import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../state/auth_state.dart';
import '../../widgets/common.dart';
import '../shared/attendance_report_screen.dart';
import '../shared/profile_screen.dart';
import '../shared/results_screen.dart';
import '../admin/student_fees_screen.dart';
import '../admin/announcements_screen.dart';

/// The student's "Me" tab: quick links plus the shared profile screen.
class StudentMoreScreen extends StatelessWidget {
  const StudentMoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final user = context.watch<AuthState>().user;

    final links = <({IconData icon, String label, String subtitle, Widget page, Color tint})>[
      (
        icon: Icons.fact_check_rounded,
        label: 'My attendance',
        subtitle: 'Day-by-day record and percentage',
        page: const AttendanceReportScreen(mine: true),
        tint: const Color(0xFF12B76A),
      ),
      (
        icon: Icons.payments_rounded,
        label: 'My fees',
        subtitle: 'Installments, payments and receipts',
        page: StudentFeesScreen(
          studentId: user?.studentId ?? '',
          studentName: user?.name ?? '',
          readOnly: true,
        ),
        tint: const Color(0xFFF79009),
      ),
      (
        icon: Icons.emoji_events_rounded,
        label: 'My results',
        subtitle: 'Marks, grades and ranks',
        page: const ResultsScreen(mine: true),
        tint: const Color(0xFF6172F3),
      ),
      (
        icon: Icons.campaign_rounded,
        label: 'Announcements',
        subtitle: 'Notices from the institute',
        page: const AnnouncementsScreen(mine: true),
        tint: const Color(0xFFEE46BC),
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Me')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Gap.lg, 0, Gap.lg, Gap.xxl),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(Gap.lg),
              child: Row(
                children: [
                  InitialsAvatar(name: user?.name ?? 'S', size: 50),
                  const SizedBox(width: Gap.lg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.name ?? 'Student',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          user?.studentCode ?? user?.email ?? '',
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
                ],
              ),
            ),
          ),
          const SectionHeader(
            title: 'My records',
            padding: EdgeInsets.only(top: Gap.xl, bottom: Gap.md),
          ),
          ...links.map(
            (t) => Padding(
              padding: const EdgeInsets.only(bottom: Gap.md),
              child: Card(
                child: InkWell(
                  borderRadius: BorderRadius.circular(kRadius),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => t.page),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(Gap.lg),
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: t.tint.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(t.icon, size: 20, color: t.tint),
                        ),
                        const SizedBox(width: Gap.lg),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                t.label,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14.5,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                t.subtitle,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right_rounded,
                            size: 20, color: scheme.onSurfaceVariant),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SectionHeader(
            title: 'Account',
            padding: EdgeInsets.only(top: Gap.lg, bottom: Gap.md),
          ),
          Card(
            child: InkWell(
              borderRadius: BorderRadius.circular(kRadius),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              ),
              child: const Padding(
                padding: EdgeInsets.all(Gap.lg),
                child: Row(
                  children: [
                    Icon(Icons.settings_outlined, size: 21),
                    SizedBox(width: Gap.lg),
                    Expanded(
                      child: Text(
                        'Profile & settings',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, size: 20),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
