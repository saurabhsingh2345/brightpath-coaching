import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/api_exception.dart';
import '../../core/formatters.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../state/auth_state.dart';
import '../../state/chat_state.dart';
import '../../widgets/common.dart';
import '../../widgets/states.dart';

/// A single conversation. Messages arrive over the socket; the initial page
/// and any back-fill come over HTTP.
class ChatThreadScreen extends StatefulWidget {
  const ChatThreadScreen({
    super.key,
    required this.conversationId,
    required this.title,
    required this.subtitle,
    required this.isBatch,
    this.isLocked = false,
  });

  final String conversationId;
  final String title;
  final String subtitle;
  final bool isBatch;
  final bool isLocked;

  @override
  State<ChatThreadScreen> createState() => _ChatThreadScreenState();
}

class _ChatThreadScreenState extends State<ChatThreadScreen> {
  late final ApiService _api;
  late final ChatState _chat;
  final _scroll = ScrollController();
  final _input = TextEditingController();

  final List<ChatMessage> _messages = [];
  StreamSubscription<ChatMessage>? _sub;

  ApiException? _error;
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = false;
  bool _sending = false;
  late bool _isLocked = widget.isLocked;

  @override
  void initState() {
    super.initState();
    _api = context.read<ApiService>();
    _chat = context.read<ChatState>();

    _sub = _chat.socket.onMessage.listen((m) {
      if (m.conversationId != widget.conversationId) return;
      if (!mounted) return;
      setState(() {
        // Guard against a duplicate if HTTP already delivered it.
        if (_messages.any((x) => x.id == m.id)) return;
        _messages.add(m);
      });
      _markRead();
      _jumpToBottom();
    });

    _scroll.addListener(() {
      // Oldest messages are at the top; back-fill when the user reaches it.
      if (_scroll.position.pixels <= 80) _loadOlder();
    });

    _load();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _scroll.dispose();
    _input.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await _api.messages(widget.conversationId);
      if (!mounted) return;
      setState(() {
        _messages
          ..clear()
          ..addAll(page.messages);
        _hasMore = page.hasMore;
        _isLocked = page.isLocked;
        _loading = false;
      });
      _markRead();
      _jumpToBottom(animated: false);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _error = e;
          _loading = false;
        });
      }
    }
  }

  Future<void> _loadOlder() async {
    if (!_hasMore || _loadingMore || _messages.isEmpty) return;
    setState(() => _loadingMore = true);
    try {
      final oldest = _messages.first.createdAt;
      final page = await _api.messages(
        widget.conversationId,
        before: oldest?.toUtc().toIso8601String(),
      );
      if (!mounted) return;
      setState(() {
        _messages.insertAll(0, page.messages);
        _hasMore = page.hasMore;
      });
    } on ApiException catch (_) {
      if (mounted) {
        showSnack(context, 'Could not load older messages', isError: true);
      }
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  void _markRead() {
    _api.markConversationRead(widget.conversationId).catchError((_) {});
    _chat.clearUnreadFor(widget.conversationId);
  }

  void _jumpToBottom({bool animated = true}) {
    // One frame later, so the new item is laid out before we scroll.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      final target = _scroll.position.maxScrollExtent;
      if (animated) {
        _scroll.animateTo(
          target,
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOut,
        );
      } else {
        _scroll.jumpTo(target);
      }
    });
  }

  Future<void> _send() async {
    final body = _input.text.trim();
    if (body.isEmpty || _sending) return;

    final me = context.read<AuthState>().user?.name ?? 'You';
    final pending = ChatMessage.pending(
      conversationId: widget.conversationId,
      body: body,
      senderName: me,
    );

    setState(() {
      _messages.add(pending);
      _input.clear();
      _sending = true;
    });
    _jumpToBottom();

    try {
      final saved = await _api.sendMessage(widget.conversationId, body);
      if (!mounted) return;
      setState(() {
        final i = _messages.indexWhere((m) => m.id == pending.id);
        if (i != -1) _messages[i] = saved;
      });
      _chat.refresh();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _messages.removeWhere((m) => m.id == pending.id);
        // Put the text back so nothing is silently lost.
        _input.text = body;
      });
      showSnack(context, e.message, isError: true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _toggleLock() async {
    try {
      final msg = await _api.setConversationLocked(
        widget.conversationId,
        !_isLocked,
      );
      if (!mounted) return;
      setState(() => _isLocked = !_isLocked);
      showSnack(context, msg);
      _chat.refresh();
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, isError: true);
    }
  }

  Future<void> _deleteMessage(ChatMessage m) async {
    final ok = await confirm(
      context,
      title: 'Delete message?',
      message: 'It will show as deleted for everyone in this conversation.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok) return;
    try {
      final updated = await _api.deleteMessage(m.id);
      if (!mounted) return;
      setState(() {
        final i = _messages.indexWhere((x) => x.id == m.id);
        if (i != -1) _messages[i] = updated;
      });
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, isError: true);
    }
  }

  /// Group messages so a date header is inserted whenever the day changes.
  List<_Row> _rows() {
    final rows = <_Row>[];
    DateTime? lastDay;
    for (final m in _messages) {
      final at = m.createdAt;
      if (at != null) {
        final day = DateTime(at.year, at.month, at.day);
        if (lastDay == null || day != lastDay) {
          rows.add(_Row.divider(day));
          lastDay = day;
        }
      }
      rows.add(_Row.message(m));
    }
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isAdmin = context.watch<AuthState>().isAdmin;
    final canPost = isAdmin || !_isLocked;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            if (widget.isBatch)
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: const Color(0xFF6172F3).withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.groups_rounded,
                    size: 17, color: Color(0xFF6172F3)),
              )
            else
              InitialsAvatar(name: widget.title, size: 34),
            const SizedBox(width: Gap.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  Text(
                    _isLocked ? '${widget.subtitle} · read-only' : widget.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          if (isAdmin && widget.isBatch)
            IconButton(
              tooltip: _isLocked ? 'Allow students to post' : 'Make read-only',
              icon: Icon(
                _isLocked ? Icons.lock_rounded : Icons.lock_open_rounded,
              ),
              onPressed: _toggleLock,
            ),
          const SizedBox(width: Gap.xs),
        ],
      ),
      body: Column(
        children: [
          Expanded(child: _body()),
          SafeArea(
            top: false,
            child: canPost
                ? _composer(scheme)
                : Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(Gap.lg),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(color: Theme.of(context).dividerColor),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.lock_rounded,
                            size: 15, color: scheme.onSurfaceVariant),
                        const SizedBox(width: Gap.sm),
                        Text(
                          'Only staff can post in this group',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _body() {
    if (_loading) return const LoadingView();
    if (_error != null && _messages.isEmpty) {
      return ErrorView(error: _error!, onRetry: _load);
    }
    if (_messages.isEmpty) {
      return EmptyView(
        icon: Icons.chat_bubble_outline_rounded,
        title: 'No messages yet',
        message: widget.isBatch
            ? 'Say hello to the group.'
            : 'Send the first message to ${widget.title}.',
      );
    }

    final rows = _rows();
    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.lg, Gap.lg, Gap.lg),
      itemCount: rows.length + (_hasMore ? 1 : 0),
      itemBuilder: (context, i) {
        if (_hasMore && i == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: Gap.lg),
            child: Center(
              child: _loadingMore
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2.2),
                    )
                  : TextButton(
                      onPressed: _loadOlder,
                      child: const Text('Load earlier messages'),
                    ),
            ),
          );
        }
        final row = rows[_hasMore ? i - 1 : i];
        if (row.day != null) return _DateDivider(day: row.day!);
        return _Bubble(
          message: row.message!,
          showSender: widget.isBatch,
          onLongPress: row.message!.isMine && !row.message!.isDeleted
              ? () => _deleteMessage(row.message!)
              : null,
        );
      },
    );
  }

  Widget _composer(ColorScheme scheme) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        border: Border(
          top: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(Gap.md, Gap.sm, Gap.md, Gap.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: _input,
              minLines: 1,
              maxLines: 5,
              maxLength: 4000,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.newline,
              keyboardType: TextInputType.multiline,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Write a message…',
                counterText: '',
                filled: true,
                fillColor: scheme.surfaceContainerHighest
                    .withValues(alpha: 0.45),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(color: scheme.primary, width: 1.4),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: Gap.lg,
                  vertical: Gap.md,
                ),
              ),
            ),
          ),
          const SizedBox(width: Gap.sm),
          _SendButton(
            enabled: _input.text.trim().isNotEmpty && !_sending,
            busy: _sending,
            onTap: _send,
          ),
        ],
      ),
    );
  }
}

/// Either a date header or a message.
class _Row {
  _Row.divider(this.day) : message = null;
  _Row.message(this.message) : day = null;
  final DateTime? day;
  final ChatMessage? message;
}

class _DateDivider extends StatelessWidget {
  const _DateDivider({required this.day});
  final DateTime day;

  String get _label {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return Fmt.date(day);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Gap.lg),
      child: Center(
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: Gap.md, vertical: 4),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            _label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.message,
    required this.showSender,
    this.onLongPress,
  });

  final ChatMessage message;
  final bool showSender;
  final VoidCallback? onLongPress;

  String _time(DateTime? at) {
    if (at == null) return '';
    final h = at.hour % 12 == 0 ? 12 : at.hour % 12;
    final suffix = at.hour >= 12 ? 'PM' : 'AM';
    return '$h:${at.minute.toString().padLeft(2, '0')} $suffix';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final m = message;
    final mine = m.isMine;

    final bg = m.isDeleted
        ? scheme.surfaceContainerHighest.withValues(alpha: 0.5)
        : (mine ? scheme.primary : scheme.surfaceContainerLow);
    final fg = m.isDeleted
        ? scheme.onSurfaceVariant
        : (mine ? scheme.onPrimary : scheme.onSurface);

    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.sm),
      child: Row(
        mainAxisAlignment:
            mine ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!mine && showSender) ...[
            InitialsAvatar(name: m.senderName, size: 28),
            const SizedBox(width: Gap.sm),
          ],
          Flexible(
            child: GestureDetector(
              onLongPress: onLongPress,
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.76,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: Gap.lg,
                  vertical: Gap.md,
                ),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(18),
                    topRight: const Radius.circular(18),
                    bottomLeft: Radius.circular(mine ? 18 : 5),
                    bottomRight: Radius.circular(mine ? 5 : 18),
                  ),
                  border: mine || m.isDeleted
                      ? null
                      : Border.all(
                          color: Theme.of(context).dividerColor,
                        ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!mine && showSender)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 3),
                        child: Row(
                          children: [
                            Text(
                              m.senderName,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: scheme.primary,
                              ),
                            ),
                            if (m.fromAdmin) ...[
                              const SizedBox(width: 4),
                              const StatusPill(
                                label: 'STAFF',
                                color: Color(0xFF6172F3),
                                dense: true,
                              ),
                            ],
                          ],
                        ),
                      ),
                    Text(
                      m.body,
                      style: TextStyle(
                        color: fg,
                        fontSize: 14.5,
                        height: 1.4,
                        fontStyle:
                            m.isDeleted ? FontStyle.italic : FontStyle.normal,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _time(m.createdAt),
                          style: TextStyle(
                            fontSize: 10,
                            color: mine
                                ? scheme.onPrimary.withValues(alpha: 0.75)
                                : scheme.onSurfaceVariant,
                          ),
                        ),
                        if (m.isPending) ...[
                          const SizedBox(width: 4),
                          SizedBox(
                            width: 9,
                            height: 9,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.4,
                              color: scheme.onPrimary.withValues(alpha: 0.8),
                            ),
                          ),
                        ] else if (mine)
                          Padding(
                            padding: const EdgeInsets.only(left: 3),
                            child: Icon(
                              Icons.done_rounded,
                              size: 11,
                              color: scheme.onPrimary.withValues(alpha: 0.8),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  const _SendButton({
    required this.enabled,
    required this.busy,
    required this.onTap,
  });

  final bool enabled;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: enabled
            ? scheme.primary
            : scheme.surfaceContainerHighest.withValues(alpha: 0.7),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        onPressed: enabled ? onTap : null,
        icon: busy
            ? SizedBox(
                width: 17,
                height: 17,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: scheme.onPrimary,
                ),
              )
            : Icon(
                Icons.arrow_upward_rounded,
                size: 20,
                color: enabled ? scheme.onPrimary : scheme.onSurfaceVariant,
              ),
      ),
    );
  }
}
