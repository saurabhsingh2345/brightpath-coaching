import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/api_exception.dart';
import '../../core/formatters.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../state/async_value.dart';
import '../../widgets/common.dart';
import '../../widgets/states.dart';

/// Admin: compose / pin / delete. Students get the read-only variant via
/// [mine], which uses the /announcements/me endpoint.
class AnnouncementsScreen extends StatefulWidget {
  const AnnouncementsScreen({
    super.key,
    this.mine = false,
    this.showAppBar = true,
  });

  final bool mine;
  final bool showAppBar;

  @override
  State<AnnouncementsScreen> createState() => _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends State<AnnouncementsScreen> {
  late final ApiService _api;
  late final AsyncController<List<Announcement>> _ctrl;
  List<Batch> _batches = const [];
  String _search = '';

  @override
  void initState() {
    super.initState();
    _api = context.read<ApiService>();
    _ctrl = AsyncController(_fetch)..load();
    if (!widget.mine) _loadBatches();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _loadBatches() async {
    try {
      final b = await _api.batches();
      if (mounted) setState(() => _batches = b);
    } catch (_) {}
  }

  Future<List<Announcement>> _fetch() => widget.mine
      ? _api.myAnnouncements()
      : _api.announcements(search: _search.isEmpty ? null : _search);

  Future<void> _compose({Announcement? existing}) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ComposeSheet(batches: _batches, existing: existing),
    );
    if (saved == true) _ctrl.load();
  }

  Future<void> _togglePin(Announcement a) async {
    try {
      await _api.updateAnnouncement(a.id, {'isPinned': !a.isPinned});
      if (mounted) showSnack(context, a.isPinned ? 'Unpinned' : 'Pinned to top');
      _ctrl.load();
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, isError: true);
    }
  }

  Future<void> _delete(Announcement a) async {
    final ok = await confirm(
      context,
      title: 'Delete announcement?',
      message: '"${a.title}" will be removed for everyone.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok) return;
    try {
      await _api.deleteAnnouncement(a.id);
      if (mounted) showSnack(context, 'Announcement deleted');
      _ctrl.load();
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final body = Column(
      children: [
        if (!widget.mine)
          Padding(
            padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.sm, Gap.lg, Gap.md),
            child: SearchBarField(
              hint: 'Search announcements…',
              onChanged: (v) {
                _search = v;
                _ctrl.load();
              },
            ),
          ),
        Expanded(
          child: ListenableBuilder(
            listenable: _ctrl,
            builder: (context, _) {
              if (_ctrl.isFirstLoad) return const SkeletonList(height: 108);
              if (_ctrl.error != null && !_ctrl.hasData) {
                return ErrorView(error: _ctrl.error!, onRetry: _ctrl.load);
              }
              final items = _ctrl.data ?? const <Announcement>[];
              if (items.isEmpty) {
                return EmptyView(
                  icon: Icons.campaign_outlined,
                  title: widget.mine
                      ? 'No announcements'
                      : (_search.isEmpty
                          ? 'No announcements yet'
                          : 'Nothing matches "$_search"'),
                  message: widget.mine
                      ? 'Notices from the institute will appear here.'
                      : 'Send a notice to everyone or to one batch.',
                  actionLabel: widget.mine || _search.isNotEmpty
                      ? null
                      : 'New announcement',
                  onAction: widget.mine || _search.isNotEmpty
                      ? null
                      : () => _compose(),
                );
              }
              return RefreshIndicator(
                onRefresh: _ctrl.refresh,
                child: ListView.separated(
                  padding: EdgeInsets.fromLTRB(
                    Gap.lg,
                    widget.mine ? Gap.lg : 0,
                    Gap.lg,
                    Gap.xxl * 2,
                  ),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: Gap.md),
                  itemBuilder: (context, i) => AnnouncementCard(
                    announcement: items[i],
                    onEdit: widget.mine ? null : () => _compose(existing: items[i]),
                    onPin: widget.mine ? null : () => _togglePin(items[i]),
                    onDelete: widget.mine ? null : () => _delete(items[i]),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );

    if (!widget.showAppBar) return body;

    return Scaffold(
      appBar: AppBar(title: const Text('Announcements')),
      body: body,
      floatingActionButton: widget.mine
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _compose(),
              icon: const Icon(Icons.campaign_rounded),
              label: const Text('Announce'),
            ),
    );
  }
}

class AnnouncementCard extends StatelessWidget {
  const AnnouncementCard({
    super.key,
    required this.announcement,
    this.onEdit,
    this.onPin,
    this.onDelete,
  });

  final Announcement announcement;
  final VoidCallback? onEdit;
  final VoidCallback? onPin;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final a = announcement;
    final hasActions = onEdit != null || onPin != null || onDelete != null;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(kRadius),
        onTap: () => showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          builder: (_) => _ReadSheet(announcement: a),
        ),
        child: Padding(
          padding: const EdgeInsets.all(Gap.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (a.isPinned) ...[
                    Icon(Icons.push_pin_rounded,
                        size: 15, color: scheme.primary),
                    const SizedBox(width: Gap.xs),
                  ],
                  Expanded(
                    child: Text(
                      a.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14.5,
                        height: 1.3,
                      ),
                    ),
                  ),
                  if (hasActions)
                    PopupMenuButton<String>(
                      icon: Icon(Icons.more_vert_rounded,
                          size: 18, color: scheme.onSurfaceVariant),
                      onSelected: (v) {
                        switch (v) {
                          case 'edit':
                            onEdit?.call();
                          case 'pin':
                            onPin?.call();
                          case 'delete':
                            onDelete?.call();
                        }
                      },
                      itemBuilder: (_) => [
                        if (onEdit != null)
                          const PopupMenuItem(
                              value: 'edit', child: Text('Edit')),
                        if (onPin != null)
                          PopupMenuItem(
                            value: 'pin',
                            child: Text(a.isPinned ? 'Unpin' : 'Pin to top'),
                          ),
                        if (onDelete != null)
                          PopupMenuItem(
                            value: 'delete',
                            child: Text('Delete',
                                style: TextStyle(color: scheme.error)),
                          ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: Gap.sm),
              Text(
                a.body,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.45,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: Gap.md),
              Row(
                children: [
                  StatusPill(
                    label: a.isForAll
                        ? 'ALL STUDENTS'
                        : (a.batchName ?? 'BATCH').toUpperCase(),
                    color: a.isForAll ? scheme.primary : const Color(0xFF6172F3),
                    icon: a.isForAll
                        ? Icons.public_rounded
                        : Icons.groups_rounded,
                    dense: true,
                  ),
                  const Spacer(),
                  Text(
                    Fmt.dateShort(a.createdAt),
                    style: TextStyle(
                      fontSize: 11.5,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReadSheet extends StatelessWidget {
  const _ReadSheet({required this.announcement});
  final Announcement announcement;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final a = announcement;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.55,
      maxChildSize: 0.9,
      builder: (context, scroll) => ListView(
        controller: scroll,
        padding: const EdgeInsets.fromLTRB(Gap.xl, 0, Gap.xl, Gap.xxl),
        children: [
          Row(
            children: [
              if (a.isPinned) ...[
                Icon(Icons.push_pin_rounded, size: 17, color: scheme.primary),
                const SizedBox(width: Gap.sm),
              ],
              Expanded(
                child: Text(
                  a.title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ],
          ),
          const SizedBox(height: Gap.sm),
          Row(
            children: [
              StatusPill(
                label: a.isForAll
                    ? 'ALL STUDENTS'
                    : (a.batchName ?? 'BATCH').toUpperCase(),
                color: a.isForAll ? scheme.primary : const Color(0xFF6172F3),
                dense: true,
              ),
              const SizedBox(width: Gap.sm),
              Text(
                Fmt.dateTime(a.createdAt),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
          const Divider(height: Gap.xxl),
          Text(a.body, style: const TextStyle(fontSize: 14.5, height: 1.6)),
          if (a.authorName != null) ...[
            const SizedBox(height: Gap.xl),
            Text(
              '— ${a.authorName}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ComposeSheet extends StatefulWidget {
  const _ComposeSheet({required this.batches, this.existing});
  final List<Batch> batches;
  final Announcement? existing;

  @override
  State<_ComposeSheet> createState() => _ComposeSheetState();
}

class _ComposeSheetState extends State<_ComposeSheet> {
  final _form = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.existing?.title);
  late final _body = TextEditingController(text: widget.existing?.body);
  late String _audience = widget.existing?.audience ?? 'ALL';
  late String? _batchId = widget.existing?.batchId;
  late bool _pinned = widget.existing?.isPinned ?? false;
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    if (_audience == 'BATCH' && _batchId == null) {
      showSnack(context, 'Pick a batch to send to', isError: true);
      return;
    }
    setState(() => _saving = true);
    final api = context.read<ApiService>();
    final body = {
      'title': _title.text.trim(),
      'body': _body.text.trim(),
      'audience': _audience,
      if (_audience == 'BATCH') 'batchId': _batchId,
      'isPinned': _pinned,
    };
    try {
      if (_isEdit) {
        await api.updateAnnouncement(widget.existing!.id, body);
      } else {
        await api.createAnnouncement(body);
      }
      if (!mounted) return;
      showSnack(context, _isEdit ? 'Announcement updated' : 'Announcement sent');
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: Gap.xl,
        right: Gap.xl,
        bottom: MediaQuery.of(context).viewInsets.bottom + Gap.xl,
      ),
      child: Form(
        key: _form,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _isEdit ? 'Edit announcement' : 'New announcement',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: Gap.xl),
              TextFormField(
                controller: _title,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Title'),
                validator: (v) {
                  final value = v?.trim() ?? '';
                  if (value.isEmpty) return 'Title is required';
                  if (value.length < 3) return 'Title is too short';
                  return null;
                },
              ),
              const SizedBox(height: Gap.lg),
              TextFormField(
                controller: _body,
                maxLines: 5,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Message'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Message is required' : null,
              ),
              const SizedBox(height: Gap.lg),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: 'ALL',
                    label: Text('All students'),
                    icon: Icon(Icons.public_rounded, size: 17),
                  ),
                  ButtonSegment(
                    value: 'BATCH',
                    label: Text('One batch'),
                    icon: Icon(Icons.groups_rounded, size: 17),
                  ),
                ],
                selected: {_audience},
                onSelectionChanged: (s) => setState(() => _audience = s.first),
              ),
              if (_audience == 'BATCH') ...[
                const SizedBox(height: Gap.lg),
                DropdownButtonFormField<String>(
                  initialValue: _batchId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Batch'),
                  items: widget.batches
                      .map((b) => DropdownMenuItem(
                            value: b.id,
                            child:
                                Text(b.name, overflow: TextOverflow.ellipsis),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _batchId = v),
                  validator: (v) =>
                      v == null ? 'Select a batch' : null,
                ),
              ],
              const SizedBox(height: Gap.sm),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _pinned,
                onChanged: (v) => setState(() => _pinned = v),
                title: const Text('Pin to top'),
                subtitle: const Text(
                  'Keeps this notice above the rest',
                  style: TextStyle(fontSize: 12),
                ),
              ),
              const SizedBox(height: Gap.lg),
              FilledButton(
                onPressed: _saving ? null : _submit,
                child: _saving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: Colors.white,
                        ),
                      )
                    : Text(_isEdit ? 'Save changes' : 'Send announcement'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
