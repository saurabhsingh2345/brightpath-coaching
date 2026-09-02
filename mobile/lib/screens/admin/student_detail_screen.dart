import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/api_exception.dart';
import '../../core/formatters.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../state/async_value.dart';
import '../../widgets/common.dart';
import '../../widgets/states.dart';
import 'student_form_screen.dart';
import 'student_fees_screen.dart';
import '../shared/attendance_report_screen.dart';
import '../shared/results_screen.dart';

class StudentDetailScreen extends StatefulWidget {
  const StudentDetailScreen({super.key, required this.studentId});
  final String studentId;

  @override
  State<StudentDetailScreen> createState() => _StudentDetailScreenState();
}

class _StudentDetailScreenState extends State<StudentDetailScreen> {
  late final ApiService _api;
  late final AsyncController<Student> _ctrl;
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    _api = context.read<ApiService>();
    _ctrl = AsyncController(() => _api.student(widget.studentId))..load();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _call(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (!await launchUrl(uri) && mounted) {
      showSnack(context, 'Could not open the dialler', isError: true);
    }
  }

  Future<void> _toggleActive(Student s) async {
    final deactivating = s.isActive;
    final ok = await confirm(
      context,
      title: deactivating ? 'Deactivate student?' : 'Reactivate student?',
      message: deactivating
          ? '${s.name} will no longer be able to log in. All attendance, fee and exam history is kept.'
          : '${s.name} will be able to log in again.',
      confirmLabel: deactivating ? 'Deactivate' : 'Reactivate',
      destructive: deactivating,
    );
    if (!ok) return;
    try {
      final msg = await _api.setStudentActive(s.id, !s.isActive);
      _changed = true;
      await _ctrl.load();
      if (mounted) showSnack(context, msg);
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, isError: true);
    }
  }

  Future<void> _delete(Student s) async {
    final ok = await confirm(
      context,
      title: 'Delete permanently?',
      message:
          'This removes ${s.name} and every attendance, fee and exam record attached to them. This cannot be undone.\n\nConsider deactivating instead.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok) return;
    try {
      await _api.deleteStudent(s.id);
      if (!mounted) return;
      showSnack(context, '${s.name} deleted');
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {},
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Student'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => Navigator.pop(context, _changed),
          ),
          actions: [
            ListenableBuilder(
              listenable: _ctrl,
              builder: (context, _) {
                final s = _ctrl.data;
                if (s == null) return const SizedBox.shrink();
                return PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded),
                  onSelected: (v) async {
                    switch (v) {
                      case 'edit':
                        final changed = await Navigator.push<bool>(
                          context,
                          MaterialPageRoute(
                            builder: (_) => StudentFormScreen(student: s),
                          ),
                        );
                        if (changed == true) {
                          _changed = true;
                          _ctrl.load();
                        }
                      case 'toggle':
                        _toggleActive(s);
                      case 'delete':
                        _delete(s);
                    }
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.edit_outlined, size: 20),
                        title: Text('Edit details'),
                      ),
                    ),
                    PopupMenuItem(
                      value: 'toggle',
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          s.isActive
                              ? Icons.person_off_outlined
                              : Icons.person_add_alt_rounded,
                          size: 20,
                        ),
                        title: Text(s.isActive ? 'Deactivate' : 'Reactivate'),
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.delete_outline_rounded,
                            size: 20, color: scheme.error),
                        title: Text('Delete',
                            style: TextStyle(color: scheme.error)),
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(width: Gap.xs),
          ],
        ),
        body: ListenableBuilder(
          listenable: _ctrl,
          builder: (context, _) {
            if (_ctrl.isFirstLoad) return const LoadingView();
            if (_ctrl.error != null && !_ctrl.hasData) {
              return ErrorView(error: _ctrl.error!, onRetry: _ctrl.load);
            }
            final s = _ctrl.data!;
            final att = s.attendanceSummary;
            final fee = s.feeSummary;

            return RefreshIndicator(
              onRefresh: _ctrl.refresh,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.lg, Gap.lg, Gap.xxl),
                children: [
                  // ── header ──
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(Gap.xl),
                      child: Column(
                        children: [
                          InitialsAvatar(name: s.name, size: 72),
                          const SizedBox(height: Gap.lg),
                          Text(
                            s.name,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: Gap.xs),
                          Text(
                            s.studentCode,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                          const SizedBox(height: Gap.md),
                          Wrap(
                            spacing: Gap.sm,
                            runSpacing: Gap.sm,
                            alignment: WrapAlignment.center,
                            children: [
                              StatusPill(
                                label: s.isActive ? 'ACTIVE' : 'INACTIVE',
                                color: s.isActive
                                    ? StatusColors.present
                                    : StatusColors.pending,
                                icon: s.isActive
                                    ? Icons.check_circle_rounded
                                    : Icons.pause_circle_rounded,
                              ),
                              StatusPill(
                                label: s.batch?.name ?? 'NO BATCH',
                                color: s.batch == null
                                    ? StatusColors.partial
                                    : scheme.primary,
                                icon: Icons.groups_rounded,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ── quick stats ──
                  if (att != null || fee != null) ...[
                    const SizedBox(height: Gap.lg),
                    Row(
                      children: [
                        if (att != null)
                          Expanded(
                            child: StatCard(
                              label: 'Attendance',
                              value: Fmt.percent(att.percentage),
                              sublabel: '${att.present + att.late}/${att.total} classes',
                              icon: Icons.fact_check_rounded,
                              tint: att.percentage >= 75
                                  ? StatusColors.present
                                  : StatusColors.late,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => AttendanceReportScreen(
                                    studentId: s.id,
                                    studentName: s.name,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        if (att != null && fee != null)
                          const SizedBox(width: Gap.md),
                        if (fee != null)
                          Expanded(
                            child: StatCard(
                              label: 'Fees due',
                              value: Fmt.moneyCompact(fee.due),
                              sublabel: fee.overdue > 0
                                  ? '${Fmt.moneyCompact(fee.overdue)} overdue'
                                  : '${fee.installments} installments',
                              icon: Icons.payments_rounded,
                              tint: fee.overdue > 0
                                  ? StatusColors.overdue
                                  : (fee.due > 0
                                      ? StatusColors.partial
                                      : StatusColors.paid),
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => StudentFeesScreen(
                                    studentId: s.id,
                                    studentName: s.name,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],

                  const SizedBox(height: Gap.lg),
                  InfoCard(
                    title: 'CONTACT',
                    children: [
                      DetailRow(
                        label: 'Phone',
                        value: s.phone,
                        icon: Icons.phone_outlined,
                        onTap: () => _call(s.phone),
                      ),
                      const Divider(),
                      DetailRow(
                        label: 'Email',
                        value: s.email,
                        icon: Icons.mail_outline_rounded,
                      ),
                      const Divider(),
                      DetailRow(
                        label: 'Address',
                        value: s.address,
                        icon: Icons.location_on_outlined,
                      ),
                    ],
                  ),

                  const SizedBox(height: Gap.lg),
                  InfoCard(
                    title: 'PARENT / GUARDIAN',
                    children: [
                      DetailRow(
                        label: 'Name',
                        value: s.parentName,
                        icon: Icons.escalator_warning_outlined,
                      ),
                      const Divider(),
                      DetailRow(
                        label: 'Phone',
                        value: s.parentPhone,
                        icon: Icons.phone_outlined,
                        onTap: () => _call(s.parentPhone),
                      ),
                    ],
                  ),

                  const SizedBox(height: Gap.lg),
                  InfoCard(
                    title: 'ENROLMENT',
                    children: [
                      DetailRow(
                        label: 'Course',
                        value: s.course,
                        icon: Icons.menu_book_outlined,
                      ),
                      const Divider(),
                      DetailRow(
                        label: 'Batch',
                        value: s.batch == null
                            ? 'Not assigned'
                            : '${s.batch!.name} · ${s.batch!.timing ?? ''}',
                        icon: Icons.groups_outlined,
                      ),
                      const Divider(),
                      DetailRow(
                        label: 'Admission date',
                        value: Fmt.date(s.admissionDate),
                        icon: Icons.event_available_outlined,
                      ),
                      if (s.notes != null && s.notes!.isNotEmpty) ...[
                        const Divider(),
                        DetailRow(
                          label: 'Notes',
                          value: s.notes!,
                          icon: Icons.sticky_note_2_outlined,
                        ),
                      ],
                    ],
                  ),

                  const SizedBox(height: Gap.xl),
                  _ActionTile(
                    icon: Icons.fact_check_outlined,
                    label: 'Attendance history',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AttendanceReportScreen(
                          studentId: s.id,
                          studentName: s.name,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: Gap.md),
                  _ActionTile(
                    icon: Icons.payments_outlined,
                    label: 'Fees & payments',
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => StudentFeesScreen(
                            studentId: s.id,
                            studentName: s.name,
                          ),
                        ),
                      );
                      _ctrl.load();
                    },
                  ),
                  const SizedBox(height: Gap.md),
                  _ActionTile(
                    icon: Icons.emoji_events_outlined,
                    label: 'Exam results',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ResultsScreen(
                          studentId: s.id,
                          studentName: s.name,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(kRadius),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Gap.lg,
            vertical: Gap.lg,
          ),
          child: Row(
            children: [
              Icon(icon, size: 21, color: scheme.primary),
              const SizedBox(width: Gap.lg),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  size: 20, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
