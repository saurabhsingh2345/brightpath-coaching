import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/api_exception.dart';
import '../../core/formatters.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../state/async_value.dart';
import '../../widgets/common.dart';
import '../../widgets/states.dart';

/// Study material list. Admins can upload and delete; students get a
/// read-only view of their batch plus institute-wide documents.
class MaterialsScreen extends StatefulWidget {
  const MaterialsScreen({
    super.key,
    this.mine = false,
    this.showAppBar = true,
  });

  final bool mine;
  final bool showAppBar;

  @override
  State<MaterialsScreen> createState() => _MaterialsScreenState();
}

class _MaterialsScreenState extends State<MaterialsScreen> {
  late final ApiService _api;
  late final AsyncController<List<StudyMaterial>> _ctrl;

  String _search = '';
  String? _batchId;
  List<Batch> _batches = const [];

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

  Future<List<StudyMaterial>> _fetch() => widget.mine
      ? _api.myMaterials(search: _search.isEmpty ? null : _search)
      : _api.materials(
          batchId: _batchId,
          search: _search.isEmpty ? null : _search,
        );

  Future<void> _open(StudyMaterial m) async {
    final uri = Uri.parse(m.fileUrl);
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && mounted) {
        showSnack(context, 'No app on this device can open that file',
            isError: true);
      }
    } catch (_) {
      if (mounted) {
        showSnack(context, 'Could not open the file', isError: true);
      }
    }
  }

  Future<void> _upload() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      // withData so the picker also returns bytes, which is the only thing
      // available in a browser.
      withData: true,
      allowedExtensions: const [
        'pdf', 'doc', 'docx', 'ppt', 'pptx', 'xls', 'xlsx', 'txt', 'jpg',
        'jpeg', 'png', 'zip',
      ],
    );
    final file = result?.files.single;
    if (file == null) return;
    if (file.path == null && file.bytes == null) {
      if (mounted) {
        showSnack(context, 'Could not read that file', isError: true);
      }
      return;
    }
    if (!mounted) return;

    final uploaded = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _UploadSheet(
        filePath: file.path,
        bytes: file.bytes,
        fileName: file.name,
        fileSize: file.size,
        batches: _batches,
      ),
    );
    if (uploaded == true) _ctrl.load();
  }

  Future<void> _delete(StudyMaterial m) async {
    final ok = await confirm(
      context,
      title: 'Delete material?',
      message: '"${m.title}" will be removed for everyone it was shared with.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok) return;
    try {
      await _api.deleteMaterial(m.id);
      if (mounted) showSnack(context, 'Material deleted');
      _ctrl.load();
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final body = Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.sm, Gap.lg, Gap.md),
          child: SearchBarField(
            hint: 'Search notes, subjects…',
            onChanged: (v) {
              _search = v;
              _ctrl.load();
            },
          ),
        ),
        if (!widget.mine && _batches.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(Gap.lg, 0, Gap.lg, Gap.md),
            child: DropdownButtonFormField<String?>(
              initialValue: _batchId,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Batch',
                isDense: true,
              ),
              items: [
                const DropdownMenuItem(value: null, child: Text('All batches')),
                ..._batches.map(
                  (b) => DropdownMenuItem(value: b.id, child: Text(b.name)),
                ),
              ],
              onChanged: (v) {
                setState(() => _batchId = v);
                _ctrl.load();
              },
            ),
          ),
        Expanded(
          child: ListenableBuilder(
            listenable: _ctrl,
            builder: (context, _) {
              if (_ctrl.isFirstLoad) return const SkeletonList(height: 76);
              if (_ctrl.error != null && !_ctrl.hasData) {
                return ErrorView(error: _ctrl.error!, onRetry: _ctrl.load);
              }
              final items = _ctrl.data ?? const <StudyMaterial>[];
              if (items.isEmpty) {
                return EmptyView(
                  icon: Icons.folder_open_outlined,
                  title: _search.isEmpty
                      ? 'No study material yet'
                      : 'Nothing matches "$_search"',
                  message: widget.mine
                      ? 'Notes shared by your teachers will show up here.'
                      : 'Upload a PDF or document and assign it to a batch.',
                  actionLabel: widget.mine || _search.isNotEmpty
                      ? null
                      : 'Upload document',
                  onAction:
                      widget.mine || _search.isNotEmpty ? null : _upload,
                );
              }
              return RefreshIndicator(
                onRefresh: _ctrl.refresh,
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                      Gap.lg, 0, Gap.lg, Gap.xxl * 2),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: Gap.md),
                  itemBuilder: (context, i) => _MaterialCard(
                    material: items[i],
                    onOpen: () => _open(items[i]),
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
      appBar: AppBar(
        title: Text(widget.mine ? 'Study material' : 'Study material'),
      ),
      body: body,
      floatingActionButton: widget.mine
          ? null
          : FloatingActionButton.extended(
              onPressed: _upload,
              icon: const Icon(Icons.upload_file_rounded),
              label: const Text('Upload'),
            ),
    );
  }
}

class _MaterialCard extends StatelessWidget {
  const _MaterialCard({
    required this.material,
    required this.onOpen,
    this.onDelete,
  });

  final StudyMaterial material;
  final VoidCallback onOpen;
  final VoidCallback? onDelete;

  IconData get _icon {
    if (material.isPdf) return Icons.picture_as_pdf_rounded;
    if (material.fileType.contains('image')) return Icons.image_rounded;
    if (material.fileType.contains('sheet') ||
        material.fileType.contains('excel')) {
      return Icons.table_chart_rounded;
    }
    if (material.fileType.contains('presentation')) return Icons.slideshow_rounded;
    if (material.fileType.contains('zip')) return Icons.folder_zip_rounded;
    return Icons.description_rounded;
  }

  Color get _tint {
    if (material.isPdf) return const Color(0xFFF04438);
    if (material.fileType.contains('image')) return const Color(0xFF06AED4);
    if (material.fileType.contains('sheet')) return const Color(0xFF12B76A);
    if (material.fileType.contains('presentation')) {
      return const Color(0xFFF79009);
    }
    return const Color(0xFF6172F3);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(kRadius),
        child: Padding(
          padding: const EdgeInsets.all(Gap.lg),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: _tint.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(_icon, size: 22, color: _tint),
              ),
              const SizedBox(width: Gap.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      material.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${material.subject} · ${Fmt.fileSize(material.fileSize)} · ${material.batchName ?? 'All batches'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (onDelete != null)
                IconButton(
                  tooltip: 'Delete',
                  icon: Icon(Icons.delete_outline_rounded,
                      size: 19, color: scheme.onSurfaceVariant),
                  onPressed: onDelete,
                )
              else
                Icon(Icons.download_rounded,
                    size: 19, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _UploadSheet extends StatefulWidget {
  const _UploadSheet({
    required this.fileName,
    required this.fileSize,
    required this.batches,
    this.filePath,
    this.bytes,
  });

  final String fileName;
  final String? filePath;
  final Uint8List? bytes;
  final int fileSize;
  final List<Batch> batches;

  @override
  State<_UploadSheet> createState() => _UploadSheetState();
}

class _UploadSheetState extends State<_UploadSheet> {
  final _form = GlobalKey<FormState>();
  late final _title = TextEditingController(
    text: widget.fileName.replaceAll(RegExp(r'\.[^.]+$'), ''),
  );
  final _subject = TextEditingController();
  final _description = TextEditingController();
  String? _batchId;
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _subject.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      await context.read<ApiService>().uploadMaterial(
            title: _title.text.trim(),
            subject: _subject.text.trim(),
            description: _description.text.trim(),
            batchId: _batchId,
            filePath: widget.filePath,
            bytes: widget.bytes,
            fileName: widget.fileName,
          );
      if (!mounted) return;
      showSnack(context, 'Uploaded');
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
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
              Text('Upload material',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: Gap.md),
              Container(
                padding: const EdgeInsets.all(Gap.md),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(kRadiusSm),
                ),
                child: Row(
                  children: [
                    Icon(Icons.attach_file_rounded,
                        size: 17, color: scheme.onSurfaceVariant),
                    const SizedBox(width: Gap.sm),
                    Expanded(
                      child: Text(
                        widget.fileName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Text(
                      Fmt.fileSize(widget.fileSize),
                      style: TextStyle(
                        fontSize: 11.5,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: Gap.lg),
              TextFormField(
                controller: _title,
                decoration: const InputDecoration(labelText: 'Title'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Title is required' : null,
              ),
              const SizedBox(height: Gap.lg),
              TextFormField(
                controller: _subject,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Subject',
                  hintText: 'e.g. Physics',
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Subject is required'
                    : null,
              ),
              const SizedBox(height: Gap.lg),
              DropdownButtonFormField<String?>(
                initialValue: _batchId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Share with'),
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: Text('All batches'),
                  ),
                  ...widget.batches.map(
                    (b) => DropdownMenuItem(value: b.id, child: Text(b.name)),
                  ),
                ],
                onChanged: (v) => setState(() => _batchId = v),
              ),
              const SizedBox(height: Gap.lg),
              TextFormField(
                controller: _description,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                ),
              ),
              const SizedBox(height: Gap.xl),
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
                    : const Text('Upload'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
