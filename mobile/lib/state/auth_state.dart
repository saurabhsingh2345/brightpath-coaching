import 'package:flutter/foundation.dart';
import '../core/api_client.dart';
import '../core/api_exception.dart';
import '../core/token_store.dart';
import '../models/models.dart';
import '../services/api_service.dart';

enum AuthStatus { initializing, unauthenticated, authenticated }

class AuthState extends ChangeNotifier {
  AuthState({
    required this.tokens,
    required this.client,
    required this.api,
  }) {
    client.onSessionExpired = () {
      _user = null;
      _status = AuthStatus.unauthenticated;
      _error = 'Your session expired. Please log in again.';
      notifyListeners();
    };
  }

  final TokenStore tokens;
  final ApiClient client;
  final ApiService api;

  AuthStatus _status = AuthStatus.initializing;
  AppUser? _user;
  String? _error;
  bool _busy = false;

  AuthStatus get status => _status;
  AppUser? get user => _user;
  String? get error => _error;
  bool get busy => _busy;
  bool get isAdmin => _user?.isAdmin ?? false;

  /// Restore a session on cold start. Falls back to the cached user if the
  /// network is unavailable but tokens exist, so the app opens offline.
  Future<void> bootstrap() async {
    await tokens.load();
    if (tokens.accessToken == null) {
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return;
    }
    try {
      _user = await api.me();
      _status = AuthStatus.authenticated;
    } on ApiException catch (e) {
      if (e.isNetwork) {
        final cached = await tokens.cachedUser();
        if (cached != null) {
          _user = AppUser.fromJson(cached);
          _status = AuthStatus.authenticated;
        } else {
          _status = AuthStatus.unauthenticated;
        }
      } else {
        await tokens.clear();
        _status = AuthStatus.unauthenticated;
      }
    }
    notifyListeners();
  }

  Future<bool> login(String email, String password) async {
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      final res = await api.login(email, password);
      final user = AppUser.fromJson(
          Map<String, dynamic>.from(res['user'] as Map));
      await tokens.save(
        access: res['accessToken'] as String,
        refresh: res['refreshToken'] as String,
        user: user.toJson(),
      );
      _user = user;
      _status = AuthStatus.authenticated;
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    _busy = true;
    notifyListeners();
    await api.logout();
    await tokens.clear();
    _user = null;
    _error = null;
    _status = AuthStatus.unauthenticated;
    _busy = false;
    notifyListeners();
  }

  Future<void> refreshUser() async {
    try {
      _user = await api.me();
      await tokens.save(
        access: tokens.accessToken!,
        refresh: tokens.refreshToken!,
        user: _user!.toJson(),
      );
      notifyListeners();
    } on ApiException catch (_) {
      // Keep the current user; the screen will surface its own error.
    }
  }

  void clearError() {
    if (_error == null) return;
    _error = null;
    notifyListeners();
  }
}
