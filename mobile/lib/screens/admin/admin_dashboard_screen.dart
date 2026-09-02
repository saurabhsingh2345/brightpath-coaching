import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/brand.dart';
import '../../core/formatters.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../state/async_value.dart';
import '../../state/auth_state.dart';
import '../../widgets/common.dart';
import '../../widgets/states.dart';
import 'announcements_screen.dart';
import 'exams_screen.dart';
import 'fees_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  late final AsyncController<AdminDashboard> _ctrl;

  @override
  void initState() {
    super.initState();
    final api = context.read<ApiService>();
    _ctrl = AsyncController(api.adminDashboard)..load();
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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hello, ${user?.name.split(' ').first ?? 'Admin'}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Text(
              Brand.fullName,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
        actions: [
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
                // ── key metrics ──
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Gap.lg),
                  child: GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: Gap.md,
                    mainAxisSpacing: Gap.md,
                    childAspectRatio: 1.06,
                    children: [
                      StatCard(
                        label: 'Total students',
                        value: '${d.totalStudents}',
                        sublabel: '${d.activeStudents} active',
                        icon: Icons.people_alt_rounded,
                      ),
                      StatCard(
                        label: 'Batches',
                        value: '${d.totalBatches}',
                        sublabel: '${d.activeBatches} running',
                        icon: Icons.groups_rounded,
                        tint: const Color(0xFF6172F3),
                      ),
                      StatCard(
                        label: "Today's attendance",
                        value: d.todayIsMarked
                            ? Fmt.percent(d.todayAttendance)
                            : '—',
                        sublabel: d.todayIsMarked
                            ? '${d.todayMarked} of ${d.todayExpected} marked'
                            : 'Not marked yet',
                        icon: Icons.fact_check_rounded,
                        tint: d.todayIsMarked
                            ? StatusColors.present
                            : StatusColors.pending,
                      ),
                      StatCard(
                        label: 'Pending fees',
                        value: Fmt.moneyCompact(d.pending),
                        sublabel: d.overdueInstallments > 0
                            ? '${d.overdueInstallments} overdue'
                            : 'All on schedule',
                        icon: Icons.payments_rounded,
                        tint: d.overdueInstallments > 0
                            ? StatusColors.overdue
                            : StatusColors.partial,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const FeesScreen()),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── fee collection ──
                const SectionHeader(title: 'Fee collection'),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Gap.lg),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(Gap.lg),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      Fmt.money(d.collected),
                                      style: Theme.of(context)
                                          .textTheme
                                          .headlineSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: -0.8,
                                          ),
                                    ),
                                    Text(
                                      'collected of ${Fmt.money(d.totalFee)}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: scheme.onSurfaceVariant,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              StatusPill(
                                label: Fmt.percent(d.collectionRate),
                                color: d.collectionRate >= 75
                                    ? StatusColors.paid
                                    : StatusColors.partial,
                              ),
                            ],
                          ),
                          const SizedBox(height: Gap.lg),
                          MeterBar(
                            value: d.collectionRate,
                            color: d.collectionRate >= 75
                                ? StatusColors.paid
                                : StatusColors.partial,
                          ),
                          const SizedBox(height: Gap.lg),
                          Row(
                            children: [
                              _MiniStat(
                                label: 'Pending',
                                value: Fmt.money(d.pending),
                                color: StatusColors.pending,
                              ),
                              _MiniStat(
                                label: 'Overdue',
                                value: Fmt.money(d.overdueAmount),
                                color: StatusColors.overdue,
                              ),
                              _MiniStat(
                                label: 'Installments',
                                value: '${d.pendingInstallments} open',
                                color: scheme.primary,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // ── upcoming exams ──
                if (d.upcomingExams.isNotEmpty) ...[
                  SectionHeader(
                    title: 'Upcoming exams',
                    actionLabel: 'All exams',
                    onAction: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ExamsScreen(),
                      ),
                    ),
                  ),
                  ...d.upcomingExams.take(3).map(
                        (e) => Padding(
                          padding: const EdgeInsets.only(
                            left: Gap.lg,
                            right: Gap.lg,
                            bottom: Gap.md,
                          ),
                          child: Card(
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: Gap.lg,
                                vertical: Gap.xs,
                              ),
                              leading: Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: scheme.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(Icons.assignment_outlined,
                                    size: 20, color: scheme.primary),
                              ),
                              title: Text(
                                e.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600),
                              ),
                              subtitle: Text(
                                '${e.batchName ?? '—'} · ${Fmt.date(e.examDate)}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ),
                      ),
                ],

                // ── recent announcements ──
                SectionHeader(
                  title: 'Recent announcements',
                  actionLabel: 'Manage',
                  onAction: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AnnouncementsScreen(),
                    ),
                  ),
                ),
                if (d.announcements.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: Gap.lg),
                    child: Card(
                      child: Padding(
                        padding: EdgeInsets.all(Gap.xl),
                        child: Center(
                          child: Text('No announcements yet.'),
                        ),
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

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: color,
              fontSize: 14.5,
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
