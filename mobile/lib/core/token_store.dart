import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists the token pair + cached user so the app can restore a session
/// without a network round-trip on cold start.
class TokenStore {
  static const _kAccess = 'bp.accessToken';
  static const _kRefresh = 'bp.refreshToken';
  static const _kUser = 'bp.user';

  SharedPreferences? _prefs;
  Future<SharedPreferences> get _p async =>
      _prefs ??= await SharedPreferences.getInstance();

  String? accessToken;
  String? refreshToken;

  Future<void> load() async {
    final p = await _p;
    accessToken = p.getString(_kAccess);
    refreshToken = p.getString(_kRefresh);
  }

  Future<void> save({
    required String access,
    required String refresh,
    Map<String, dynamic>? user,
  }) async {
    final p = await _p;
    accessToken = access;
    refreshToken = refresh;
    await p.setString(_kAccess, access);
    await p.setString(_kRefresh, refresh);
    if (user != null) await p.setString(_kUser, jsonEncode(user));
  }

  Future<void> updateTokens({
    required String access,
    required String refresh,
  }) async {
    final p = await _p;
    accessToken = access;
    refreshToken = refresh;
    await p.setString(_kAccess, access);
    await p.setString(_kRefresh, refresh);
  }

  Future<Map<String, dynamic>?> cachedUser() async {
    final raw = (await _p).getString(_kUser);
    if (raw == null) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<void> clear() async {
    final p = await _p;
    accessToken = null;
    refreshToken = null;
    await p.remove(_kAccess);
    await p.remove(_kRefresh);
    await p.remove(_kUser);
  }
}
