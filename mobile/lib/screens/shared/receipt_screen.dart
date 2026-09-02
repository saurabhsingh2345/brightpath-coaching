import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/brand.dart';
import '../../core/formatters.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../state/async_value.dart';
import '../../widgets/common.dart';
import '../../widgets/states.dart';

/// A simple, printable-looking receipt. Copy-to-clipboard stands in for a
/// share/print integration.
class ReceiptScreen extends StatefulWidget {
  const ReceiptScreen({super.key, required this.paymentId});
  final String paymentId;

  @override
  State<ReceiptScreen> createState() => _ReceiptScreenState();
}

class _ReceiptScreenState extends State<ReceiptScreen> {
  late final AsyncController<Receipt> _ctrl;

  @override
  void initState() {
    super.initState();
    final api = context.read<ApiService>();
    _ctrl = AsyncController(() => api.receipt(widget.paymentId))..load();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  String _asText(Receipt r) => '''
${r.institute}
Receipt ${r.receiptNo}

Student   ${r.studentName} (${r.studentCode})
Course    ${r.course ?? '—'}
Batch     ${r.batchName ?? '—'}

Fee       ${r.feeTitle} (installment ${r.installment})
Amount    ${Fmt.money(r.amount)}
Mode      ${Fmt.titleCase(r.mode)}${r.reference != null ? ' (${r.reference})' : ''}
Paid on   ${Fmt.dateTime(r.paidAt)}

Installment total   ${Fmt.money(r.totalAmount)}
Paid so far         ${Fmt.money(r.paidAmount)}
Balance             ${Fmt.money(r.balance)}
Status              ${r.status}

Received by ${r.recordedBy ?? 'System'}
''';

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Receipt'),
        actions: [
          ListenableBuilder(
            listenable: _ctrl,
            builder: (context, _) {
              final r = _ctrl.data;
              if (r == null) return const SizedBox.shrink();
              return IconButton(
                tooltip: 'Copy receipt',
                icon: const Icon(Icons.copy_rounded),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: _asText(r)));
                  showSnack(context, 'Receipt copied to clipboard');
                },
              );
            },
          ),
          const SizedBox(width: Gap.sm),
        ],
      ),
      body: ListenableBuilder(
        listenable: _ctrl,
        builder: (context, _) {
          if (_ctrl.isFirstLoad) return const LoadingView();
          if (_ctrl.error != null && !_ctrl.hasData) {
            return ErrorView(error: _ctrl.error!, onRetry: _ctrl.load);
          }
          final r = _ctrl.data!;
          return ListView(
            padding: const EdgeInsets.all(Gap.lg),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(Gap.xl),
                  child: Column(
                    children: [
                      // ── header ──
                      Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          color: scheme.primary,
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child:
                            Icon(Brand.logo, color: Colors.white, size: 27),
                      ),
                      const SizedBox(height: Gap.md),
                      Text(
                        r.institute,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: Gap.xs),
                      Text(
                        'Payment receipt',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: Gap.lg),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: Gap.lg,
                          vertical: Gap.sm,
                        ),
                        decoration: BoxDecoration(
                          color: scheme.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          r.receiptNo,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: scheme.primary,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),

                      const Divider(height: Gap.xxl * 1.2),

                      // ── amount ──
                      Text(
                        Fmt.money(r.amount),
                        style: Theme.of(context)
                            .textTheme
                            .displaySmall
                            ?.copyWith(
                              fontWeight: FontWeight.w700,
                              letterSpacing: -1.5,
                              color: StatusColors.paid,
                            ),
                      ),
                      const SizedBox(height: Gap.xs),
                      Text(
                        'received via ${Fmt.titleCase(r.mode)}',
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: Gap.lg),
                      Text(
                        Fmt.dateTime(r.paidAt),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                      ),

                      const Divider(height: Gap.xxl * 1.2),

                      _Line('Student', '${r.studentName} · ${r.studentCode}'),
                      if (r.course != null) _Line('Course', r.course!),
                      if (r.batchName != null) _Line('Batch', r.batchName!),
                      _Line('Fee', r.feeTitle),
                      _Line('Installment', r.installment),
                      if (r.reference != null && r.reference!.isNotEmpty)
                        _Line('Reference', r.reference!),
                      _Line('Received by', r.recordedBy ?? 'System'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: Gap.lg),
              InfoCard(
                title: 'INSTALLMENT STATUS',
                children: [
                  DetailRow(
                    label: 'Installment total',
                    value: Fmt.money(r.totalAmount),
                  ),
                  const Divider(),
                  DetailRow(
                    label: 'Paid so far',
                    value: Fmt.money(r.paidAmount),
                  ),
                  const Divider(),
                  DetailRow(
                    label: 'Remaining balance',
                    value: Fmt.money(r.balance),
                    trailing: StatusPill(
                      label: r.status,
                      color: StatusColors.forFee(r.status),
                      dense: true,
                    ),
                  ),
                  const Divider(),
                  DetailRow(
                    label: 'Due date',
                    value: Fmt.date(r.dueDate),
                  ),
                ],
              ),
              const SizedBox(height: Gap.xl),
              Center(
                child: Text(
                  'This is a computer-generated receipt.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
              ),
              const SizedBox(height: Gap.xxl),
            ],
          );
        },
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line(this.label, this.value);
  final String label, value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 104,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
