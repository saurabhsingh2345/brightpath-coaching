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

const kWeekdays = [
  'MONDAY',
  'TUESDAY',
  'WEDNESDAY',
  'THURSDAY',
  'FRIDAY',
  'SATURDAY',
  'SUNDAY',
];

/// Weekly grid. Admins pick a batch and can add/remove slots; students see
/// their own batch read-only.
class TimetableScreen extends StatefulWidget {
  const TimetableScreen({
    super.key,
    this.mine = false,
    this.showAppBar = true,
  });

  final bool mine;
  final bool showAppBar;

  @override
  State<TimetableScreen> createState() => _TimetableScreenState();
}

class _TimetableScreenState extends State<TimetableScreen> {
  late final ApiService _api;
  late final AsyncController<WeeklyTimetable> _ctrl;

  List<Batch> _batches = const [];
  Batch? _batch;
  late String _day;

  @override
  void initState() {
    super.initState();
    _api = context.read<ApiService>();
    // Default to today, so the screen opens on what matters now.
    _day = kWeekdays[(DateTime.now().weekday - 1).clamp(0, 6)];
    _ctrl = AsyncController(_fetch);
    if (widget.mine) {
      _ctrl.load();
    } else {
      _loadBatches();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<WeeklyTimetable> _fetch() async {
    if (widget.mine) return _api.myTimetable();
    if (_batch == null) return WeeklyTimetable(batch: null, days: const {});
    return _api.weeklyTimetable(_batch!.id);
  }

  Future<void> _loadBatches() async {
    try {
      final list = await _api.batches(isActive: true);
      if (!mounted) return;
      setState(() {
        _batches = list;
        _batch = list.isEmpty ? null : list.first;
      });
      if (_batch != null) _ctrl.load();
    } catch (_) {
      if (mounted) _ctrl.load();
    }
  }

  Future<void> _addSlot() async {
    if (_batch == null) return;
    final added = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _SlotSheet(batch: _batch!, weekday: _day),
    );
    if (added == true) _ctrl.load();
  }

  Future<void> _deleteSlot(TimetableSlot slot) async {
    final ok = await confirm(
      context,
      title: 'Remove class?',
      message:
          '${slot.subject} on ${Fmt.titleCase(slot.weekday)} at ${Fmt.time(slot.startTime)} will be removed from the timetable.',
      confirmLabel: 'Remove',
      destructive: true,
    );
    if (!ok) return;
    try {
      await _api.deleteSlot(slot.id);
      if (mounted) showSnack(context, 'Class removed');
      _ctrl.load();
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final body = Column(
      children: [
        if (!widget.mine && _batches.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.sm, Gap.lg, Gap.md),
            child: DropdownButtonFormField<String>(
              initialValue: _batch?.id,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Batch',
                isDense: true,
              ),
              items: _batches
                  .map((b) => DropdownMenuItem(
                        value: b.id,
                        child: Text(b.name, overflow: TextOverflow.ellipsis),
                      ))
                  .toList(),
              onChanged: (v) {
                setState(() => _batch = _batches.firstWhere((b) => b.id == v));
                _ctrl.load();
              },
            ),
          ),
        // ── weekday selector ──
        Padding(
          padding: const EdgeInsets.only(bottom: Gap.sm),
          child: FilterChips<String>(
            options: kWeekdays,
            selected: _day,
            labelOf: (d) => d.substring(0, 3),
            onSelected: (d) => setState(() => _day = d),
          ),
        ),
        Expanded(
          child: ListenableBuilder(
            listenable: _ctrl,
            builder: (context, _) {
              if (_ctrl.isFirstLoad) return const SkeletonList(height: 84);
              if (_ctrl.error != null && !_ctrl.hasData) {
                return ErrorView(error: _ctrl.error!, onRetry: _ctrl.load);
              }
              final table = _ctrl.data;

              if (!widget.mine && _batches.isEmpty) {
                return const EmptyView(
                  icon: Icons.groups_outlined,
                  title: 'No batches yet',
                  message: 'Create a batch before building its timetable.',
                );
              }
              if (widget.mine && table?.batch == null) {
                return const EmptyView(
                  icon: Icons.groups_outlined,
                  title: 'No batch assigned',
                  message:
                      'Once the institute assigns you to a batch, your weekly timetable appears here.',
                );
              }

              final slots = table?.days[_day] ?? const <TimetableSlot>[];
              if (slots.isEmpty) {
                return EmptyView(
                  icon: Icons.event_available_outlined,
                  title: 'No classes on ${Fmt.titleCase(_day)}',
                  message: widget.mine
                      ? 'Enjoy the break.'
                      : 'Add a class to build out this day.',
                  actionLabel: widget.mine ? null : 'Add class',
                  onAction: widget.mine ? null : _addSlot,
                );
              }

              return RefreshIndicator(
                onRefresh: _ctrl.refresh,
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                      Gap.lg, Gap.sm, Gap.lg, Gap.xxl * 2),
                  itemCount: slots.length,
                  separatorBuilder: (_, __) => const SizedBox(height: Gap.md),
                  itemBuilder: (context, i) {
                    final s = slots[i];
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(Gap.lg),
                        child: Row(
                          children: [
                            Container(
                              width: 4,
                              height: 48,
                              decoration: BoxDecoration(
                                color: scheme.primary,
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                            const SizedBox(width: Gap.lg),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    s.subject,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    Fmt.timeRange(s.startTime, s.endTime),
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      color: scheme.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Row(
                                    children: [
                                      Icon(Icons.room_outlined,
                                          size: 13,
                                          color: scheme.onSurfaceVariant),
                                      const SizedBox(width: 3),
                                      Text(
                                        s.room,
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          color: scheme.onSurfaceVariant,
                                        ),
                                      ),
                                      if (s.teacher != null) ...[
                                        const SizedBox(width: Gap.md),
                                        Icon(Icons.person_outline_rounded,
                                            size: 13,
                                            color: scheme.onSurfaceVariant),
                                        const SizedBox(width: 3),
                                        Expanded(
                                          child: Text(
                                            s.teacher!,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 11.5,
                                              color: scheme.onSurfaceVariant,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            if (!widget.mine)
                              IconButton(
                                tooltip: 'Remove',
                                icon: Icon(Icons.delete_outline_rounded,
                                    size: 19, color: scheme.onSurfaceVariant),
                                onPressed: () => _deleteSlot(s),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );

    if (!widget.showAppBar) return body;

    return Scaffold(
      appBar: AppBar(title: const Text('Timetable')),
      body: body,
      floatingActionButton: widget.mine || _batch == null
          ? null
          : FloatingActionButton.extended(
              onPressed: _addSlot,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add class'),
            ),
    );
  }
}

class _SlotSheet extends StatefulWidget {
  const _SlotSheet({required this.batch, required this.weekday});
  final Batch batch;
  final String weekday;

  @override
  State<_SlotSheet> createState() => _SlotSheetState();
}

class _SlotSheetState extends State<_SlotSheet> {
  final _form = GlobalKey<FormState>();
  final _subject = TextEditingController();
  final _teacher = TextEditingController();
  late final _room = TextEditingController(text: widget.batch.room);

  late String _weekday = widget.weekday;
  TimeOfDay _start = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _end = const TimeOfDay(hour: 10, minute: 30);
  bool _saving = false;

  @override
  void dispose() {
    _subject.dispose();
    _teacher.dispose();
    _room.dispose();
    super.dispose();
  }

  String _hhmm(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _pick({required bool isStart}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _start : _end,
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _start = picked;
        // Keep the end after the start automatically.
        final endMin = _end.hour * 60 + _end.minute;
        final startMin = picked.hour * 60 + picked.minute;
        if (endMin <= startMin) {
          final next = startMin + 90;
          _end = TimeOfDay(hour: (next ~/ 60) % 24, minute: next % 60);
        }
      } else {
        _end = picked;
      }
    });
  }

  Future<void> _submit() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    if (_end.hour * 60 + _end.minute <= _start.hour * 60 + _start.minute) {
      showSnack(context, 'End time must be after the start time',
          isError: true);
      return;
    }
    setState(() => _saving = true);
    try {
      await context.read<ApiService>().createSlot({
        'batchId': widget.batch.id,
        'subject': _subject.text.trim(),
        if (_teacher.text.trim().isNotEmpty) 'teacher': _teacher.text.trim(),
        'weekday': _weekday,
        'startTime': _hhmm(_start),
        'endTime': _hhmm(_end),
        'room': _room.text.trim(),
      });
      if (!mounted) return;
      showSnack(context, 'Class added');
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: Gap.xl,
        right: Gap.xl,
        bottom: MediaQuery.of(context).viewInsets.bottom + Gap.xl,
      ),
      child: Form(
        key: _form,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Add class',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: Gap.xs),
              Text(
                widget.batch.name,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: Gap.xl),
              TextFormField(
                controller: _subject,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Subject'),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Subject is required'
                    : null,
              ),
              const SizedBox(height: Gap.lg),
              DropdownButtonFormField<String>(
                initialValue: _weekday,
                decoration: const InputDecoration(labelText: 'Day'),
                items: kWeekdays
                    .map((d) => DropdownMenuItem(
                          value: d,
                          child: Text(Fmt.titleCase(d)),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _weekday = v!),
              ),
              const SizedBox(height: Gap.lg),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => _pick(isStart: true),
                      borderRadius: BorderRadius.circular(kRadiusSm),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Start',
                          isDense: true,
                        ),
                        child: Text(Fmt.time(_hhmm(_start))),
                      ),
                    ),
                  ),
                  const SizedBox(width: Gap.md),
                  Expanded(
                    child: InkWell(
                      onTap: () => _pick(isStart: false),
                      borderRadius: BorderRadius.circular(kRadiusSm),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'End',
                          isDense: true,
                        ),
                        child: Text(Fmt.time(_hhmm(_end))),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Gap.lg),
              TextFormField(
                controller: _room,
                decoration: const InputDecoration(labelText: 'Room'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Room is required' : null,
              ),
              const SizedBox(height: Gap.lg),
              TextFormField(
                controller: _teacher,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Teacher (optional)',
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
                    : const Text('Add class'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
