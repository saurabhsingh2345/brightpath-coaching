import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/formatters.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../state/async_value.dart';
import '../../widgets/common.dart';
import '../../widgets/states.dart';

/// Attendance report for one student. Admins pass a [studentId]; a student
/// passes `mine: true` and the server resolves their own profile.
class AttendanceReportScreen extends StatefulWidget {
  const AttendanceReportScreen({
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
  State<AttendanceReportScreen> createState() =>
      _AttendanceReportScreenState();
}

class _AttendanceReportScreenState extends State<AttendanceReportScreen> {
  late final AsyncController<AttendanceReport> _ctrl;

  @override
  void initState() {
    super.initState();
    final api = context.read<ApiService>();
    _ctrl = AsyncController(() =>
        widget.mine ? api.myAttendance() : api.studentAttendance(widget.studentId!))
      ..load();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final body = ListenableBuilder(
      listenable: _ctrl,
      builder: (context, _) {
        if (_ctrl.isFirstLoad) return const SkeletonList(height: 64);
        if (_ctrl.error != null && !_ctrl.hasData) {
          return ErrorView(error: _ctrl.error!, onRetry: _ctrl.load);
        }
        final report = _ctrl.data!;
        final s = report.summary;

        return RefreshIndicator(
          onRefresh: _ctrl.refresh,
          child: ListView(
            padding:
                const EdgeInsets.fromLTRB(Gap.lg, Gap.lg, Gap.lg, Gap.xxl),
            children: [
              AttendanceSummaryCard(summary: s),
              const SectionHeader(
                title: 'History',
                padding: EdgeInsets.only(top: Gap.xl, bottom: Gap.md),
              ),
              if (report.records.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(Gap.xl),
                    child: Center(
                      child: Text(
                        'No attendance recorded yet.',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                )
              else
                ...report.records.map(
                  (r) => Padding(
                    padding: const EdgeInsets.only(bottom: Gap.sm),
                    child: AttendanceRecordTile(record: r),
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
        title: Text(widget.mine ? 'My attendance' : 'Attendance'),
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
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
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

class AttendanceSummaryCard extends StatelessWidget {
  const AttendanceSummaryCard({super.key, required this.summary});
  final AttendanceSummary summary;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final good = summary.percentage >= 75;
    final color = good ? StatusColors.present : StatusColors.late;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Gap.xl),
        child: Column(
          children: [
            Text(
              Fmt.percent(summary.percentage),
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: -1.5,
                    color: color,
                  ),
            ),
            Text(
              'overall attendance',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
            if (summary.total > 0 && !good) ...[
              const SizedBox(height: Gap.md),
              const StatusPill(
                label: 'BELOW 75%',
                color: StatusColors.late,
                icon: Icons.warning_amber_rounded,
              ),
            ],
            const SizedBox(height: Gap.xl),
            MeterBar(value: summary.percentage, color: color),
            const SizedBox(height: Gap.xl),
            Row(
              children: [
                _Cell('Present', summary.present, StatusColors.present),
                _Cell('Absent', summary.absent, StatusColors.absent),
                _Cell('Late', summary.late, StatusColors.late),
                _Cell('Leave', summary.leave, StatusColors.leave),
              ],
            ),
            const SizedBox(height: Gap.lg),
            Text(
              '${summary.total} classes recorded · leave is excluded from the percentage',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontSize: 11.5,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell(this.label, this.value, this.color);
  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Text(
              '$value',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: color,
                fontSize: 15,
              ),
            ),
          ),
          const SizedBox(height: Gap.xs),
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

class AttendanceRecordTile extends StatelessWidget {
  const AttendanceRecordTile({super.key, required this.record});
  final AttendanceRecord record;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = StatusColors.forAttendance(record.status);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Gap.lg,
          vertical: Gap.md,
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    Fmt.parse(record.date)?.day.toString() ?? '—',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: color,
                      fontSize: 15,
                      height: 1,
                    ),
                  ),
                  Text(
                    Fmt.dateShort(record.date).split(' ').last,
                    style: TextStyle(
                      color: color,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: Gap.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    Fmt.dayName(record.date),
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    record.remarks?.isNotEmpty == true
                        ? record.remarks!
                        : (record.subject ?? record.batchName ?? '—'),
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
            StatusPill(
              label: Fmt.titleCase(record.status),
              color: color,
              dense: true,
            ),
          ],
        ),
      ),
    );
  }
}
