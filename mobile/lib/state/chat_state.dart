import 'dart:async';
import 'package:flutter/foundation.dart';
import '../core/api_exception.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/chat_socket.dart';

/// Owns the conversation list and the unread badge.
///
/// Kept app-wide (rather than per-screen) so the bottom-bar badge stays
/// accurate no matter which tab is open.
class ChatState extends ChangeNotifier {
  ChatState({required this.api, required this.socket}) {
    _messageSub = socket.onMessage.listen(_onIncoming);
    _convSub = socket.onConversationUpdate.listen((_) => refresh());
  }

  final ApiService api;
  final ChatSocket socket;

  StreamSubscription<ChatMessage>? _messageSub;
  StreamSubscription<String>? _convSub;
  Timer? _poll;

  List<Conversation> _conversations = const [];
  ApiException? _error;
  bool _loading = false;
  int _unread = 0;

  List<Conversation> get conversations => _conversations;
  ApiException? get error => _error;
  bool get isLoading => _loading;
  bool get isFirstLoad => _loading && _conversations.isEmpty;
  int get unreadTotal => _unread;

  /// Poll as a safety net for whatever the socket misses (backgrounded app,
  /// flaky network). Cheap: one small request.
  void start() {
    load();
    socket.connect();
    _poll?.cancel();
    _poll = Timer.periodic(const Duration(seconds: 20), (_) => refresh());
  }

  void stop() {
    _poll?.cancel();
    _poll = null;
    socket.disconnect();
    _conversations = const [];
    _unread = 0;
  }

  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();
    await _fetch();
    _loading = false;
    notifyListeners();
  }

  Future<void> refresh() async {
    await _fetch();
    notifyListeners();
  }

  Future<void> _fetch() async {
    try {
      final list = await api.conversations();
      _conversations = list;
      _unread = list.fold<int>(0, (sum, c) => sum + c.unreadCount);
      _error = null;
    } on ApiException catch (e) {
      _error = e;
    } catch (_) {
      // Never let a background poll surface as a hard failure.
    }
  }

  /// A socket message arrived: bump the matching row without a round trip.
  void _onIncoming(ChatMessage message) {
    final index =
        _conversations.indexWhere((c) => c.id == message.conversationId);
    if (index == -1) {
      // A brand new thread - fetch the list so it appears.
      refresh();
      return;
    }
    final existing = _conversations[index];
    final updated = Conversation(
      id: existing.id,
      type: existing.type,
      title: existing.title,
      subtitle: existing.subtitle,
      isLocked: existing.isLocked,
      unreadCount: existing.unreadCount + 1,
      memberCount: existing.memberCount,
      participants: existing.participants,
      lastMessageAt: message.createdAt ?? DateTime.now(),
      lastMessageText: message.body,
      batchName: existing.batchName,
    );

    final next = [..._conversations]..[index] = updated;
    next.sort((a, b) {
      final at = a.lastMessageAt?.millisecondsSinceEpoch ?? 0;
      final bt = b.lastMessageAt?.millisecondsSinceEpoch ?? 0;
      if (at != bt) return bt - at;
      return a.title.compareTo(b.title);
    });
    _conversations = next;
    _unread += 1;
    notifyListeners();
  }

  /// Called when a thread is opened, so the badge drops immediately.
  void clearUnreadFor(String conversationId) {
    final index = _conversations.indexWhere((c) => c.id == conversationId);
    if (index == -1) return;
    final existing = _conversations[index];
    if (existing.unreadCount == 0) return;

    _unread = (_unread - existing.unreadCount).clamp(0, 1 << 30);
    _conversations = [..._conversations]..[index] = Conversation(
          id: existing.id,
          type: existing.type,
          title: existing.title,
          subtitle: existing.subtitle,
          isLocked: existing.isLocked,
          unreadCount: 0,
          memberCount: existing.memberCount,
          participants: existing.participants,
          lastMessageAt: existing.lastMessageAt,
          lastMessageText: existing.lastMessageText,
          batchName: existing.batchName,
        );
    notifyListeners();
  }

  @override
  void dispose() {
    _poll?.cancel();
    _messageSub?.cancel();
    _convSub?.cancel();
    super.dispose();
  }
}
