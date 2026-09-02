import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/theme_state.dart';

/// App-bar button that cycles light / dark / follow-device.
class ThemeToggleButton extends StatelessWidget {
  const ThemeToggleButton({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeState>();
    return IconButton(
      tooltip: theme.nextLabel,
      onPressed: theme.cycle,
      icon: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        transitionBuilder: (child, animation) => RotationTransition(
          turns: Tween(begin: 0.7, end: 1.0).animate(animation),
          child: FadeTransition(opacity: animation, child: child),
        ),
        // Keyed so the switcher animates when the icon changes.
        child: Icon(theme.icon, key: ValueKey(theme.icon)),
      ),
    );
  }
}
