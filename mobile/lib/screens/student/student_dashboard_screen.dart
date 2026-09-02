import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/formatters.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../state/async_value.dart';
import '../../state/auth_state.dart';
import '../../widgets/common.dart';
import '../../widgets/states.dart';
import '../../widgets/theme_button.dart';
import '../admin/announcements_screen.dart';
import '../admin/student_fees_screen.dart';
import '../shared/attendance_report_screen.dart';
import '../shared/results_screen.dart';

class StudentDashboardScreen extends StatefulWidget {
  const StudentDashboardScreen({super.key});

  @override
  State<StudentDashboardScreen> createState() =>
      _StudentDashboardScreenState();
}

class _StudentDashboardScreenState extends State<StudentDashboardScreen> {
  late final AsyncController<StudentDashboard> _ctrl;

  @override
  void initState() {
    super.initState();
    final api = context.read<ApiService>();
    _ctrl = AsyncController(api.studentDashboard)..load();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final user = context.watch<AuthState>().user;

    return Scaffold(
      appBar: AppBar(
        title: ListenableBuilder(
          listenable: _ctrl,
          builder: (context, _) {
            final d = _ctrl.data;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hi, ${(d?.name ?? user?.name ?? 'there').split(' ').first}',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Text(
                  d?.batch?.name ?? d?.course ?? 'Student',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
              ],
            );
          },
        ),
        actions: [
          const ThemeToggleButton(),
          IconButton(
            tooltip: 'Refresh',
            onPressed: () => _ctrl.load(),
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: Gap.sm),
        ],
      ),
      body: ListenableBuilder(
        listenable: _ctrl,
        builder: (context, _) {
          if (_ctrl.isFirstLoad) return const SkeletonList(count: 4, height: 110);
          if (_ctrl.error != null && !_ctrl.hasData) {
            return ErrorView(error: _ctrl.error!, onRetry: _ctrl.load);
          }
          final d = _ctrl.data!;

          return RefreshIndicator(
            onRefresh: _ctrl.refresh,
            child: ListView(
              padding: const EdgeInsets.only(bottom: Gap.xxl),
              children: [
                // ── next class ──
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Gap.lg),
                  child: _NextClassCard(next: d.nextClass),
                ),

                const SizedBox(height: Gap.lg),

                // ── key metrics ──
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Gap.lg),
                  child: Row(
                    children: [
                      Expanded(
                        child: StatCard(
                          label: 'Attendance',
                          value: Fmt.percent(d.attendance.percentage),
                          sublabel:
                              '${d.attendance.present + d.attendance.late} of ${d.attendance.total} classes',
                          icon: Icons.fact_check_rounded,
                          tint: d.attendance.percentage >= 75
                              ? StatusColors.present
                              : StatusColors.late,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  const AttendanceReportScreen(mine: true),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: Gap.md),
                      Expanded(
                        child: StatCard(
                          label: 'Fees due',
                          value: Fmt.moneyCompact(d.fees.due),
                          sublabel: d.fees.overdue > 0
                              ? '${Fmt.moneyCompact(d.fees.overdue)} overdue'
                              : (d.fees.due > 0 ? 'On schedule' : 'All cleared'),
                          icon: Icons.payments_rounded,
                          tint: d.fees.overdue > 0
                              ? StatusColors.overdue
                              : (d.fees.due > 0
                                  ? StatusColors.partial
                                  : StatusColors.paid),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => StudentFeesScreen(
                                studentId: user?.studentId ?? '',
                                studentName: d.name,
                                readOnly: true,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── today's attendance ──
                if (d.attendance.todayStatus != null) ...[
                  const SizedBox(height: Gap.md),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Gap.lg),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(Gap.lg),
                        child: Row(
                          children: [
                            Icon(
                              Icons.today_rounded,
                              size: 19,
                              color: StatusColors.forAttendance(
                                  d.attendance.todayStatus),
                            ),
                            const SizedBox(width: Gap.md),
                            const Expanded(
                              child: Text(
                                'Today you were marked',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            StatusPill(
                              label:
                                  Fmt.titleCase(d.attendance.todayStatus),
                              color: StatusColors.forAttendance(
                                  d.attendance.todayStatus),
                              dense: true,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],

                // ── next fee due ──
                if (d.fees.nextDueDate != null && d.fees.nextDueAmount > 0) ...[
                  const SizedBox(height: Gap.md),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Gap.lg),
                    child: Card(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(kRadius),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => StudentFeesScreen(
                              studentId: user?.studentId ?? '',
                              studentName: d.name,
                              readOnly: true,
                            ),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(Gap.lg),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: StatusColors.partial
                                      .withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(11),
                                ),
                                child: const Icon(Icons.event_outlined,
                                    size: 19, color: StatusColors.partial),
                              ),
                              const SizedBox(width: Gap.lg),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Next payment · ${d.fees.nextDueTitle ?? 'installment'}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13.5,
                                      ),
                                    ),
                                    Text(
                                      'Due ${Fmt.date(d.fees.nextDueDate)}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: scheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                Fmt.money(d.fees.nextDueAmount),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],

                // ── recent results ──
                if (d.recentResults.isNotEmpty) ...[
                  SectionHeader(
                    title: 'Recent results',
                    actionLabel: 'All results',
                    onAction: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ResultsScreen(mine: true),
                      ),
                    ),
                  ),
                  ...d.recentResults.map(
                    (r) => Padding(
                      padding: const EdgeInsets.only(
                        left: Gap.lg,
                        right: Gap.lg,
                        bottom: Gap.md,
                      ),
                      child: ResultCard(result: r),
                    ),
                  ),
                ],

                // ── announcements ──
                SectionHeader(
                  title: 'Announcements',
                  actionLabel: d.announcements.isEmpty ? null : 'See all',
                  onAction: d.announcements.isEmpty
                      ? null
                      : () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  const AnnouncementsScreen(mine: true),
                            ),
                          ),
                ),
                if (d.announcements.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: Gap.lg),
                    child: Card(
                      child: Padding(
                        padding: EdgeInsets.all(Gap.xl),
                        child: Center(child: Text('Nothing new right now.')),
                      ),
                    ),
                  )
                else
                  ...d.announcements.map(
                    (a) => Padding(
                      padding: const EdgeInsets.only(
                        left: Gap.lg,
                        right: Gap.lg,
                        bottom: Gap.md,
                      ),
                      child: AnnouncementCard(announcement: a),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _NextClassCard extends StatelessWidget {
  const _NextClassCard({required this.next});
  final NextClass? next;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    if (next == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(Gap.xl),
          child: Row(
            children: [
              Icon(Icons.event_available_outlined,
                  size: 24, color: scheme.onSurfaceVariant),
              const SizedBox(width: Gap.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'No upcoming class',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14.5,
                      ),
                    ),
                    Text(
                      'Your timetable has not been set up yet.',
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    final n = next!;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [scheme.primary, scheme.primary.withValues(alpha: 0.78)],
        ),
        borderRadius: BorderRadius.circular(kRadius),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withValues(alpha: 0.24),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(Gap.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.schedule_rounded, size: 15, color: Colors.white70),
              const SizedBox(width: Gap.xs),
              Text(
                n.isToday
                    ? 'NEXT CLASS TODAY'
                    : 'NEXT CLASS · ${Fmt.titleCase(n.weekday).toUpperCase()}',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: Gap.sm, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  Fmt.inMinutes(n.startsInMinutes),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: Gap.md),
          Text(
            n.subject,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: Gap.sm),
          Row(
            children: [
              const Icon(Icons.access_time_rounded,
                  size: 14, color: Colors.white70),
              const SizedBox(width: 4),
              Text(
                Fmt.timeRange(n.startTime, n.endTime),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: Gap.lg),
              const Icon(Icons.room_outlined, size: 14, color: Colors.white70),
              const SizedBox(width: 4),
              Text(
                n.room,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          if (n.teacher != null) ...[
            const SizedBox(height: Gap.xs),
            Row(
              children: [
                const Icon(Icons.person_outline_rounded,
                    size: 14, color: Colors.white70),
                const SizedBox(width: 4),
                Text(
                  n.teacher!,
                  style: const TextStyle(color: Colors.white70, fontSize: 12.5),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
