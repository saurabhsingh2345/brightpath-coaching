import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'brand.dart';

/// Shared spacing scale - keeps padding consistent everywhere.
class Gap {
  const Gap._();
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
}

const double kRadius = 18;
const double kRadiusSm = 12;

ThemeData buildTheme({Brightness brightness = Brightness.light}) {
  final scheme = ColorScheme.fromSeed(
    seedColor: Brand.seed,
    brightness: brightness,
  );
  final isLight = brightness == Brightness.light;
  final base = ThemeData.from(colorScheme: scheme);

  final textTheme = base.textTheme.apply(
    bodyColor: scheme.onSurface,
    displayColor: scheme.onSurface,
  );

  return base.copyWith(
    scaffoldBackgroundColor: isLight
        ? const Color(0xFFF7F8FC)
        : scheme.surface,
    textTheme: textTheme.copyWith(
      headlineSmall: textTheme.headlineSmall?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
      ),
      titleLarge: textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
      ),
      titleMedium: textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
      ),
      labelLarge: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: isLight ? const Color(0xFFF7F8FC) : scheme.surface,
      surfaceTintColor: Colors.transparent,
      foregroundColor: scheme.onSurface,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      centerTitle: false,
      titleTextStyle: textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: isLight ? Colors.white : scheme.surfaceContainerLow,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(kRadius),
        side: BorderSide(
          color: isLight
              ? const Color(0xFFE8EAF2)
              : scheme.outlineVariant.withValues(alpha: 0.35),
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: isLight ? Colors.white : scheme.surfaceContainerHighest,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: Gap.lg,
        vertical: Gap.lg,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(kRadiusSm),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(kRadiusSm),
        borderSide: BorderSide(
          color: isLight ? const Color(0xFFE0E3ED) : scheme.outlineVariant,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(kRadiusSm),
        borderSide: BorderSide(color: scheme.primary, width: 1.6),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(kRadiusSm),
        borderSide: BorderSide(color: scheme.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(kRadiusSm),
        borderSide: BorderSide(color: scheme.error, width: 1.6),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(kRadiusSm),
        ),
        textStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 16,
          letterSpacing: 0.1,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(kRadiusSm),
        ),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    chipTheme: ChipThemeData(
      side: BorderSide.none,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(999),
      ),
      // No labelStyle here: Material 3 needs to resolve label colour per
      // selected/unselected state, which a single TextStyle cannot express.
      padding: const EdgeInsets.symmetric(horizontal: Gap.sm, vertical: 2),
    ),
    dividerTheme: DividerThemeData(
      color: isLight
          ? const Color(0xFFEDEFF5)
          : scheme.outlineVariant.withValues(alpha: 0.3),
      thickness: 1,
      space: 1,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: isLight ? Colors.white : scheme.surfaceContainerLow,
      surfaceTintColor: Colors.transparent,
      indicatorColor: scheme.primary.withValues(alpha: 0.12),
      elevation: 0,
      height: 68,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      labelTextStyle: WidgetStatePropertyAll(
        TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          color: scheme.onSurfaceVariant,
        ),
      ),
    ),
    // Surfaces are pinned explicitly. Leaving them to the framework produced
    // a light sheet over a dark page, so both themes state their own colours.
    bottomSheetTheme: BottomSheetThemeData(
      showDragHandle: true,
      surfaceTintColor: Colors.transparent,
      backgroundColor: isLight ? Colors.white : scheme.surfaceContainerLow,
      modalBackgroundColor:
          isLight ? Colors.white : scheme.surfaceContainerLow,
      dragHandleColor: scheme.onSurfaceVariant.withValues(alpha: 0.4),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),
    dialogTheme: DialogThemeData(
      surfaceTintColor: Colors.transparent,
      backgroundColor: isLight ? Colors.white : scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(kRadius),
      ),
    ),
    datePickerTheme: DatePickerThemeData(
      surfaceTintColor: Colors.transparent,
      backgroundColor: isLight ? Colors.white : scheme.surfaceContainerLow,
    ),
    timePickerTheme: TimePickerThemeData(
      backgroundColor: isLight ? Colors.white : scheme.surfaceContainerLow,
    ),
    popupMenuTheme: PopupMenuThemeData(
      surfaceTintColor: Colors.transparent,
      color: isLight ? Colors.white : scheme.surfaceContainerLow,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(kRadiusSm),
      ),
    ),
    listTileTheme: const ListTileThemeData(
      contentPadding: EdgeInsets.symmetric(horizontal: Gap.lg),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      },
    ),
  );
}

/// Status colours used by attendance / fees badges.
class StatusColors {
  const StatusColors._();
  static const present = Color(0xFF12B76A);
  static const absent = Color(0xFFF04438);
  static const late = Color(0xFFF79009);
  static const leave = Color(0xFF6172F3);
  static const paid = Color(0xFF12B76A);
  static const partial = Color(0xFFF79009);
  static const pending = Color(0xFF667085);
  static const overdue = Color(0xFFF04438);

  static Color forAttendance(String? s) => switch (s) {
        'PRESENT' => present,
        'ABSENT' => absent,
        'LATE' => late,
        'LEAVE' => leave,
        _ => pending,
      };

  static Color forFee(String? s) => switch (s) {
        'PAID' => paid,
        'PARTIAL' => partial,
        'OVERDUE' => overdue,
        _ => pending,
      };
}
