import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/api_exception.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../state/async_value.dart';
import '../../widgets/common.dart';
import '../../widgets/states.dart';

/// Removes the seeded walkthrough data once the institute is ready to work
/// with real records. Only rows created by the seed can be removed, so
/// anything the institute has entered is never at risk.
class ClearDemoScreen extends StatefulWidget {
  const ClearDemoScreen({super.key});

  @override
  State<ClearDemoScreen> createState() => _ClearDemoScreenState();
}

class _ClearDemoScreenState extends State<ClearDemoScreen> {
  static const _phrase = 'CLEAR DEMO DATA';

  late final ApiService _api;
  late final AsyncController<DemoSummary> _ctrl;
  final _confirm = TextEditingController();
  bool _working = false;

  @override
  void initState() {
    super.initState();
    _api = context.read<ApiService>();
    _ctrl = AsyncController(_api.demoSummary)..load();
  }

  @override
  void dispose() {
    _confirm.dispose();
    _ctrl.dispose();
    super.dispose();
  }

  bool get _phraseOk => _confirm.text.trim().toUpperCase() == _phrase;

  Future<void> _clear() async {
    if (!_phraseOk || _working) return;
    setState(() => _working = true);
    try {
      final message = await _api.clearDemoData();
      if (!mounted) return;
      showSnack(context, message);
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, isError: true);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Start fresh')),
      body: ListenableBuilder(
        listenable: _ctrl,
        builder: (context, _) {
          if (_ctrl.isFirstLoad) return const LoadingView();
          if (_ctrl.error != null && !_ctrl.hasData) {
            return ErrorView(error: _ctrl.error!, onRetry: _ctrl.load);
          }
          final d = _ctrl.data!;

          if (!d.hasDemoData) {
            return const EmptyView(
              icon: Icons.check_circle_outline_rounded,
              title: 'Already clean',
              message:
                  'The sample walkthrough data has been removed. Everything here now belongs to your institute.',
            );
          }

          final rows = <(String, int)>[
            ('Sample students', d.students),
            ('Sample batches', d.batches),
            ('Attendance records', d.attendanceRecords),
            ('Fee installments', d.feeInstallments),
            ('Exams and results', d.exams),
            ('Study material entries', d.materials),
            ('Announcements', d.announcements),
            ('Chat messages', d.chatMessages),
          ];

          return ListView(
            padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.lg, Gap.lg, Gap.xxl),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(Gap.xl),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: scheme.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(13),
                            ),
                            child: Icon(Icons.auto_awesome_rounded,
                                size: 21, color: scheme.primary),
                          ),
                          const SizedBox(width: Gap.lg),
                          Expanded(
                            child: Text(
                              'Ready for your real records',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: Gap.lg),
                      Text(
                        'The app ships with a sample institute so you can see '
                        'every feature working. When you are done exploring, '
                        'remove it and start entering your own batches and '
                        'students.',
                        style: TextStyle(
                          fontSize: 13.5,
                          height: 1.55,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SectionHeader(
                title: 'What will be removed',
                padding: EdgeInsets.only(top: Gap.xl, bottom: Gap.md),
              ),
              Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Gap.lg,
                    vertical: Gap.sm,
                  ),
                  child: Column(
                    children: [
                      for (final (label, count) in rows) ...[
                        if (label != rows.first.$1) const Divider(),
                        Padding(
                          padding:
                              const EdgeInsets.symmetric(vertical: Gap.md),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  label,
                                  style: const TextStyle(fontSize: 13.5),
                                ),
                              ),
                              Text(
                                '$count',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: count > 0
                                      ? scheme.onSurface
                                      : scheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const SectionHeader(
                title: 'What stays',
                padding: EdgeInsets.only(top: Gap.xl, bottom: Gap.md),
              ),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(Gap.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.verified_user_rounded,
                              size: 19, color: StatusColors.present),
                          const SizedBox(width: Gap.md),
                          Expanded(
                            child: Text(
                              'Everything you created yourself',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: Gap.md),
                      Text(
                        d.keeps.hasAny
                            ? 'You currently have '
                                '${d.keeps.students} student(s), '
                                '${d.keeps.batches} batch(es), '
                                '${d.keeps.announcements} announcement(s) and '
                                '${d.keeps.materials} document(s) of your own. '
                                'None of it is affected.'
                            : 'You have not added anything of your own yet. '
                                'Once you do, this button can never touch it.',
                        style: TextStyle(
                          fontSize: 12.5,
                          height: 1.55,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const Divider(height: Gap.xl),
                      Text(
                        'This removes only the rows that shipped with the app. '
                        'Your admin login, your students, their attendance, '
                        'fees, receipts, exams and messages are stored '
                        'separately and are not part of this action.',
                        style: TextStyle(
                          fontSize: 12.5,
                          height: 1.55,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: Gap.xl),
              Text(
                'Type $_phrase to confirm',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: Gap.sm),
              TextField(
                controller: _confirm,
                textCapitalization: TextCapitalization.characters,
                autocorrect: false,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: _phrase,
                  suffixIcon: _phraseOk
                      ? const Icon(Icons.check_circle_rounded,
                          color: StatusColors.present, size: 20)
                      : null,
                ),
              ),
              const SizedBox(height: Gap.lg),
              FilledButton.icon(
                onPressed: _phraseOk && !_working ? _clear : null,
                icon: _working
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.cleaning_services_rounded, size: 19),
                label: Text(_working ? 'Removing…' : 'Remove demo data'),
                style: FilledButton.styleFrom(
                  backgroundColor: scheme.error,
                  foregroundColor: scheme.onError,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
