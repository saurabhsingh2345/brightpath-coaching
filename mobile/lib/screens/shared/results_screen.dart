import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/formatters.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../state/async_value.dart';
import '../../widgets/common.dart';
import '../../widgets/states.dart';

Color gradeColor(String? grade) => switch (grade) {
      'A+' || 'A' => StatusColors.present,
      'B+' || 'B' => const Color(0xFF06AED4),
      'C' => StatusColors.late,
      'D' => const Color(0xFFF79009),
      'F' => StatusColors.absent,
      _ => StatusColors.pending,
    };

/// Report card. Students see only published exams (enforced server-side).
class ResultsScreen extends StatefulWidget {
  const ResultsScreen({
    super.key,
    this.studentId,
    this.studentName,
    this.mine = false,
    this.showAppBar = true,
  });

  final String? studentId;
  final String? studentName;
  final bool mine;
  final bool showAppBar;

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  late final AsyncController<StudentResults> _ctrl;

  @override
  void initState() {
    super.initState();
    final api = context.read<ApiService>();
    _ctrl = AsyncController(() =>
        widget.mine ? api.myResults() : api.studentResults(widget.studentId!))
      ..load();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final body = ListenableBuilder(
      listenable: _ctrl,
      builder: (context, _) {
        if (_ctrl.isFirstLoad) return const SkeletonList(height: 96);
        if (_ctrl.error != null && !_ctrl.hasData) {
          return ErrorView(error: _ctrl.error!, onRetry: _ctrl.load);
        }
        final r = _ctrl.data!;

        if (r.results.isEmpty) {
          return const EmptyView(
            icon: Icons.emoji_events_outlined,
            title: 'No results yet',
            message:
                'Results appear here once an exam has been marked and published.',
          );
        }

        return RefreshIndicator(
          onRefresh: _ctrl.refresh,
          child: ListView(
            padding:
                const EdgeInsets.fromLTRB(Gap.lg, Gap.lg, Gap.lg, Gap.xxl),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(Gap.xl),
                  child: Column(
                    children: [
                      Text(
                        Fmt.percent(r.averagePercentage),
                        style: Theme.of(context)
                            .textTheme
                            .displaySmall
                            ?.copyWith(
                              fontWeight: FontWeight.w700,
                              letterSpacing: -1.5,
                              color: scheme.primary,
                            ),
                      ),
                      Text(
                        'average across ${r.examsTaken} exam${r.examsTaken == 1 ? '' : 's'}',
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: Gap.xl),
                      Row(
                        children: [
                          _Stat('Best score',
                              Fmt.percent(r.bestPercentage), StatusColors.present),
                          _Stat(
                            'Best rank',
                            r.bestRank == null ? '—' : '#${r.bestRank}',
                            const Color(0xFF6172F3),
                          ),
                          _Stat('Exams', '${r.examsTaken}', scheme.primary),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SectionHeader(
                title: 'Exam results',
                padding: EdgeInsets.only(top: Gap.xl, bottom: Gap.md),
              ),
              ...r.results.map(
                (res) => Padding(
                  padding: const EdgeInsets.only(bottom: Gap.md),
                  child: ResultCard(result: res),
                ),
              ),
            ],
          ),
        );
      },
    );

    if (!widget.showAppBar) return body;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.mine ? 'My results' : 'Results'),
        bottom: widget.studentName == null
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(20),
                child: Padding(
                  padding: const EdgeInsets.only(left: Gap.lg, bottom: Gap.sm),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      widget.studentName!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                  ),
                ),
              ),
      ),
      body: body,
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value, this.color);
  final String label, value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: color,
              fontSize: 16,
            ),
          ),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 11.5,
                ),
          ),
        ],
      ),
    );
  }
}

class ResultCard extends StatefulWidget {
  const ResultCard({super.key, required this.result, this.initiallyOpen = false});
  final ExamResult result;
  final bool initiallyOpen;

  @override
  State<ResultCard> createState() => _ResultCardState();
}

class _ResultCardState extends State<ResultCard> {
  late bool _open = widget.initiallyOpen;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final r = widget.result;
    final color = gradeColor(r.grade);

    return Card(
      child: InkWell(
        onTap: () => setState(() => _open = !_open),
        borderRadius: BorderRadius.circular(kRadius),
        child: Padding(
          padding: const EdgeInsets.all(Gap.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      r.grade ?? '—',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: color,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  const SizedBox(width: Gap.lg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          r.examName ?? r.student?.name ?? 'Exam',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          [
                            if (r.examDate != null) Fmt.date(r.examDate),
                            if (r.rank != null)
                              'Rank #${r.rank}${r.classSize != null ? ' of ${r.classSize}' : ''}',
                          ].join(' · '),
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
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${r.obtained}/${r.totalMarks}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        Fmt.percent(r.percentage),
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: Gap.md),
              MeterBar(value: r.percentage, height: 6, color: color),
              AnimatedCrossFade(
                duration: const Duration(milliseconds: 220),
                crossFadeState: _open
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                firstChild: const SizedBox(width: double.infinity),
                secondChild: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Divider(height: Gap.xl),
                    ...r.marks.map(
                      (m) => Padding(
                        padding: const EdgeInsets.only(bottom: Gap.md),
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
                              width: 92,
                              child: MeterBar(
                                value: m.maxMarks == 0
                                    ? 0
                                    : ((m.marksObtained ?? 0) /
                                            m.maxMarks *
                                            100)
                                        .toDouble(),
                                height: 5,
                              ),
                            ),
                            const SizedBox(width: Gap.md),
                            Text(
                              '${m.marksObtained ?? '—'}/${m.maxMarks}',
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (r.remarks != null && r.remarks!.isNotEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(Gap.md),
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerHighest
                              .withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(kRadiusSm),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.comment_outlined,
                                size: 15, color: scheme.onSurfaceVariant),
                            const SizedBox(width: Gap.sm),
                            Expanded(
                              child: Text(
                                r.remarks!,
                                style: const TextStyle(fontSize: 12.5),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              if (r.marks.isNotEmpty)
                Center(
                  child: Icon(
                    _open
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    size: 20,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
