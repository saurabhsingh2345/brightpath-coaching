import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/api_exception.dart';
import '../../core/formatters.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../state/async_value.dart';
import '../../widgets/common.dart';
import '../../widgets/states.dart';
import 'fees_screen.dart';
import '../shared/receipt_screen.dart';

/// One student's whole fee ledger. Admins can add a plan and record payments;
/// students see the same screen read-only via [readOnly].
class StudentFeesScreen extends StatefulWidget {
  const StudentFeesScreen({
    super.key,
    required this.studentId,
    required this.studentName,
    this.readOnly = false,
  });

  final String studentId;
  final String studentName;
  final bool readOnly;

  @override
  State<StudentFeesScreen> createState() => _StudentFeesScreenState();
}

class _StudentFeesScreenState extends State<StudentFeesScreen> {
  late final ApiService _api;
  late final AsyncController<StudentFeeLedger> _ctrl;

  @override
  void initState() {
    super.initState();
    _api = context.read<ApiService>();
    _ctrl = AsyncController(
      () => widget.readOnly
          ? _api.myFees()
          : _api.studentFees(widget.studentId),
    )..load();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _createPlan() async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _FeePlanSheet(studentId: widget.studentId),
    );
    if (created == true) _ctrl.load();
  }

  Future<void> _recordPayment(Fee fee) async {
    final done = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _PaymentSheet(fee: fee),
    );
    if (done == true) _ctrl.load();
  }

  Future<void> _deleteFee(Fee fee) async {
    final ok = await confirm(
      context,
      title: 'Delete installment?',
      message: 'Remove "${fee.title}" from this student\'s fee plan.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok) return;
    try {
      await _api.deleteFee(fee.id);
      if (mounted) showSnack(context, 'Installment deleted');
      _ctrl.load();
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.readOnly ? 'My fees' : 'Fees'),
        bottom: widget.readOnly
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(20),
                child: Padding(
                  padding: const EdgeInsets.only(left: Gap.lg, bottom: Gap.sm),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      widget.studentName,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                  ),
                ),
              ),
      ),
      body: ListenableBuilder(
        listenable: _ctrl,
        builder: (context, _) {
          if (_ctrl.isFirstLoad) return const SkeletonList();
          if (_ctrl.error != null && !_ctrl.hasData) {
            return ErrorView(error: _ctrl.error!, onRetry: _ctrl.load);
          }
          final ledger = _ctrl.data!;
          final s = ledger.summary;

          return RefreshIndicator(
            onRefresh: _ctrl.refresh,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                  Gap.lg, Gap.lg, Gap.lg, Gap.xxl * 2),
              children: [
                // ── summary ──
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(Gap.xl),
                    child: Column(
                      children: [
                        Text(
                          Fmt.money(s.due),
                          style: Theme.of(context)
                              .textTheme
                              .headlineMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w700,
                                letterSpacing: -1,
                                color: s.due > 0
                                    ? (s.overdue > 0
                                        ? StatusColors.overdue
                                        : scheme.onSurface)
                                    : StatusColors.paid,
                              ),
                        ),
                        Text(
                          s.due > 0 ? 'total outstanding' : 'all fees cleared',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                        ),
                        if (s.overdue > 0) ...[
                          const SizedBox(height: Gap.md),
                          StatusPill(
                            label: '${Fmt.money(s.overdue)} OVERDUE',
                            color: StatusColors.overdue,
                            icon: Icons.warning_amber_rounded,
                          ),
                        ],
                        const SizedBox(height: Gap.xl),
                        MeterBar(
                          value: s.totalFee == 0
                              ? 0
                              : (s.paid / s.totalFee * 100).toDouble(),
                          color: StatusColors.paid,
                        ),
                        const SizedBox(height: Gap.lg),
                        Row(
                          children: [
                            _Sum('Total', Fmt.money(s.totalFee),
                                scheme.onSurface),
                            _Sum('Paid', Fmt.money(s.paid), StatusColors.paid),
                            _Sum(
                              'Installments',
                              '${s.paidInstallments}/${s.installments}',
                              scheme.primary,
                            ),
                          ],
                        ),
                        if (s.nextDueDate != null && s.nextDueAmount > 0) ...[
                          const Divider(height: Gap.xl * 1.5),
                          Row(
                            children: [
                              Icon(Icons.event_outlined,
                                  size: 17, color: scheme.onSurfaceVariant),
                              const SizedBox(width: Gap.sm),
                              Expanded(
                                child: Text(
                                  'Next: ${s.nextDueTitle ?? 'installment'} · ${Fmt.date(s.nextDueDate)}',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              Text(
                                Fmt.money(s.nextDueAmount),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                const SectionHeader(
                  title: 'Installments',
                  padding: EdgeInsets.only(top: Gap.xl, bottom: Gap.md),
                ),

                if (ledger.fees.isEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(Gap.xl),
                      child: Column(
                        children: [
                          Icon(Icons.receipt_long_outlined,
                              size: 34, color: scheme.onSurfaceVariant),
                          const SizedBox(height: Gap.md),
                          Text(
                            'No fee plan yet',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          const SizedBox(height: Gap.xs),
                          Text(
                            widget.readOnly
                                ? 'The institute has not set up your fees yet.'
                                : 'Create a plan to start tracking payments.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                          if (!widget.readOnly) ...[
                            const SizedBox(height: Gap.lg),
                            FilledButton.tonal(
                              onPressed: _createPlan,
                              child: const Text('Create fee plan'),
                            ),
                          ],
                        ],
                      ),
                    ),
                  )
                else
                  ...ledger.fees.map(
                    (fee) => Padding(
                      padding: const EdgeInsets.only(bottom: Gap.md),
                      child: FeeCard(
                        fee: fee,
                        onTap: () => _openFee(fee),
                        trailing: widget.readOnly || fee.isPaid
                            ? null
                            : TextButton(
                                onPressed: () => _recordPayment(fee),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: Gap.sm,
                                  ),
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: const Text('Collect'),
                              ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: widget.readOnly
          ? null
          : FloatingActionButton.extended(
              onPressed: _createPlan,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add plan'),
            ),
    );
  }

  void _openFee(Fee fee) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _FeeDetailSheet(
        fee: fee,
        readOnly: widget.readOnly,
        onCollect: fee.isPaid
            ? null
            : () {
                Navigator.pop(context);
                _recordPayment(fee);
              },
        onDelete: widget.readOnly || fee.payments.isNotEmpty
            ? null
            : () {
                Navigator.pop(context);
                _deleteFee(fee);
              },
      ),
    );
  }
}

class _Sum extends StatelessWidget {
  const _Sum(this.label, this.value, this.color);
  final String label, value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: color,
              fontSize: 14,
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

// ── payment history sheet ────────────────────────────────────
class _FeeDetailSheet extends StatelessWidget {
  const _FeeDetailSheet({
    required this.fee,
    required this.readOnly,
    this.onCollect,
    this.onDelete,
  });

  final Fee fee;
  final bool readOnly;
  final VoidCallback? onCollect;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.62,
      maxChildSize: 0.9,
      builder: (context, scroll) => ListView(
        controller: scroll,
        padding: const EdgeInsets.fromLTRB(Gap.xl, 0, Gap.xl, Gap.xl),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  fee.title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              StatusPill(
                label: fee.status,
                color: StatusColors.forFee(fee.status),
              ),
            ],
          ),
          const SizedBox(height: Gap.xs),
          Text(
            'Installment ${fee.installmentNo} of ${fee.totalInstallments} · due ${Fmt.date(fee.dueDate)}',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: Gap.xl),
          Row(
            children: [
              _Sum('Total', Fmt.money(fee.totalAmount), scheme.onSurface),
              _Sum('Paid', Fmt.money(fee.paidAmount), StatusColors.paid),
              _Sum(
                'Balance',
                Fmt.money(fee.balance),
                fee.balance > 0 ? StatusColors.overdue : StatusColors.paid,
              ),
            ],
          ),
          const Divider(height: Gap.xxl),
          Text(
            'PAYMENT HISTORY',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
          ),
          const SizedBox(height: Gap.md),
          if (fee.payments.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: Gap.xl),
              child: Center(
                child: Text(
                  'No payments recorded yet.',
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              ),
            )
          else
            ...fee.payments.map(
              (p) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: StatusColors.paid.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: const Icon(Icons.receipt_rounded,
                      size: 19, color: StatusColors.paid),
                ),
                title: Text(
                  Fmt.money(p.amount),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  '${Fmt.titleCase(p.mode)} · ${Fmt.date(p.paidAt)}\n${p.receiptNo}',
                  style: const TextStyle(fontSize: 11.5, height: 1.4),
                ),
                isThreeLine: true,
                trailing: IconButton(
                  tooltip: 'View receipt',
                  icon: const Icon(Icons.open_in_new_rounded, size: 18),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ReceiptScreen(paymentId: p.id),
                    ),
                  ),
                ),
              ),
            ),
          if (!readOnly) ...[
            const SizedBox(height: Gap.xl),
            if (onCollect != null)
              FilledButton.icon(
                onPressed: onCollect,
                icon: const Icon(Icons.payments_rounded, size: 19),
                label: const Text('Record payment'),
              ),
            if (onDelete != null) ...[
              const SizedBox(height: Gap.md),
              OutlinedButton.icon(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline_rounded, size: 19),
                label: const Text('Delete installment'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: scheme.error,
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

// ── record payment sheet ─────────────────────────────────────
class _PaymentSheet extends StatefulWidget {
  const _PaymentSheet({required this.fee});
  final Fee fee;

  @override
  State<_PaymentSheet> createState() => _PaymentSheetState();
}

class _PaymentSheetState extends State<_PaymentSheet> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _amount =
      TextEditingController(text: widget.fee.balance.toString());
  final _reference = TextEditingController();
  String _mode = 'CASH';
  bool _saving = false;

  static const _modes = [
    ('CASH', 'Cash', Icons.payments_outlined),
    ('UPI', 'UPI', Icons.qr_code_rounded),
    ('CARD', 'Card', Icons.credit_card_rounded),
    ('BANK_TRANSFER', 'Bank', Icons.account_balance_outlined),
    ('CHEQUE', 'Cheque', Icons.receipt_long_outlined),
  ];

  @override
  void dispose() {
    _amount.dispose();
    _reference.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      final res = await context.read<ApiService>().recordPayment(
            widget.fee.id,
            amount: num.parse(_amount.text),
            mode: _mode,
            reference: _reference.text.trim(),
          );
      if (!mounted) return;
      final paymentId =
          (res['payment'] as Map?)?['id']?.toString();
      showSnack(context, res['message'] as String? ?? 'Payment recorded');
      Navigator.pop(context, true);
      if (paymentId != null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ReceiptScreen(paymentId: paymentId),
          ),
        );
      }
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(
        left: Gap.xl,
        right: Gap.xl,
        bottom: MediaQuery.of(context).viewInsets.bottom + Gap.xl,
      ),
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Record payment',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: Gap.xs),
            Text(
              '${widget.fee.title} · balance ${Fmt.money(widget.fee.balance)}',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: Gap.xl),
            TextFormField(
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Amount',
                prefixText: '₹ ',
              ),
              validator: (v) {
                final value = num.tryParse(v?.trim() ?? '');
                if (value == null) return 'Enter an amount';
                if (value <= 0) return 'Amount must be greater than zero';
                if (value > widget.fee.balance) {
                  return 'Cannot exceed the ${Fmt.money(widget.fee.balance)} balance';
                }
                return null;
              },
            ),
            const SizedBox(height: Gap.lg),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Mode',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ),
            const SizedBox(height: Gap.sm),
            Wrap(
              spacing: Gap.sm,
              runSpacing: Gap.sm,
              children: _modes
                  .map((m) => ChoiceChip(
                        avatar: Icon(m.$3, size: 15),
                        label: Text(m.$2),
                        selected: _mode == m.$1,
                        showCheckmark: false,
                        onSelected: (_) => setState(() => _mode = m.$1),
                      ))
                  .toList(),
            ),
            const SizedBox(height: Gap.lg),
            TextFormField(
              controller: _reference,
              decoration: const InputDecoration(
                labelText: 'Reference (optional)',
                hintText: 'UPI ref / cheque no / txn id',
              ),
            ),
            const SizedBox(height: Gap.xl),
            FilledButton(
              onPressed: _saving ? null : _submit,
              child: _saving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Record payment'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── fee plan sheet ───────────────────────────────────────────
class _FeePlanSheet extends StatefulWidget {
  const _FeePlanSheet({required this.studentId});
  final String studentId;

  @override
  State<_FeePlanSheet> createState() => _FeePlanSheetState();
}

class _InstallmentDraft {
  _InstallmentDraft(this.title, this.dueDate);
  final TextEditingController title;
  DateTime dueDate;
  final TextEditingController amount = TextEditingController();
}

class _FeePlanSheetState extends State<_FeePlanSheet> {
  final _form = GlobalKey<FormState>();
  final _total = TextEditingController();
  final List<_InstallmentDraft> _drafts = [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _addDraft();
  }

  @override
  void dispose() {
    _total.dispose();
    for (final d in _drafts) {
      d.title.dispose();
      d.amount.dispose();
    }
    super.dispose();
  }

  void _addDraft() {
    setState(() {
      _drafts.add(_InstallmentDraft(
        TextEditingController(text: 'Term ${_drafts.length + 1}'),
        DateTime.now().add(Duration(days: 30 * (_drafts.length + 1))),
      ));
    });
  }

  /// Split the total evenly across the current installments.
  void _split() {
    final total = num.tryParse(_total.text.trim());
    if (total == null || total <= 0 || _drafts.isEmpty) return;
    final per = (total / _drafts.length);
    setState(() {
      for (final d in _drafts) {
        d.amount.text = per == per.roundToDouble()
            ? per.toStringAsFixed(0)
            : per.toStringAsFixed(2);
      }
    });
  }

  Future<void> _pickDue(_InstallmentDraft d) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: d.dueDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 1095)),
    );
    if (picked != null) setState(() => d.dueDate = picked);
  }

  Future<void> _submit() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      final msg = await context.read<ApiService>().createFeePlan(
            studentId: widget.studentId,
            installments: _drafts
                .map((d) => {
                      'title': d.title.text.trim(),
                      'amount': num.parse(d.amount.text.trim()),
                      'dueDate': Fmt.iso(d.dueDate),
                    })
                .toList(),
          );
      if (!mounted) return;
      showSnack(context, msg);
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      builder: (context, scroll) => Form(
        key: _form,
        child: ListView(
          controller: scroll,
          padding: EdgeInsets.fromLTRB(
            Gap.xl,
            0,
            Gap.xl,
            MediaQuery.of(context).viewInsets.bottom + Gap.xl,
          ),
          children: [
            Text('Fee plan', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: Gap.xs),
            Text(
              'Split the course fee into installments with their own due dates.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant, height: 1.4),
            ),
            const SizedBox(height: Gap.xl),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _total,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Total fee (optional helper)',
                      prefixText: '₹ ',
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: Gap.md),
                OutlinedButton(
                  onPressed: _split,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(80, 48),
                  ),
                  child: const Text('Split'),
                ),
              ],
            ),
            const Divider(height: Gap.xxl),
            ...List.generate(_drafts.length, (i) {
              final d = _drafts[i];
              return Padding(
                padding: const EdgeInsets.only(bottom: Gap.lg),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(Gap.md),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: TextFormField(
                                controller: d.title,
                                decoration: const InputDecoration(
                                  labelText: 'Title',
                                  isDense: true,
                                ),
                                validator: (v) =>
                                    (v == null || v.trim().isEmpty)
                                        ? 'Required'
                                        : null,
                              ),
                            ),
                            const SizedBox(width: Gap.sm),
                            Expanded(
                              flex: 2,
                              child: TextFormField(
                                controller: d.amount,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Amount',
                                  prefixText: '₹',
                                  isDense: true,
                                ),
                                validator: (v) {
                                  final value = num.tryParse(v?.trim() ?? '');
                                  if (value == null) return 'Number';
                                  if (value <= 0) return '> 0';
                                  return null;
                                },
                              ),
                            ),
                            if (_drafts.length > 1)
                              IconButton(
                                icon: const Icon(Icons.close_rounded, size: 19),
                                onPressed: () => setState(() {
                                  _drafts.removeAt(i);
                                }),
                              ),
                          ],
                        ),
                        const SizedBox(height: Gap.sm),
                        InkWell(
                          onTap: () => _pickDue(d),
                          borderRadius: BorderRadius.circular(kRadiusSm),
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Due date',
                              isDense: true,
                              suffixIcon:
                                  Icon(Icons.calendar_today_rounded, size: 17),
                            ),
                            child: Text(Fmt.date(d.dueDate)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
            OutlinedButton.icon(
              onPressed: _addDraft,
              icon: const Icon(Icons.add_rounded, size: 19),
              label: const Text('Add installment'),
            ),
            const SizedBox(height: Gap.xl),
            FilledButton(
              onPressed: _saving ? null : _submit,
              child: _saving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: Colors.white,
                      ),
                    )
                  : Text('Create ${_drafts.length} installment(s)'),
            ),
          ],
        ),
      ),
    );
  }
}
