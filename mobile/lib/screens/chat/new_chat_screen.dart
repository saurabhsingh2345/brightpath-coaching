import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/api_exception.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../state/async_value.dart';
import '../../state/auth_state.dart';
import '../../widgets/common.dart';
import '../../widgets/states.dart';

/// Pick someone to start a 1:1 thread with. Pops the conversation id.
/// Students only ever see staff here - the API enforces the same rule.
class NewChatScreen extends StatefulWidget {
  const NewChatScreen({super.key});

  @override
  State<NewChatScreen> createState() => _NewChatScreenState();
}

class _NewChatScreenState extends State<NewChatScreen> {
  late final ApiService _api;
  late final AsyncController<List<ChatContact>> _ctrl;
  String _search = '';
  bool _opening = false;

  @override
  void initState() {
    super.initState();
    _api = context.read<ApiService>();
    _ctrl = AsyncController(
      () => _api.chatContacts(search: _search.isEmpty ? null : _search),
    )..load();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _open(ChatContact contact) async {
    if (_opening) return;
    setState(() => _opening = true);
    try {
      final id = await _api.startDirect(contact.id);
      if (!mounted) return;
      Navigator.pop(context, id);
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, isError: true);
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isAdmin = context.watch<AuthState>().isAdmin;

    return Scaffold(
      appBar: AppBar(
        title: Text(isAdmin ? 'New message' : 'Message staff'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.sm, Gap.lg, Gap.md),
            child: SearchBarField(
              hint: isAdmin ? 'Search students or staff…' : 'Search staff…',
              onChanged: (v) {
                _search = v;
                _ctrl.load();
              },
            ),
          ),
          Expanded(
            child: ListenableBuilder(
              listenable: _ctrl,
              builder: (context, _) {
                if (_ctrl.isFirstLoad) return const SkeletonList(height: 70);
                if (_ctrl.error != null && !_ctrl.hasData) {
                  return ErrorView(error: _ctrl.error!, onRetry: _ctrl.load);
                }
                final contacts = _ctrl.data ?? const <ChatContact>[];
                if (contacts.isEmpty) {
                  return EmptyView(
                    icon: Icons.person_search_outlined,
                    title: _search.isEmpty
                        ? 'Nobody to message'
                        : 'No match for "$_search"',
                    message: _search.isEmpty
                        ? (isAdmin
                            ? 'Add students first, then you can message them.'
                            : 'No staff account is available right now.')
                        : 'Try a different name or student ID.',
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                      Gap.lg, 0, Gap.lg, Gap.xxl),
                  itemCount: contacts.length,
                  separatorBuilder: (_, __) => const SizedBox(height: Gap.sm),
                  itemBuilder: (context, i) {
                    final c = contacts[i];
                    return Card(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(kRadius),
                        onTap: () => _open(c),
                        child: Padding(
                          padding: const EdgeInsets.all(Gap.md),
                          child: Row(
                            children: [
                              InitialsAvatar(name: c.name, size: 42),
                              const SizedBox(width: Gap.lg),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      c.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14.5,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      c.isAdmin
                                          ? 'Administrator'
                                          : [
                                              c.studentCode,
                                              c.batchName ?? 'No batch',
                                            ].whereType<String>().join(' · '),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: scheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (c.isAdmin)
                                const StatusPill(
                                  label: 'STAFF',
                                  color: Color(0xFF6172F3),
                                  dense: true,
                                ),
                              const SizedBox(width: Gap.sm),
                              Icon(Icons.chat_bubble_outline_rounded,
                                  size: 18, color: scheme.onSurfaceVariant),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
