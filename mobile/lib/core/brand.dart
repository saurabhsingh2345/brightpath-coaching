import 'package:flutter/material.dart';

/// Everything visual about the institute lives here.
/// Swap these five values to rebrand the whole app.
class Brand {
  const Brand._();

  static const String name = 'BrightPath';
  static const String fullName = 'BrightPath Coaching';
  static const String tagline = 'Learn with clarity';

  /// One primary brand colour. Material 3 derives the rest of the scheme.
  static const Color seed = Color(0xFF3D5AFE);

  /// The mark shown on the splash / login screen and in the app bar.
  static const IconData logo = Icons.school_rounded;

  /// Currency used across fees.
  static const String currencySymbol = '₹';
}
