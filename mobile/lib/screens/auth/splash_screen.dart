import 'package:flutter/material.dart';
import '../../core/brand.dart';
import '../../core/theme.dart';

/// Shown for the moment it takes to restore a stored session.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: scheme.primary,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(Brand.logo, color: Colors.white, size: 36),
            ),
            const SizedBox(height: Gap.xl),
            Text(
              Brand.fullName,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: Gap.xxl),
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.4),
            ),
          ],
        ),
      ),
    );
  }
}
