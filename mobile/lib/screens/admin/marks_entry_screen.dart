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
import '../shared/results_screen.dart';

/// Marks-entry grid. One expandable row per student; totals, percentage and
/// grade are computed live so the operator sees the effect immediately.
class MarksEntryScreen extends StatefulWidget {
  const MarksEntryScreen({super.key, required this.examId});
  final String examId;

  @override
  State<MarksEntryScreen> createState() => _MarksEntryScreenState();
}

class _MarksEntryScreenState extends State<MarksEntryScreen>
    with SingleTickerProviderStateMixin {
  late final ApiService _api;
  late final AsyncController<MarksSheet> _sheetCtrl;
  late final AsyncController<Exam> _examCtrl;
  late final TabController _tabs;

  /// studentId -> (subject -> controller)
  final Map<String, Map<String, TextEditingController>> _fields = {};
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _api = context.read<ApiService>();
    _tabs = TabController(length: 2, vsync: this);
    _sheetCtrl = AsyncController(() => _api.marksSheet(widget.examId));
    _examCtrl = AsyncController(() => _api.exam(widget.examId));
    _sheetCtrl.addListener(_syncFields);
    _sheetCtrl.load();
    _examCtrl.load();
  }

  @override
  void dispose() {
    _sheetCtrl.removeListener(_syncFields);
    _sheetCtrl.dispose();
    _examCtrl.dispose();
    _tabs.dispose();
    for (final row in _fields.values) {
      for (final c in row.values) {
        c.dispose();
      }
    }
    super.dispose();
  }

  void _syncFields() {
    final sheet = _sheetCtrl.data;
    if (sheet == null) return;
    for (final row in sheet.rows) {
      final existing = _fields[row.studentId];
      if (existing != null) continue;
      _fields[row.studentId] = {
        for (final m in row.marks)
          m.subject: TextEditingController(
            text: m.marksObtained?.toString() ?? '',
          ),
      };
    }
  }

  num? _valueOf(String studentId, String subject) {
    final text = _fields[studentId]?[subject]?.text.trim() ?? '';
    return text.isEmpty ? null : num.tryParse(text);
  }

  ({num obtained, int total, double pct}) _totalsFor(MarksSheetRow row) {
    num obtained = 0;
    int total = 0;
    for (final m in row.marks) {
      final v = _valueOf(row.studentId, m.subject);
      if (v == null) continue;
      obtained += v;
      total += m.maxMarks;
    }
    return (
      obtained: obtained,
      total: total,
      pct: total == 0 ? 0 : (obtained / total * 100),
    );
  }

  String _gradeFor(double pct) => pct >= 90
      ? 'A+'
      : pct >= 80
          ? 'A'
          : pct >= 70
              ? 'B+'
              : pct >= 60
                  ? 'B'
                  : pct >= 50
                      ? 'C'
                      : pct >= 40
                          ? 'D'
                          : 'F';

  Future<void> _save() async {
    final sheet = _sheetCtrl.data;
    if (sheet == null) return;

    final results = <Map<String, dynamic>>[];
    for (final row in sheet.rows) {
      final marks = <Map<String, dynamic>>[];
      for (final m in row.marks) {
        final v = _valueOf(row.studentId, m.subject);
        if (v == null) continue;
        if (v < 0) {
          showSnack(context, '${row.name}: marks cannot be negative',
              isError: true);
          return;
        }
        if (v > m.maxMarks) {
          showSnack(
            context,
            '${row.name} · ${m.subject}: $v exceeds the maximum of ${m.maxMarks}',
            isError: true,
          );
          return;
        }
        marks.add({'subject': m.subject, 'marksObtained': v});
      }
      if (marks.isEmpty) continue;
      results.add({'studentId': row.studentId, 'marks': marks});
    }

    if (results.isEmpty) {
      showSnack(context, 'Enter marks for at least one student', isError: true);
      return;
    }

    setState(() => _saving = true);
    try {
      final msg = await _api.saveMarks(widget.examId, results);
      if (!mounted) return;
      showSnack(context, msg);
      await Future.wait([_sheetCtrl.load(), _examCtrl.load()]);
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _togglePublish() async {
    final exam = _examCtrl.data;
    if (exam == null) return;
    if (!exam.isPublished && exam.resultCount == 0) {
      showSnack(context, 'Enter and save marks before publishing',
          isError: true);
      return;
    }
    try {
      await _api.updateExam(exam.id, {'isPublished': !exam.isPublished});
      if (mounted) {
        showSnack(
          context,
          exam.isPublished ? 'Results hidden' : 'Results published to students',
        );
      }
      _examCtrl.load();
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: ListenableBuilder(
          listenable: _sheetCtrl,
          builder: (context, _) => Text(
            _sheetCtrl.data?.examName ?? 'Marks',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        actions: [
          ListenableBuilder(
            listenable: _examCtrl,
            builder: (context, _) {
              final exam = _examCtrl.data;
              if (exam == null) return const SizedBox.shrink();
              return IconButton(
                tooltip: exam.isPublished ? 'Unpublish' : 'Publish results',
                icon: Icon(
                  exam.isPublished
                      ? Icons.visibility_rounded
                      : Icons.visibility_off_outlined,
                ),
                onPressed: _togglePublish,
              );
            },
          ),
          const SizedBox(width: Gap.sm),
        ],
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'Enter marks'),
            Tab(text: 'Ranks'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [_entryTab(), _ranksTab()],
      ),
      floatingActionButton: ListenableBuilder(
        listenable: _tabs,
        builder: (context, _) => _tabs.index == 0
            ? FloatingActionButton.extended(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check_rounded),
                label: const Text('Save marks'),
              )
            : const SizedBox.shrink(),
      ),
    );
  }

  Widget _entryTab() {
    return ListenableBuilder(
      listenable: _sheetCtrl,
      builder: (context, _) {
        if (_sheetCtrl.isFirstLoad) return const SkeletonList(height: 72);
        if (_sheetCtrl.error != null && !_sheetCtrl.hasData) {
          return ErrorView(error: _sheetCtrl.error!, onRetry: _sheetCtrl.load);
        }
        final sheet = _sheetCtrl.data!;
        if (sheet.rows.isEmpty) {
          return EmptyView(
            icon: Icons.person_off_outlined,
            title: 'No students in ${sheet.batchName}',
            message: 'Assign students to this batch before entering marks.',
          );
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(
              Gap.lg, Gap.lg, Gap.lg, Gap.xxl * 2.5),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(Gap.lg),
                child: Row(
                  children: [
                    Icon(Icons.info_outline_rounded,
                        size: 18,
                        color: Theme.of(context).colorScheme.onSurfaceVariant),
                    const SizedBox(width: Gap.md),
                    Expanded(
                      child: Text(
                        'Out of ${sheet.totalMarks} marks across ${sheet.subjects.length} subjects. Leave a field blank to skip that subject.',
                        style: const TextStyle(fontSize: 12, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: Gap.lg),
            ...sheet.rows.map((row) => Padding(
                  padding: const EdgeInsets.only(bottom: Gap.md),
                  child: _MarksRow(
                    row: row,
                    controllers: _fields[row.studentId] ?? const {},
                    totals: _totalsFor(row),
                    gradeOf: _gradeFor,
                    onChanged: () => setState(() {}),
                  ),
                )),
          ],
        );
      },
    );
  }

  Widget _ranksTab() {
    return ListenableBuilder(
      listenable: _examCtrl,
      builder: (context, _) {
        if (_examCtrl.isFirstLoad) return const SkeletonList(height: 90);
        if (_examCtrl.error != null && !_examCtrl.hasData) {
          return ErrorView(error: _examCtrl.error!, onRetry: _examCtrl.load);
        }
        final exam = _examCtrl.data!;
        if (exam.results.isEmpty) {
          return const EmptyView(
            icon: Icons.leaderboard_outlined,
            title: 'No marks saved yet',
            message:
                'Enter marks on the first tab and save. Ranks are calculated automatically.',
          );
        }
        final stats = exam.stats;
        return RefreshIndicator(
          onRefresh: _examCtrl.refresh,
          child: ListView(
            padding:
                const EdgeInsets.fromLTRB(Gap.lg, Gap.lg, Gap.lg, Gap.xxl),
            children: [
              if (stats != null)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(Gap.lg),
                    child: Row(
                      children: [
                        _Stat('Average', Fmt.percent(stats.average)),
                        _Stat('Highest', Fmt.percent(stats.highest)),
                        _Stat('Lowest', Fmt.percent(stats.lowest)),
                        _Stat('Pass rate', Fmt.percent(stats.passRate)),
                      ],
                    ),
                  ),
                ),
              const SectionHeader(
                title: 'Rank list',
                padding: EdgeInsets.only(top: Gap.xl, bottom: Gap.md),
              ),
              ...exam.results.map(
                (r) => Padding(
                  padding: const EdgeInsets.only(bottom: Gap.md),
                  child: ResultCard(result: r),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value);
  final String label, value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
          ),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 11,
                ),
          ),
        ],
      ),
    );
  }
}

class _MarksRow extends StatefulWidget {
  const _MarksRow({
    required this.row,
    required this.controllers,
    required this.totals,
    required this.gradeOf,
    required this.onChanged,
  });

  final MarksSheetRow row;
  final Map<String, TextEditingController> controllers;
  final ({num obtained, int total, double pct}) totals;
  final String Function(double) gradeOf;
  final VoidCallback onChanged;

  @override
  State<_MarksRow> createState() => _MarksRowState();
}

class _MarksRowState extends State<_MarksRow> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = widget.totals;
    final hasAny = t.total > 0;
    final color = hasAny ? gradeColor(widget.gradeOf(t.pct)) : StatusColors.pending;

    return Card(
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _open = !_open),
            borderRadius: BorderRadius.circular(kRadius),
            child: Padding(
              padding: const EdgeInsets.all(Gap.md),
              child: Row(
                children: [
                  InitialsAvatar(name: widget.row.name, size: 38),
                  const SizedBox(width: Gap.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.row.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          widget.row.studentCode,
                          style: TextStyle(
                            fontSize: 11.5,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (hasAny) ...[
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${t.obtained}/${t.total}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          '${Fmt.percent(t.pct)} · ${widget.gradeOf(t.pct)}',
                          style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.w700,
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                  ] else
                    const StatusPill(
                      label: 'NOT ENTERED',
                      color: StatusColors.pending,
                      dense: true,
                    ),
                  Icon(
                    _open
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    size: 20,
                    color: scheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
          if (_open)
            Padding(
              padding: const EdgeInsets.fromLTRB(Gap.md, 0, Gap.md, Gap.md),
              child: Column(
                children: [
                  const Divider(),
                  const SizedBox(height: Gap.sm),
                  ...widget.row.marks.map(
                    (m) => Padding(
                      padding: const EdgeInsets.only(bottom: Gap.sm),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              m.subject,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 76,
                            child: TextField(
                              controller: widget.controllers[m.subject],
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              onChanged: (_) => widget.onChanged(),
                              decoration: const InputDecoration(
                                isDense: true,
                                hintText: '—',
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: Gap.sm,
                                  vertical: Gap.sm,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 42,
                            child: Text(
                              '/ ${m.maxMarks}',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
