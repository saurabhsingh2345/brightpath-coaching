import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/formatters.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../state/auth_state.dart';
import '../../state/chat_state.dart';
import '../../widgets/common.dart';
import '../../widgets/states.dart';
import 'chat_thread_screen.dart';
import 'new_chat_screen.dart';

/// Conversation list: batch groups and 1:1 threads, newest activity first.
class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key, this.showAppBar = true});
  final bool showAppBar;

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  String _search = '';

  @override
  void initState() {
    super.initState();
    // The list is owned app-wide; make sure it has data when first opened.
    final chat = context.read<ChatState>();
    if (chat.conversations.isEmpty) chat.load();
  }

  Future<void> _openThread(Conversation c) async {
    context.read<ChatState>().clearUnreadFor(c.id);
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatThreadScreen(
          conversationId: c.id,
          title: c.title,
          subtitle: c.subtitle,
          isBatch: c.isBatch,
          isLocked: c.isLocked,
        ),
      ),
    );
    if (mounted) context.read<ChatState>().refresh();
  }

  Future<void> _newChat() async {
    final conversationId = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const NewChatScreen()),
    );
    if (conversationId == null || !mounted) return;
    await context.read<ChatState>().refresh();
    if (!mounted) return;
    final chat = context.read<ChatState>();
    final match = chat.conversations.firstWhere(
      (c) => c.id == conversationId,
      orElse: () => chat.conversations.first,
    );
    _openThread(match);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final chat = context.watch<ChatState>();
    final isAdmin = context.watch<AuthState>().isAdmin;

    final term = _search.toLowerCase();
    final visible = term.isEmpty
        ? chat.conversations
        : chat.conversations
            .where((c) =>
                c.title.toLowerCase().contains(term) ||
                (c.lastMessageText ?? '').toLowerCase().contains(term))
            .toList();

    final body = Column(
      children: [
        if (chat.conversations.length > 4)
          Padding(
            padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.sm, Gap.lg, Gap.md),
            child: SearchBarField(
              hint: 'Search conversations…',
              onChanged: (v) => setState(() => _search = v),
            ),
          ),
        // A quiet strip so the user knows why messages might be delayed.
        ValueListenableBuilder<bool>(
          valueListenable: chat.socket.connected,
          builder: (context, connected, _) => connected
              ? const SizedBox.shrink()
              : Container(
                  width: double.infinity,
                  color: StatusColors.partial.withValues(alpha: 0.12),
                  padding: const EdgeInsets.symmetric(
                    horizontal: Gap.lg,
                    vertical: Gap.sm,
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.cloud_off_rounded,
                          size: 14, color: StatusColors.partial),
                      const SizedBox(width: Gap.sm),
                      Expanded(
                        child: Text(
                          'Reconnecting — messages may take a moment to arrive.',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
        ),
        Expanded(
          child: Builder(
            builder: (context) {
              if (chat.isFirstLoad) return const SkeletonList(height: 82);
              if (chat.error != null && chat.conversations.isEmpty) {
                return ErrorView(error: chat.error!, onRetry: chat.load);
              }
              if (chat.conversations.isEmpty) {
                return EmptyView(
                  icon: Icons.forum_outlined,
                  title: 'No conversations yet',
                  message: isAdmin
                      ? 'Message a student directly, or post in a batch group.'
                      : 'Message your institute staff with any doubt or update.',
                  actionLabel: 'Start a conversation',
                  onAction: _newChat,
                );
              }
              if (visible.isEmpty) {
                return EmptyView(
                  icon: Icons.search_off_rounded,
                  title: 'Nothing matches "$_search"',
                  message: 'Try a different name or keyword.',
                );
              }
              return RefreshIndicator(
                onRefresh: chat.refresh,
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                      Gap.lg, Gap.sm, Gap.lg, Gap.xxl * 2),
                  itemCount: visible.length,
                  separatorBuilder: (_, __) => const SizedBox(height: Gap.md),
                  itemBuilder: (context, i) => _ConversationTile(
                    conversation: visible[i],
                    onTap: () => _openThread(visible[i]),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );

    if (!widget.showAppBar) return body;

    return Scaffold(
      appBar: AppBar(title: const Text('Chat')),
      body: body,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _newChat,
        icon: const Icon(Icons.add_comment_rounded),
        label: Text(isAdmin ? 'Message' : 'Ask staff'),
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({required this.conversation, required this.onTap});

  final Conversation conversation;
  final VoidCallback onTap;

  String _stamp(DateTime? at) {
    if (at == null) return '';
    final now = DateTime.now();
    final sameDay =
        at.year == now.year && at.month == now.month && at.day == now.day;
    if (sameDay) {
      final h = at.hour % 12 == 0 ? 12 : at.hour % 12;
      final suffix = at.hour >= 12 ? 'PM' : 'AM';
      return '$h:${at.minute.toString().padLeft(2, '0')} $suffix';
    }
    final yesterday = now.subtract(const Duration(days: 1));
    if (at.year == yesterday.year &&
        at.month == yesterday.month &&
        at.day == yesterday.day) {
      return 'Yesterday';
    }
    return Fmt.dateShort(at);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final c = conversation;
    final hasUnread = c.unreadCount > 0;

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(kRadius),
        child: Padding(
          padding: const EdgeInsets.all(Gap.lg),
          child: Row(
            children: [
              if (c.isBatch)
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: const Color(0xFF6172F3).withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.groups_rounded,
                      size: 22, color: Color(0xFF6172F3)),
                )
              else
                InitialsAvatar(name: c.title, size: 46),
              const SizedBox(width: Gap.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            c.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight:
                                  hasUnread ? FontWeight.w800 : FontWeight.w700,
                              fontSize: 14.5,
                            ),
                          ),
                        ),
                        if (c.isLocked) ...[
                          Icon(Icons.lock_rounded,
                              size: 13, color: scheme.onSurfaceVariant),
                          const SizedBox(width: Gap.xs),
                        ],
                        Text(
                          _stamp(c.lastMessageAt),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight:
                                hasUnread ? FontWeight.w700 : FontWeight.w400,
                            color: hasUnread
                                ? scheme.primary
                                : scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            c.lastMessageText ??
                                (c.isBatch
                                    ? '${c.memberCount} members · no messages yet'
                                    : 'No messages yet'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12.5,
                              height: 1.3,
                              color: hasUnread
                                  ? scheme.onSurface
                                  : scheme.onSurfaceVariant,
                              fontWeight: hasUnread
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                          ),
                        ),
                        if (hasUnread) ...[
                          const SizedBox(width: Gap.sm),
                          Container(
                            constraints: const BoxConstraints(minWidth: 20),
                            height: 20,
                            padding:
                                const EdgeInsets.symmetric(horizontal: 6),
                            decoration: BoxDecoration(
                              color: scheme.primary,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              c.unreadCount > 99 ? '99+' : '${c.unreadCount}',
                              style: TextStyle(
                                color: scheme.onPrimary,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
