import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/api_exception.dart';
import '../../core/formatters.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../widgets/common.dart';
import '../../widgets/states.dart';
import 'attendance_history_screen.dart';

/// Pick a batch + date, then tap through the roster. Saving upserts, so a
/// day can be corrected as many times as needed.
class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  late final ApiService _api;

  List<Batch> _batches = const [];
  Batch? _batch;
  DateTime _date = DateTime.now();

  AttendanceSheet? _sheet;
  ApiException? _error;
  bool _loading = true;
  bool _saving = false;

  /// studentId -> status, edited locally until saved.
  final Map<String, String> _marks = {};

  @override
  void initState() {
    super.initState();
    _api = context.read<ApiService>();
    _loadBatches();
  }

  Future<void> _loadBatches() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _api.batches(isActive: true);
      if (!mounted) return;
      setState(() {
        _batches = list;
        _batch = list.isEmpty ? null : list.first;
      });
      if (_batch != null) {
        await _loadSheet();
      } else {
        setState(() => _loading = false);
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _error = e;
          _loading = false;
        });
      }
    }
  }

  Future<void> _loadSheet() async {
    if (_batch == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final sheet = await _api.attendanceSheet(_batch!.id, Fmt.iso(_date));
      if (!mounted) return;
      setState(() {
        _sheet = sheet;
        _marks
          ..clear()
          ..addEntries(sheet.entries
              .where((e) => e.status != null)
              .map((e) => MapEntry(e.studentId, e.status!)));
        _loading = false;
      });
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _error = e;
          _sheet = null;
          _loading = false;
        });
      }
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
      helpText: 'Attendance date',
    );
    if (picked != null) {
      setState(() => _date = picked);
      _loadSheet();
    }
  }

  void _markAll(String status) {
    if (_sheet == null) return;
    setState(() {
      for (final e in _sheet!.entries) {
        _marks[e.studentId] = status;
      }
    });
  }

  Future<void> _save() async {
    if (_batch == null || _sheet == null) return;
    if (_marks.isEmpty) {
      showSnack(context, 'Mark at least one student first', isError: true);
      return;
    }
    setState(() => _saving = true);
    try {
      final res = await _api.markAttendance(
        batchId: _batch!.id,
        date: Fmt.iso(_date),
        entries: _marks.entries
            .map((e) => {'studentId': e.key, 'status': e.value})
            .toList(),
      );
      if (!mounted) return;
      showSnack(context, res['message'] as String? ?? 'Attendance saved');
      await _loadSheet();
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  int _countOf(String status) =>
      _marks.values.where((v) => v == status).length;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final total = _sheet?.entries.length ?? 0;
    final marked = _marks.length;
    final isToday = Fmt.iso(_date) == Fmt.iso(DateTime.now());

    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance'),
        actions: [
          IconButton(
            tooltip: 'History',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AttendanceHistoryScreen(batches: _batches),
              ),
            ),
            icon: const Icon(Icons.history_rounded),
          ),
          const SizedBox(width: Gap.sm),
        ],
      ),
      body: Column(
        children: [
          // ── selectors ──
          Padding(
            padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.sm, Gap.lg, Gap.md),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: DropdownButtonFormField<String>(
                    initialValue: _batch?.id,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Batch',
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: Gap.md,
                        vertical: Gap.md,
                      ),
                    ),
                    items: _batches
                        .map((b) => DropdownMenuItem(
                              value: b.id,
                              child: Text(b.name,
                                  overflow: TextOverflow.ellipsis),
                            ))
                        .toList(),
                    onChanged: (v) {
                      final next = _batches.firstWhere((b) => b.id == v);
                      setState(() => _batch = next);
                      _loadSheet();
                    },
                  ),
                ),
                const SizedBox(width: Gap.md),
                Expanded(
                  flex: 2,
                  child: InkWell(
                    onTap: _pickDate,
                    borderRadius: BorderRadius.circular(kRadiusSm),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Date',
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: Gap.md,
                          vertical: Gap.md,
                        ),
                      ),
                      child: Text(
                        isToday ? 'Today' : Fmt.dateShort(_date),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          if (_sheet != null && total > 0) ...[
            // ── summary strip ──
            Container(
              margin: const EdgeInsets.symmetric(horizontal: Gap.lg),
              padding: const EdgeInsets.symmetric(
                horizontal: Gap.lg,
                vertical: Gap.md,
              ),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(kRadiusSm),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '$marked of $total marked',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  _Tally('P', _countOf('PRESENT'), StatusColors.present),
                  _Tally('A', _countOf('ABSENT'), StatusColors.absent),
                  _Tally('L', _countOf('LATE'), StatusColors.late),
                  _Tally('Lv', _countOf('LEAVE'), StatusColors.leave),
                ],
              ),
            ),
            const SizedBox(height: Gap.sm),
            // ── bulk actions ──
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: Gap.lg),
                children: [
                  ActionChip(
                    avatar: const Icon(Icons.done_all_rounded, size: 15),
                    label: const Text('All present'),
                    onPressed: () => _markAll('PRESENT'),
                  ),
                  const SizedBox(width: Gap.sm),
                  ActionChip(
                    avatar: const Icon(Icons.close_rounded, size: 15),
                    label: const Text('All absent'),
                    onPressed: () => _markAll('ABSENT'),
                  ),
                  const SizedBox(width: Gap.sm),
                  ActionChip(
                    avatar: const Icon(Icons.clear_all_rounded, size: 15),
                    label: const Text('Clear'),
                    onPressed: () => setState(_marks.clear),
                  ),
                ],
              ),
            ),
          ],

          Expanded(child: _body()),
        ],
      ),
      floatingActionButton: (_sheet != null && total > 0)
          ? FloatingActionButton.extended(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.check_rounded),
              label: Text(_sheet!.alreadyMarked ? 'Update' : 'Save'),
            )
          : null,
    );
  }

  Widget _body() {
    if (_loading) return const SkeletonList(height: 68);
    if (_error != null) {
      return ErrorView(
        error: _error!,
        onRetry: _batches.isEmpty ? _loadBatches : _loadSheet,
      );
    }
    if (_batches.isEmpty) {
      return const EmptyView(
        icon: Icons.groups_outlined,
        title: 'No active batches',
        message: 'Create a batch and add students before marking attendance.',
      );
    }
    final sheet = _sheet;
    if (sheet == null || sheet.entries.isEmpty) {
      return EmptyView(
        icon: Icons.person_off_outlined,
        title: 'No students in this batch',
        message:
            'Assign students to ${_batch?.name ?? 'this batch'} to mark their attendance.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.md, Gap.lg, Gap.xxl * 2.5),
      itemCount: sheet.entries.length,
      separatorBuilder: (_, __) => const SizedBox(height: Gap.sm),
      itemBuilder: (context, i) {
        final e = sheet.entries[i];
        final status = _marks[e.studentId];
        return _AttendanceRow(
          entry: e,
          status: status,
          onChanged: (v) => setState(() {
            if (v == null) {
              _marks.remove(e.studentId);
            } else {
              _marks[e.studentId] = v;
            }
          }),
        );
      },
    );
  }
}

class _Tally extends StatelessWidget {
  const _Tally(this.label, this.count, this.color);
  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: Gap.sm),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: Gap.sm, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: count > 0 ? 0.14 : 0.05),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          '$label $count',
          style: TextStyle(
            color: count > 0 ? color : color.withValues(alpha: 0.5),
            fontWeight: FontWeight.w700,
            fontSize: 11.5,
          ),
        ),
      ),
    );
  }
}

class _AttendanceRow extends StatelessWidget {
  const _AttendanceRow({
    required this.entry,
    required this.status,
    required this.onChanged,
  });

  final AttendanceSheetEntry entry;
  final String? status;
  final ValueChanged<String?> onChanged;

  static const _options = [
    ('PRESENT', 'P', StatusColors.present),
    ('ABSENT', 'A', StatusColors.absent),
    ('LATE', 'L', StatusColors.late),
    ('LEAVE', 'Lv', StatusColors.leave),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Gap.md,
          vertical: Gap.sm,
        ),
        child: Row(
          children: [
            InitialsAvatar(name: entry.name, size: 36),
            const SizedBox(width: Gap.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    entry.studentCode,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            ..._options.map((o) {
              final selected = status == o.$1;
              return Padding(
                padding: const EdgeInsets.only(left: 5),
                child: GestureDetector(
                  onTap: () => onChanged(selected ? null : o.$1),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: selected
                          ? o.$3
                          : o.$3.withValues(alpha: 0.09),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: selected
                            ? o.$3
                            : o.$3.withValues(alpha: 0.22),
                        width: 1.2,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      o.$2,
                      style: TextStyle(
                        color: selected ? Colors.white : o.$3,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
