import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/api_exception.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../state/async_value.dart';
import '../../widgets/common.dart';
import '../../widgets/states.dart';
import 'students_screen.dart';

class BatchesScreen extends StatefulWidget {
  const BatchesScreen({super.key});

  @override
  State<BatchesScreen> createState() => _BatchesScreenState();
}

class _BatchesScreenState extends State<BatchesScreen> {
  late final ApiService _api;
  late final AsyncController<List<Batch>> _ctrl;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _api = context.read<ApiService>();
    _ctrl = AsyncController(
      () => _api.batches(search: _search.isEmpty ? null : _search),
    )..load();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _openForm({Batch? batch}) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _BatchSheet(batch: batch),
    );
    if (changed == true) _ctrl.load();
  }

  Future<void> _delete(Batch b) async {
    final ok = await confirm(
      context,
      title: 'Delete batch?',
      message: b.studentCount > 0
          ? '${b.name} still has ${b.studentCount} student(s). Move them to another batch first, or deactivate this batch instead.'
          : '${b.name} will be deleted along with its timetable, exams and material.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok) return;
    try {
      await _api.deleteBatch(b.id);
      if (mounted) showSnack(context, 'Batch deleted');
      _ctrl.load();
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, isError: true);
    }
  }

  Future<void> _toggleActive(Batch b) async {
    try {
      await _api.updateBatch(b.id, {'isActive': !b.isActive});
      if (mounted) {
        showSnack(context, b.isActive ? 'Batch deactivated' : 'Batch activated');
      }
      _ctrl.load();
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Batches')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.sm, Gap.lg, Gap.md),
            child: SearchBarField(
              hint: 'Search batches…',
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
                if (_ctrl.isFirstLoad) return const SkeletonList(height: 118);
                if (_ctrl.error != null && !_ctrl.hasData) {
                  return ErrorView(error: _ctrl.error!, onRetry: _ctrl.load);
                }
                final batches = _ctrl.data ?? const <Batch>[];
                if (batches.isEmpty) {
                  return EmptyView(
                    icon: Icons.groups_outlined,
                    title: _search.isEmpty
                        ? 'No batches yet'
                        : 'No match for "$_search"',
                    message: _search.isEmpty
                        ? 'A batch groups students by course and timing.'
                        : 'Try a different name or course.',
                    actionLabel: _search.isEmpty ? 'Create batch' : null,
                    onAction: _search.isEmpty ? () => _openForm() : null,
                  );
                }
                return RefreshIndicator(
                  onRefresh: _ctrl.refresh,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(
                        Gap.lg, 0, Gap.lg, Gap.xxl * 2),
                    itemCount: batches.length,
                    separatorBuilder: (_, __) => const SizedBox(height: Gap.md),
                    itemBuilder: (context, i) {
                      final b = batches[i];
                      final full = b.studentCount >= b.capacity;
                      return Card(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(kRadius),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => StudentsScreen(
                                initialBatchId: b.id,
                                title: b.name,
                              ),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(Gap.lg),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            b.name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 15.5,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            b.course,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 12.5,
                                              color: scheme.onSurfaceVariant,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (!b.isActive)
                                      const StatusPill(
                                        label: 'INACTIVE',
                                        color: StatusColors.pending,
                                        dense: true,
                                      ),
                                    PopupMenuButton<String>(
                                      icon: Icon(Icons.more_vert_rounded,
                                          size: 19,
                                          color: scheme.onSurfaceVariant),
                                      onSelected: (v) {
                                        switch (v) {
                                          case 'edit':
                                            _openForm(batch: b);
                                          case 'toggle':
                                            _toggleActive(b);
                                          case 'delete':
                                            _delete(b);
                                        }
                                      },
                                      itemBuilder: (_) => [
                                        const PopupMenuItem(
                                          value: 'edit',
                                          child: Text('Edit'),
                                        ),
                                        PopupMenuItem(
                                          value: 'toggle',
                                          child: Text(b.isActive
                                              ? 'Deactivate'
                                              : 'Activate'),
                                        ),
                                        PopupMenuItem(
                                          value: 'delete',
                                          child: Text(
                                            'Delete',
                                            style:
                                                TextStyle(color: scheme.error),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: Gap.md),
                                Wrap(
                                  spacing: Gap.sm,
                                  runSpacing: Gap.sm,
                                  children: [
                                    StatusPill(
                                      label: b.timing,
                                      color: scheme.primary,
                                      icon: Icons.schedule_rounded,
                                      dense: true,
                                    ),
                                    StatusPill(
                                      label: b.room,
                                      color: const Color(0xFF6172F3),
                                      icon: Icons.room_outlined,
                                      dense: true,
                                    ),
                                    StatusPill(
                                      label:
                                          '${b.studentCount}/${b.capacity} students',
                                      color: full
                                          ? StatusColors.overdue
                                          : StatusColors.present,
                                      icon: Icons.people_alt_rounded,
                                      dense: true,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: Gap.md),
                                Text(
                                  b.subject,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New batch'),
      ),
    );
  }
}

class _BatchSheet extends StatefulWidget {
  const _BatchSheet({this.batch});
  final Batch? batch;

  @override
  State<_BatchSheet> createState() => _BatchSheetState();
}

class _BatchSheetState extends State<_BatchSheet> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.batch?.name);
  late final _course = TextEditingController(text: widget.batch?.course);
  late final _subject = TextEditingController(text: widget.batch?.subject);
  late final _room = TextEditingController(text: widget.batch?.room);
  late final _capacity =
      TextEditingController(text: (widget.batch?.capacity ?? 40).toString());

  TimeOfDay _start = const TimeOfDay(hour: 7, minute: 0);
  TimeOfDay _end = const TimeOfDay(hour: 9, minute: 30);
  bool _saving = false;

  bool get _isEdit => widget.batch != null;

  @override
  void initState() {
    super.initState();
    // Recover the two times from the stored "07:00 AM - 09:30 AM" string.
    final timing = widget.batch?.timing;
    if (timing != null) {
      final parts = timing.split('-');
      if (parts.length == 2) {
        _start = _parse(parts[0].trim()) ?? _start;
        _end = _parse(parts[1].trim()) ?? _end;
      }
    }
  }

  TimeOfDay? _parse(String s) {
    final m = RegExp(r'(\d{1,2}):(\d{2})\s*([AaPp][Mm])?').firstMatch(s);
    if (m == null) return null;
    var h = int.parse(m.group(1)!);
    final min = int.parse(m.group(2)!);
    final ampm = m.group(3)?.toUpperCase();
    if (ampm == 'PM' && h != 12) h += 12;
    if (ampm == 'AM' && h == 12) h = 0;
    return TimeOfDay(hour: h % 24, minute: min);
  }

  String _label(TimeOfDay t) {
    final suffix = t.hour >= 12 ? 'PM' : 'AM';
    final h12 = t.hour % 12 == 0 ? 12 : t.hour % 12;
    return '$h12:${t.minute.toString().padLeft(2, '0')} $suffix';
  }

  @override
  void dispose() {
    _name.dispose();
    _course.dispose();
    _subject.dispose();
    _room.dispose();
    _capacity.dispose();
    super.dispose();
  }

  Future<void> _pick({required bool isStart}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _start : _end,
    );
    if (picked != null) {
      setState(() => isStart ? _start = picked : _end = picked);
    }
  }

  Future<void> _submit() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    final api = context.read<ApiService>();
    final body = {
      'name': _name.text.trim(),
      'course': _course.text.trim(),
      'subject': _subject.text.trim(),
      'timing': '${_label(_start)} - ${_label(_end)}',
      'room': _room.text.trim(),
      'capacity': int.tryParse(_capacity.text.trim()) ?? 40,
    };
    try {
      if (_isEdit) {
        await api.updateBatch(widget.batch!.id, body);
      } else {
        await api.createBatch(body);
      }
      if (!mounted) return;
      showSnack(context, _isEdit ? 'Batch updated' : 'Batch created');
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String? _req(String? v, String label) =>
      (v == null || v.trim().isEmpty) ? '$label is required' : null;

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
                _isEdit ? 'Edit batch' : 'New batch',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: Gap.xl),
              TextFormField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Batch name',
                  hintText: 'e.g. JEE Morning A',
                ),
                validator: (v) => _req(v, 'Batch name'),
              ),
              const SizedBox(height: Gap.lg),
              TextFormField(
                controller: _course,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Course',
                  hintText: 'e.g. JEE Main 2027',
                ),
                validator: (v) => _req(v, 'Course'),
              ),
              const SizedBox(height: Gap.lg),
              TextFormField(
                controller: _subject,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Subjects',
                  hintText: 'e.g. Physics, Chemistry, Maths',
                ),
                validator: (v) => _req(v, 'Subjects'),
              ),
              const SizedBox(height: Gap.lg),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => _pick(isStart: true),
                      borderRadius: BorderRadius.circular(kRadiusSm),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Starts',
                          isDense: true,
                        ),
                        child: Text(_label(_start)),
                      ),
                    ),
                  ),
                  const SizedBox(width: Gap.md),
                  Expanded(
                    child: InkWell(
                      onTap: () => _pick(isStart: false),
                      borderRadius: BorderRadius.circular(kRadiusSm),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Ends',
                          isDense: true,
                        ),
                        child: Text(_label(_end)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Gap.lg),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _room,
                      decoration: const InputDecoration(
                        labelText: 'Room',
                        isDense: true,
                      ),
                      validator: (v) => _req(v, 'Room'),
                    ),
                  ),
                  const SizedBox(width: Gap.md),
                  Expanded(
                    child: TextFormField(
                      controller: _capacity,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Capacity',
                        isDense: true,
                      ),
                      validator: (v) {
                        final n = int.tryParse(v?.trim() ?? '');
                        if (n == null) return 'Number';
                        if (n < 1) return '> 0';
                        return null;
                      },
                    ),
                  ),
                ],
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
                    : Text(_isEdit ? 'Save changes' : 'Create batch'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
