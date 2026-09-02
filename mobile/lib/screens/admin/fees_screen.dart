import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/formatters.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../state/async_value.dart';
import '../../widgets/common.dart';
import '../../widgets/states.dart';
import 'student_fees_screen.dart';

enum FeeFilter { all, pending, partial, overdue, paid }

class FeesScreen extends StatefulWidget {
  const FeesScreen({super.key});

  @override
  State<FeesScreen> createState() => _FeesScreenState();
}

class _FeesScreenState extends State<FeesScreen> {
  late final ApiService _api;
  late final AsyncController<Paged<Fee>> _ctrl;

  String _search = '';
  FeeFilter _filter = FeeFilter.all;

  @override
  void initState() {
    super.initState();
    _api = context.read<ApiService>();
    _ctrl = AsyncController(_fetch)..load();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<Paged<Fee>> _fetch() => _api.fees(
        limit: 60,
        search: _search.isEmpty ? null : _search,
        status: switch (_filter) {
          FeeFilter.all => null,
          FeeFilter.pending => 'PENDING',
          FeeFilter.partial => 'PARTIAL',
          FeeFilter.overdue => 'OVERDUE',
          FeeFilter.paid => 'PAID',
        },
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Fees')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(Gap.lg, 0, Gap.lg, Gap.md),
            child: SearchBarField(
              hint: 'Search student or installment…',
              onChanged: (v) {
                _search = v;
                _ctrl.load();
              },
            ),
          ),
          FilterChips<FeeFilter>(
            options: FeeFilter.values,
            selected: _filter,
            labelOf: (f) => switch (f) {
              FeeFilter.all => 'All',
              FeeFilter.pending => 'Pending',
              FeeFilter.partial => 'Partial',
              FeeFilter.overdue => 'Overdue',
              FeeFilter.paid => 'Paid',
            },
            onSelected: (f) {
              setState(() => _filter = f);
              _ctrl.load();
            },
          ),
          Expanded(
            child: ListenableBuilder(
              listenable: _ctrl,
              builder: (context, _) {
                if (_ctrl.isFirstLoad) return const SkeletonList();
                if (_ctrl.error != null && !_ctrl.hasData) {
                  return ErrorView(error: _ctrl.error!, onRetry: _ctrl.load);
                }
                final fees = _ctrl.data?.items ?? const <Fee>[];
                if (fees.isEmpty) {
                  return EmptyView(
                    icon: Icons.receipt_long_outlined,
                    title: _filter == FeeFilter.all && _search.isEmpty
                        ? 'No fee records yet'
                        : 'Nothing matches this filter',
                    message: _filter == FeeFilter.all && _search.isEmpty
                        ? 'Open a student and create their fee plan to get started.'
                        : 'Try a different status or search term.',
                  );
                }
                return RefreshIndicator(
                  onRefresh: _ctrl.refresh,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(
                        Gap.lg, Gap.md, Gap.lg, Gap.xxl),
                    itemCount: fees.length,
                    separatorBuilder: (_, __) => const SizedBox(height: Gap.md),
                    itemBuilder: (context, i) => FeeCard(
                      fee: fees[i],
                      showStudent: true,
                      onTap: () async {
                        final s = fees[i].student;
                        if (s == null) return;
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

class FeeCard extends StatelessWidget {
  const FeeCard({
    super.key,
    required this.fee,
    this.onTap,
    this.showStudent = false,
    this.trailing,
  });

  final Fee fee;
  final VoidCallback? onTap;
  final bool showStudent;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = StatusColors.forFee(fee.status);
    final progress = fee.totalAmount == 0
        ? 0.0
        : (fee.paidAmount / fee.totalAmount * 100).toDouble();

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(kRadius),
        child: Padding(
          padding: const EdgeInsets.all(Gap.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (showStudent && fee.student != null) ...[
                          Text(
                            fee.student!.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                        ],
                        Text(
                          showStudent
                              ? '${fee.title} · Installment ${fee.installmentNo}/${fee.totalInstallments}'
                              : '${fee.title} (${fee.installmentNo}/${fee.totalInstallments})',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: showStudent
                              ? TextStyle(
                                  fontSize: 12,
                                  color: scheme.onSurfaceVariant,
                                )
                              : const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14.5,
                                ),
                        ),
                      ],
                    ),
                  ),
                  StatusPill(label: fee.status, color: color, dense: true),
                ],
              ),
              const SizedBox(height: Gap.md),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        style: Theme.of(context).textTheme.bodyMedium,
                        children: [
                          TextSpan(
                            text: Fmt.money(fee.paidAmount),
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                          TextSpan(
                            text: ' of ${Fmt.money(fee.totalAmount)}',
                            style: TextStyle(
                              color: scheme.onSurfaceVariant,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (!fee.isPaid)
                    Text(
                      '${Fmt.money(fee.balance)} due',
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: Gap.md),
              MeterBar(value: progress, height: 6, color: color),
              const SizedBox(height: Gap.md),
              Row(
                children: [
                  Icon(Icons.event_outlined,
                      size: 13, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Text(
                    'Due ${Fmt.date(fee.dueDate)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: fee.status == 'OVERDUE'
                          ? StatusColors.overdue
                          : scheme.onSurfaceVariant,
                      fontWeight: fee.status == 'OVERDUE'
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
                  ),
                  const Spacer(),
                  if (trailing != null)
                    trailing!
                  else if (fee.payments.isNotEmpty)
                    Text(
                      '${fee.payments.length} payment${fee.payments.length == 1 ? '' : 's'}',
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
