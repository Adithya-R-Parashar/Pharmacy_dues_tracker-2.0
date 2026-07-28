import 'package:flutter/material.dart';

/// Extension to define custom colors for different urgency states in the app theme.
@immutable
class AppUrgencyColors extends ThemeExtension<AppUrgencyColors> {
  const AppUrgencyColors({
    required this.urgentRed,
    required this.warningAmber,
    required this.neutral,
  });

  final Color urgentRed;
  final Color warningAmber;
  final Color neutral;

  @override
  AppUrgencyColors copyWith({
    Color? urgentRed,
    Color? warningAmber,
    Color? neutral,
  }) {
    return AppUrgencyColors(
      urgentRed: urgentRed ?? this.urgentRed,
      warningAmber: warningAmber ?? this.warningAmber,
      neutral: neutral ?? this.neutral,
    );
  }

  @override
  AppUrgencyColors lerp(ThemeExtension<AppUrgencyColors>? other, double t) {
    if (other is! AppUrgencyColors) {
      return this;
    }
    return AppUrgencyColors(
      urgentRed: Color.lerp(urgentRed, other.urgentRed, t)!,
      warningAmber: Color.lerp(warningAmber, other.warningAmber, t)!,
      neutral: Color.lerp(neutral, other.neutral, t)!,
    );
  }
}

class AppTheme {
  // Named color constants for urgency states
  static const Color urgentRed = Color(0xFFD32F2F); // Overdue
  static const Color warningAmber = Color(0xFFF57C00); // Due within 3 days
  static const Color neutralDefault = Color(0xFF757575); // Neutral default

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF1976D2), // A clean blue palette
        brightness: Brightness.light,
        surface: Colors.grey[50], // minimal light background
      ),
      // Clean, minimal cards with subtle borders instead of heavy shadows
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          side: BorderSide(
            color: Colors.grey[200]!,
            width: 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      ),
      appBarTheme: const AppBarTheme(
        elevation: 0,
        centerTitle: false,
        scrolledUnderElevation: 0,
      ),
      // Add custom urgency colors extension
      extensions: const <ThemeExtension<dynamic>>[
        AppUrgencyColors(
          urgentRed: urgentRed,
          warningAmber: warningAmber,
          neutral: neutralDefault,
        ),
      ],
    );
  }
}
