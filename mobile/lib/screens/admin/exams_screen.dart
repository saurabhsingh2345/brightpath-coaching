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
import 'marks_entry_screen.dart';

class ExamsScreen extends StatefulWidget {
  const ExamsScreen({super.key});

  @override
  State<ExamsScreen> createState() => _ExamsScreenState();
}

class _ExamsScreenState extends State<ExamsScreen> {
  late final ApiService _api;
  late final AsyncController<List<Exam>> _ctrl;
  List<Batch> _batches = const [];
  String? _batchId;

  @override
  void initState() {
    super.initState();
    _api = context.read<ApiService>();
    _ctrl = AsyncController(() => _api.exams(batchId: _batchId))..load();
    _loadBatches();
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

  Future<void> _openForm() async {
    if (_batches.isEmpty) {
      showSnack(context, 'Create a batch first', isError: true);
      return;
    }
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ExamSheet(batches: _batches),
    );
    if (created == true) _ctrl.load();
  }

  Future<void> _togglePublish(Exam e) async {
    if (!e.isPublished && e.resultCount == 0) {
      showSnack(context, 'Enter marks before publishing this exam',
          isError: true);
      return;
    }
    try {
      await _api.updateExam(e.id, {'isPublished': !e.isPublished});
      if (mounted) {
        showSnack(
          context,
          e.isPublished
              ? 'Results hidden from students'
              : 'Results published to students',
        );
      }
      _ctrl.load();
    } on ApiException catch (err) {
      if (mounted) showSnack(context, err.message, isError: true);
    }
  }

  Future<void> _delete(Exam e) async {
    final ok = await confirm(
      context,
      title: 'Delete exam?',
      message:
          '"${e.name}" and its ${e.resultCount} result(s) will be permanently removed.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok) return;
    try {
      await _api.deleteExam(e.id);
      if (mounted) showSnack(context, 'Exam deleted');
      _ctrl.load();
    } on ApiException catch (err) {
      if (mounted) showSnack(context, err.message, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Exams')),
      body: Column(
        children: [
          if (_batches.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.sm, Gap.lg, Gap.md),
              child: DropdownButtonFormField<String?>(
                initialValue: _batchId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Batch',
                  isDense: true,
                ),
                items: [
                  const DropdownMenuItem(
                      value: null, child: Text('All batches')),
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
                if (_ctrl.isFirstLoad) return const SkeletonList(height: 104);
                if (_ctrl.error != null && !_ctrl.hasData) {
                  return ErrorView(error: _ctrl.error!, onRetry: _ctrl.load);
                }
                final exams = _ctrl.data ?? const <Exam>[];
                if (exams.isEmpty) {
                  return EmptyView(
                    icon: Icons.assignment_outlined,
                    title: 'No exams yet',
                    message:
                        'Create an exam, add its subjects, then enter marks to get ranks and percentages.',
                    actionLabel: 'Create exam',
                    onAction: _openForm,
                  );
                }
                return RefreshIndicator(
                  onRefresh: _ctrl.refresh,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(
                        Gap.lg, 0, Gap.lg, Gap.xxl * 2),
                    itemCount: exams.length,
                    separatorBuilder: (_, __) => const SizedBox(height: Gap.md),
                    itemBuilder: (context, i) {
                      final e = exams[i];
                      final upcoming =
                          e.examDate?.isAfter(DateTime.now()) ?? false;
                      return Card(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(kRadius),
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => MarksEntryScreen(examId: e.id),
                              ),
                            );
                            _ctrl.load();
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(Gap.lg),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        e.name,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 15,
                                          height: 1.3,
                                        ),
                                      ),
                                    ),
                                    PopupMenuButton<String>(
                                      icon: Icon(Icons.more_vert_rounded,
                                          size: 19,
                                          color: scheme.onSurfaceVariant),
                                      onSelected: (v) {
                                        switch (v) {
                                          case 'marks':
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) =>
                                                    MarksEntryScreen(
                                                        examId: e.id),
                                              ),
                                            ).then((_) => _ctrl.load());
                                          case 'publish':
                                            _togglePublish(e);
                                          case 'delete':
                                            _delete(e);
                                        }
                                      },
                                      itemBuilder: (_) => [
                                        const PopupMenuItem(
                                          value: 'marks',
                                          child: Text('Enter marks'),
                                        ),
                                        PopupMenuItem(
                                          value: 'publish',
                                          child: Text(e.isPublished
                                              ? 'Unpublish results'
                                              : 'Publish results'),
                                        ),
                                        PopupMenuItem(
                                          value: 'delete',
                                          child: Text('Delete',
                                              style: TextStyle(
                                                  color: scheme.error)),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                Text(
                                  '${e.batchName ?? '—'} · ${Fmt.date(e.examDate)}',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: Gap.md),
                                Wrap(
                                  spacing: Gap.sm,
                                  runSpacing: Gap.sm,
                                  children: [
                                    StatusPill(
                                      label: e.isPublished
                                          ? 'PUBLISHED'
                                          : (upcoming ? 'UPCOMING' : 'DRAFT'),
                                      color: e.isPublished
                                          ? StatusColors.present
                                          : (upcoming
                                              ? scheme.primary
                                              : StatusColors.pending),
                                      icon: e.isPublished
                                          ? Icons.visibility_rounded
                                          : Icons.visibility_off_rounded,
                                      dense: true,
                                    ),
                                    StatusPill(
                                      label: '${e.subjects.length} subjects',
                                      color: const Color(0xFF6172F3),
                                      dense: true,
                                    ),
                                    StatusPill(
                                      label: '${e.totalMarks} marks',
                                      color: const Color(0xFF06AED4),
                                      dense: true,
                                    ),
                                    StatusPill(
                                      label: e.resultCount == 0
                                          ? 'No marks entered'
                                          : '${e.resultCount} results',
                                      color: e.resultCount == 0
                                          ? StatusColors.partial
                                          : StatusColors.paid,
                                      dense: true,
                                    ),
                                  ],
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
        onPressed: _openForm,
        icon: const Icon(Icons.add_rounded),
        label: const Text('New exam'),
      ),
    );
  }
}

class _SubjectDraft {
  _SubjectDraft(this.name, this.marks);
  final TextEditingController name;
  final TextEditingController marks;
}

class _ExamSheet extends StatefulWidget {
  const _ExamSheet({required this.batches});
  final List<Batch> batches;

  @override
  State<_ExamSheet> createState() => _ExamSheetState();
}

class _ExamSheetState extends State<_ExamSheet> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _description = TextEditingController();
  late String _batchId = widget.batches.first.id;
  DateTime _date = DateTime.now().add(const Duration(days: 7));
  final List<_SubjectDraft> _subjects = [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _addSubject();
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    for (final s in _subjects) {
      s.name.dispose();
      s.marks.dispose();
    }
    super.dispose();
  }

  void _addSubject() {
    setState(() {
      _subjects.add(_SubjectDraft(
        TextEditingController(),
        TextEditingController(text: '100'),
      ));
    });
  }

  int get _total => _subjects.fold<int>(
        0,
        (sum, s) => sum + (int.tryParse(s.marks.text.trim()) ?? 0),
      );

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _submit() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    final names = _subjects
        .map((s) => s.name.text.trim().toLowerCase())
        .toList();
    if (names.toSet().length != names.length) {
      showSnack(context, 'Subject names must be unique', isError: true);
      return;
    }
    setState(() => _saving = true);
    try {
      await context.read<ApiService>().createExam({
        'batchId': _batchId,
        'name': _name.text.trim(),
        'examDate': Fmt.iso(_date),
        if (_description.text.trim().isNotEmpty)
          'description': _description.text.trim(),
        'subjects': _subjects
            .map((s) => {
                  'name': s.name.text.trim(),
                  'maxMarks': int.parse(s.marks.text.trim()),
                })
            .toList(),
      });
      if (!mounted) return;
      showSnack(context, 'Exam created');
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
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      builder: (context, scroll) => Form(
        key: _form,
        child: ListView(
          controller: scroll,
          padding: EdgeInsets.fromLTRB(
            Gap.xl,
            0,
            Gap.xl,
            MediaQuery.of(context).viewInsets.bottom + Gap.xl,
          ),
          children: [
            Text('New exam', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: Gap.xl),
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Exam name',
                hintText: 'e.g. Monthly Test - September',
              ),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Exam name is required'
                  : null,
            ),
            const SizedBox(height: Gap.lg),
            DropdownButtonFormField<String>(
              initialValue: _batchId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Batch'),
              items: widget.batches
                  .map((b) => DropdownMenuItem(
                        value: b.id,
                        child: Text(b.name, overflow: TextOverflow.ellipsis),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _batchId = v!),
            ),
            const SizedBox(height: Gap.lg),
            InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(kRadiusSm),
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Exam date',
                  suffixIcon: Icon(Icons.calendar_today_rounded, size: 18),
                ),
                child: Text(Fmt.date(_date)),
              ),
            ),
            const SizedBox(height: Gap.lg),
            TextFormField(
              controller: _description,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Syllabus / notes (optional)',
              ),
            ),
            const Divider(height: Gap.xxl),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'SUBJECTS',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                        ),
                  ),
                ),
                Text(
                  'Total $_total marks',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: scheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: Gap.md),
            ...List.generate(_subjects.length, (i) {
              final s = _subjects[i];
              return Padding(
                padding: const EdgeInsets.only(bottom: Gap.md),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextFormField(
                        controller: s.name,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'Subject',
                          isDense: true,
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Required'
                            : null,
                      ),
                    ),
                    const SizedBox(width: Gap.sm),
                    Expanded(
                      child: TextFormField(
                        controller: s.marks,
                        keyboardType: TextInputType.number,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                          labelText: 'Max',
                          isDense: true,
                        ),
                        validator: (v) {
                          final n = int.tryParse(v?.trim() ?? '');
                          if (n == null) return 'No.';
                          if (n < 1) return '> 0';
                          return null;
                        },
                      ),
                    ),
                    if (_subjects.length > 1)
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 19),
                        onPressed: () => setState(() => _subjects.removeAt(i)),
                      ),
                  ],
                ),
              );
            }),
            OutlinedButton.icon(
              onPressed: _addSubject,
              icon: const Icon(Icons.add_rounded, size: 19),
              label: const Text('Add subject'),
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
                  : const Text('Create exam'),
            ),
          ],
        ),
      ),
    );
  }
}
