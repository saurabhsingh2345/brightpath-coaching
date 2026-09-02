import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../state/async_value.dart';
import '../../widgets/common.dart';
import '../../widgets/states.dart';
import 'student_detail_screen.dart';
import 'student_form_screen.dart';

enum StudentFilter { all, active, inactive }

class StudentsScreen extends StatefulWidget {
  const StudentsScreen({super.key, this.initialBatchId, this.title});

  final String? initialBatchId;
  final String? title;

  @override
  State<StudentsScreen> createState() => _StudentsScreenState();
}

class _StudentsScreenState extends State<StudentsScreen> {
  late final ApiService _api;
  late final AsyncController<Paged<Student>> _ctrl;
  final _scroll = ScrollController();

  String _search = '';
  String? _batchId;
  StudentFilter _filter = StudentFilter.all;
  List<Batch> _batches = const [];

  final List<Student> _items = [];
  int _page = 1;
  bool _loadingMore = false;
  bool _hasNext = false;

  @override
  void initState() {
    super.initState();
    _api = context.read<ApiService>();
    _batchId = widget.initialBatchId;
    _ctrl = AsyncController(_fetch);
    _scroll.addListener(_onScroll);
    _bootstrap();
  }

  @override
  void dispose() {
    _scroll.dispose();
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    await _reload();
    try {
      final b = await _api.batches();
      if (mounted) setState(() => _batches = b);
    } catch (_) {
      // Filters degrade gracefully without the batch list.
    }
  }

  Future<Paged<Student>> _fetch() => _api.students(
        page: _page,
        search: _search.isEmpty ? null : _search,
        batchId: _batchId,
        isActive: switch (_filter) {
          StudentFilter.all => null,
          StudentFilter.active => true,
          StudentFilter.inactive => false,
        },
      );

  Future<void> _reload() async {
    _page = 1;
    await _ctrl.load();
    final data = _ctrl.data;
    if (!mounted) return;
    setState(() {
      _items
        ..clear()
        ..addAll(data?.items ?? const []);
      _hasNext = data?.hasNext ?? false;
    });
  }

  void _onScroll() {
    if (!_hasNext || _loadingMore) return;
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 300) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    setState(() => _loadingMore = true);
    _page += 1;
    try {
      final next = await _fetch();
      if (!mounted) return;
      setState(() {
        _items.addAll(next.items);
        _hasNext = next.hasNext;
      });
    } catch (e) {
      _page -= 1;
      if (mounted) showSnack(context, 'Could not load more', isError: true);
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _openForm({Student? student}) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => StudentFormScreen(student: student, batches: _batches),
      ),
    );
    if (changed == true) _reload();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isNested = widget.initialBatchId != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title ?? 'Students'),
        automaticallyImplyLeading: isNested,
        actions: [
          IconButton(
            tooltip: 'Add student',
            onPressed: () => _openForm(),
            icon: const Icon(Icons.person_add_alt_1_rounded),
          ),
          const SizedBox(width: Gap.sm),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(Gap.lg, 0, Gap.lg, Gap.md),
            child: SearchBarField(
              hint: 'Search by name, ID, phone…',
              onChanged: (v) {
                _search = v;
                _reload();
              },
            ),
          ),
          FilterChips<StudentFilter>(
            options: StudentFilter.values,
            selected: _filter,
            labelOf: (f) => switch (f) {
              StudentFilter.all => 'All',
              StudentFilter.active => 'Active',
              StudentFilter.inactive => 'Inactive',
            },
            onSelected: (f) {
              setState(() => _filter = f);
              _reload();
            },
          ),
          if (_batches.isNotEmpty && !isNested)
            Padding(
              padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.sm, Gap.lg, 0),
              child: DropdownButtonFormField<String?>(
                initialValue: _batchId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Batch',
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: Gap.lg,
                    vertical: Gap.md,
                  ),
                ),
                items: [
                  const DropdownMenuItem(value: null, child: Text('All batches')),
                  ..._batches.map(
                    (b) => DropdownMenuItem(value: b.id, child: Text(b.name)),
                  ),
                ],
                onChanged: (v) {
                  setState(() => _batchId = v);
                  _reload();
                },
              ),
            ),
          Expanded(
            child: ListenableBuilder(
              listenable: _ctrl,
              builder: (context, _) {
                if (_ctrl.isFirstLoad) return const SkeletonList();
                if (_ctrl.error != null && _items.isEmpty) {
                  return ErrorView(error: _ctrl.error!, onRetry: _reload);
                }
                if (_items.isEmpty) {
                  return EmptyView(
                    icon: Icons.people_outline_rounded,
                    title: _search.isEmpty
                        ? 'No students yet'
                        : 'No match for "$_search"',
                    message: _search.isEmpty
                        ? 'Add your first student to get started.'
                        : 'Try a different name, student ID or phone number.',
                    actionLabel: _search.isEmpty ? 'Add student' : null,
                    onAction: _search.isEmpty ? () => _openForm() : null,
                  );
                }
                return RefreshIndicator(
                  onRefresh: _reload,
                  child: ListView.separated(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(
                        Gap.lg, Gap.md, Gap.lg, Gap.xxl * 2),
                    itemCount: _items.length + (_hasNext ? 1 : 0),
                    separatorBuilder: (_, __) => const SizedBox(height: Gap.md),
                    itemBuilder: (context, i) {
                      if (i >= _items.length) {
                        return const Padding(
                          padding: EdgeInsets.all(Gap.lg),
                          child: Center(
                            child: SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2.4),
                            ),
                          ),
                        );
                      }
                      final s = _items[i];
                      return StudentCard(
                        student: s,
                        onTap: () async {
                          final changed = await Navigator.push<bool>(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  StudentDetailScreen(studentId: s.id),
                            ),
                          );
                          if (changed == true) _reload();
                        },
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openForm(),
        tooltip: 'Add student',
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        child: const Icon(Icons.add_rounded),
      ),
    );
  }
}

class StudentCard extends StatelessWidget {
  const StudentCard({super.key, required this.student, this.onTap});

  final Student student;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(kRadius),
        child: Padding(
          padding: const EdgeInsets.all(Gap.lg),
          child: Row(
            children: [
              InitialsAvatar(name: student.name, size: 46),
              const SizedBox(width: Gap.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            student.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        if (!student.isActive)
                          const StatusPill(
                            label: 'INACTIVE',
                            color: StatusColors.pending,
                            dense: true,
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${student.studentCode} · ${student.phone}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: Gap.sm),
                    Row(
                      children: [
                        Icon(Icons.groups_outlined,
                            size: 13, color: scheme.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            student.batch?.name ?? 'No batch assigned',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: student.batch == null
                                  ? StatusColors.partial
                                  : scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  color: scheme.onSurfaceVariant, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
