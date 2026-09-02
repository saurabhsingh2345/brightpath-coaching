import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../core/config.dart';
import '../core/token_store.dart';
import '../models/models.dart';

/// Live message transport.
///
/// The REST API remains the source of truth - this only delivers messages
/// sooner. Every screen that listens here also refreshes over HTTP when it
/// opens, so a dropped socket degrades to "slightly stale", never to
/// "missing messages".
class ChatSocket {
  ChatSocket(this._tokens);

  final TokenStore _tokens;
  io.Socket? _socket;

  final _messages = StreamController<ChatMessage>.broadcast();
  final _conversations = StreamController<String>.broadcast();
  final ValueNotifier<bool> connected = ValueNotifier(false);

  /// New messages for any conversation the user participates in.
  Stream<ChatMessage> get onMessage => _messages.stream;

  /// Conversation ids whose list entry should be refreshed.
  Stream<String> get onConversationUpdate => _conversations.stream;

  void connect() {
    final token = _tokens.accessToken;
    if (token == null) return;
    if (_socket != null) {
      // Reconnect with the current token in case it was refreshed.
      disconnect();
    }

    final socket = io.io(
      '${AppConfig.host}/chat',
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': token})
          .enableReconnection()
          .setReconnectionDelay(1500)
          .setReconnectionDelayMax(10000)
          .disableAutoConnect()
          .build(),
    );

    socket.onConnect((_) => connected.value = true);
    socket.onDisconnect((_) => connected.value = false);
    socket.onConnectError((_) => connected.value = false);

    socket.on('message', (data) {
      if (data is Map) {
        try {
          _messages.add(
            ChatMessage.fromJson(Map<String, dynamic>.from(data)),
          );
        } catch (_) {
          // A malformed frame must never take the app down; HTTP will catch up.
        }
      }
    });

    socket.on('conversation', (data) {
      if (data is Map && data['conversationId'] != null) {
        _conversations.add(data['conversationId'].toString());
      }
    });

    socket.on('unauthorized', (_) {
      // The access token expired. The next HTTP call refreshes it; reconnect
      // after a short delay with whatever token is current by then.
      connected.value = false;
      socket.disconnect();
      Timer(const Duration(seconds: 3), () {
        if (_socket == socket && _tokens.accessToken != null) connect();
      });
    });

    _socket = socket;
    socket.connect();
  }

  void disconnect() {
    _socket?.dispose();
    _socket = null;
    connected.value = false;
  }

  void dispose() {
    disconnect();
    _messages.close();
    _conversations.close();
    connected.dispose();
  }
}
