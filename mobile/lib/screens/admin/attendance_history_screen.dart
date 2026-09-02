import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/formatters.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../state/async_value.dart';
import '../../widgets/common.dart';
import '../../widgets/states.dart';

/// Day-by-day roll-up for a batch, with a drill-down into one day's records.
class AttendanceHistoryScreen extends StatefulWidget {
  const AttendanceHistoryScreen({super.key, required this.batches});
  final List<Batch> batches;

  @override
  State<AttendanceHistoryScreen> createState() =>
      _AttendanceHistoryScreenState();
}

class _AttendanceHistoryScreenState extends State<AttendanceHistoryScreen> {
  late final ApiService _api;
  late final AsyncController<List<AttendanceDay>> _ctrl;
  Batch? _batch;

  @override
  void initState() {
    super.initState();
    _api = context.read<ApiService>();
    _batch = widget.batches.isEmpty ? null : widget.batches.first;
    _ctrl = AsyncController(_fetch);
    if (_batch != null) _ctrl.load();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<List<AttendanceDay>> _fetch() async {
    if (_batch == null) return const [];
    return _api.attendanceDays(_batch!.id);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Attendance history')),
      body: Column(
        children: [
          if (widget.batches.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(Gap.lg, 0, Gap.lg, Gap.md),
              child: DropdownButtonFormField<String>(
                initialValue: _batch?.id,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Batch',
                  isDense: true,
                ),
                items: widget.batches
                    .map((b) => DropdownMenuItem(
                          value: b.id,
                          child: Text(b.name, overflow: TextOverflow.ellipsis),
                        ))
                    .toList(),
                onChanged: (v) {
                  setState(() =>
                      _batch = widget.batches.firstWhere((b) => b.id == v));
                  _ctrl.load();
                },
              ),
            ),
          Expanded(
            child: ListenableBuilder(
              listenable: _ctrl,
              builder: (context, _) {
                if (widget.batches.isEmpty) {
                  return const EmptyView(
                    icon: Icons.groups_outlined,
                    title: 'No batches',
                    message: 'Create a batch first.',
                  );
                }
                if (_ctrl.isFirstLoad) return const SkeletonList(height: 72);
                if (_ctrl.error != null && !_ctrl.hasData) {
                  return ErrorView(error: _ctrl.error!, onRetry: _ctrl.load);
                }
                final days = _ctrl.data ?? const <AttendanceDay>[];
                if (days.isEmpty) {
                  return EmptyView(
                    icon: Icons.event_busy_outlined,
                    title: 'No attendance recorded',
                    message:
                        'Nothing has been marked for ${_batch?.name ?? 'this batch'} yet.',
                  );
                }
                return RefreshIndicator(
                  onRefresh: _ctrl.refresh,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(
                        Gap.lg, Gap.sm, Gap.lg, Gap.xxl),
                    itemCount: days.length,
                    separatorBuilder: (_, __) => const SizedBox(height: Gap.md),
                    itemBuilder: (context, i) {
                      final d = days[i];
                      final good = d.percentage >= 75;
                      return Card(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(kRadius),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => _DayDetailScreen(
                                batchId: _batch!.id,
                                batchName: _batch!.name,
                                date: d.date,
                              ),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(Gap.lg),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            Fmt.date(d.date),
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 14.5,
                                            ),
                                          ),
                                          Text(
                                            '${Fmt.dayName(d.date)} · ${d.total} marked',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: scheme.onSurfaceVariant,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    StatusPill(
                                      label: Fmt.percent(d.percentage),
                                      color: good
                                          ? StatusColors.present
                                          : StatusColors.late,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: Gap.md),
                                MeterBar(
                                  value: d.percentage,
                                  height: 6,
                                  color: good
                                      ? StatusColors.present
                                      : StatusColors.late,
                                ),
                                const SizedBox(height: Gap.md),
                                Row(
                                  children: [
                                    _Count('Present', d.present,
                                        StatusColors.present),
                                    _Count('Absent', d.absent,
                                        StatusColors.absent),
                                    _Count('Late', d.late, StatusColors.late),
                                    _Count('Leave', d.leave,
                                        StatusColors.leave),
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
    );
  }
}

class _Count extends StatelessWidget {
  const _Count(this.label, this.value, this.color);
  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            '$value',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: color,
              fontSize: 15,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _DayDetailScreen extends StatefulWidget {
  const _DayDetailScreen({
    required this.batchId,
    required this.batchName,
    required this.date,
  });

  final String batchId, batchName, date;

  @override
  State<_DayDetailScreen> createState() => _DayDetailScreenState();
}

class _DayDetailScreenState extends State<_DayDetailScreen> {
  late final AsyncController<List<AttendanceRecord>> _ctrl;

  @override
  void initState() {
    super.initState();
    final api = context.read<ApiService>();
    _ctrl = AsyncController(() => api.attendanceHistory(
          batchId: widget.batchId,
          from: widget.date,
          to: widget.date,
        ))
      ..load();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(Fmt.date(widget.date)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(20),
          child: Padding(
            padding: const EdgeInsets.only(left: Gap.lg, bottom: Gap.sm),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                widget.batchName,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ),
          ),
        ),
      ),
      body: ListenableBuilder(
        listenable: _ctrl,
        builder: (context, _) {
          if (_ctrl.isFirstLoad) return const SkeletonList(height: 62);
          if (_ctrl.error != null && !_ctrl.hasData) {
            return ErrorView(error: _ctrl.error!, onRetry: _ctrl.load);
          }
          final records = _ctrl.data ?? const <AttendanceRecord>[];
          if (records.isEmpty) {
            return const EmptyView(
              icon: Icons.event_busy_outlined,
              title: 'Nothing recorded',
              message: 'No attendance was marked on this date.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(Gap.lg),
            itemCount: records.length,
            separatorBuilder: (_, __) => const SizedBox(height: Gap.sm),
            itemBuilder: (context, i) {
              final r = records[i];
              final color = StatusColors.forAttendance(r.status);
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(Gap.md),
                  child: Row(
                    children: [
                      InitialsAvatar(name: r.student?.name ?? '?', size: 38),
                      const SizedBox(width: Gap.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              r.student?.name ?? '—',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            if (r.remarks != null && r.remarks!.isNotEmpty)
                              Text(
                                r.remarks!,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                              ),
                          ],
                        ),
                      ),
                      StatusPill(
                        label: Fmt.titleCase(r.status),
                        color: color,
                        dense: true,
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
