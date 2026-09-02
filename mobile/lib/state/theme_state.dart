import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Remembers the user's light/dark choice.
///
/// Defaults to [ThemeMode.system] so the app matches the phone until the user
/// expresses a preference, after which their choice wins on every launch.
class ThemeState extends ChangeNotifier {
  static const _key = 'bp.themeMode';

  ThemeMode _mode = ThemeMode.system;
  ThemeMode get mode => _mode;

  /// Load the stored preference. Failing to read it is not worth surfacing -
  /// the app just follows the system, which is the default anyway.
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _mode = _decode(prefs.getString(_key));
      notifyListeners();
    } catch (_) {
      /* keep ThemeMode.system */
    }
  }

  Future<void> set(ThemeMode mode) async {
    if (_mode == mode) return;
    _mode = mode;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, _encode(mode));
    } catch (_) {
      /* the choice still applies for this session */
    }
  }

  /// Cycles system → light → dark → system.
  Future<void> cycle() => set(switch (_mode) {
        ThemeMode.system => ThemeMode.light,
        ThemeMode.light => ThemeMode.dark,
        ThemeMode.dark => ThemeMode.system,
      });

  /// Icon for the *current* state, so the button shows what is in effect.
  IconData get icon => switch (_mode) {
        ThemeMode.system => Icons.brightness_auto_rounded,
        ThemeMode.light => Icons.light_mode_rounded,
        ThemeMode.dark => Icons.dark_mode_rounded,
      };

  String get label => switch (_mode) {
        ThemeMode.system => 'Matching your device',
        ThemeMode.light => 'Light',
        ThemeMode.dark => 'Dark',
      };

  /// What tapping will switch to - used for the tooltip.
  String get nextLabel => switch (_mode) {
        ThemeMode.system => 'Switch to light',
        ThemeMode.light => 'Switch to dark',
        ThemeMode.dark => 'Match my device',
      };

  static ThemeMode _decode(String? v) => switch (v) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };

  static String _encode(ThemeMode m) => switch (m) {
        ThemeMode.light => 'light',
        ThemeMode.dark => 'dark',
        ThemeMode.system => 'system',
      };
}
