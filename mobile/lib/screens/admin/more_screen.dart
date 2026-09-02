import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../state/auth_state.dart';
import '../../widgets/common.dart';
import '../shared/materials_screen.dart';
import '../shared/profile_screen.dart';
import '../shared/timetable_screen.dart';
import 'announcements_screen.dart';
import 'batches_screen.dart';
import 'fees_screen.dart';
import 'exams_screen.dart';

/// Everything that does not fit in the five-item bottom bar.
class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final user = context.watch<AuthState>().user;

    final tiles = <({IconData icon, String label, String subtitle, Widget page, Color tint})>[
      (
        icon: Icons.payments_rounded,
        label: 'Fees & payments',
        subtitle: 'Installments, collections and receipts',
        page: const FeesScreen(),
        tint: const Color(0xFFF04438),
      ),
      (
        icon: Icons.groups_rounded,
        label: 'Batches',
        subtitle: 'Courses, timings and rooms',
        page: const BatchesScreen(),
        tint: const Color(0xFF6172F3),
      ),
      (
        icon: Icons.calendar_month_rounded,
        label: 'Timetable',
        subtitle: 'Weekly class schedule',
        page: const TimetableScreen(),
        tint: const Color(0xFF06AED4),
      ),
      (
        icon: Icons.assignment_rounded,
        label: 'Exams & results',
        subtitle: 'Marks, ranks and publishing',
        page: const ExamsScreen(),
        tint: const Color(0xFFF79009),
      ),
      (
        icon: Icons.folder_rounded,
        label: 'Study material',
        subtitle: 'Upload PDFs and documents',
        page: const MaterialsScreen(),
        tint: const Color(0xFF12B76A),
      ),
      (
        icon: Icons.campaign_rounded,
        label: 'Announcements',
        subtitle: 'Notify everyone or one batch',
        page: const AnnouncementsScreen(),
        tint: const Color(0xFFEE46BC),
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('More')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Gap.lg, 0, Gap.lg, Gap.xxl),
        children: [
          // ── profile card ──
          Card(
            child: InkWell(
              borderRadius: BorderRadius.circular(kRadius),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              ),
              child: Padding(
                padding: const EdgeInsets.all(Gap.lg),
                child: Row(
                  children: [
                    InitialsAvatar(name: user?.name ?? 'A', size: 50),
                    const SizedBox(width: Gap.lg),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user?.name ?? 'Admin',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            user?.email ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12.5,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: Gap.sm),
                          StatusPill(
                            label: 'ADMINISTRATOR',
                            color: scheme.primary,
                            icon: Icons.shield_rounded,
                            dense: true,
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
          const SectionHeader(
            title: 'Manage',
            padding: EdgeInsets.only(top: Gap.xl, bottom: Gap.md),
          ),
          ...tiles.map(
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
        ],
      ),
    );
  }
}
