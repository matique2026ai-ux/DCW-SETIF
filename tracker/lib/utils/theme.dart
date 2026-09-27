import 'package:flutter/material.dart';

class AppTheme {
  static const PrimaryColor = Color(0xFF881337);
  static const PrimaryLightColor = Color(0xFF9F1239);
  static const AccentColor = Color(0xFFD4AF37);
  static const AccentLightColor = Color(0xFFFDE68A);
  static const SidebarColor = Color(0xFF4C0519);
  static const BackgroundColor = Color(0xFF1A0A1F);
  static const CardColor = Color(0xFF2D1035);
  static const SurfaceColor = Color(0xFF3D1A45);
  static const TextPrimary = Color(0xFFFFFFFF);
  static const TextSecondary = Color(0xFFB0B0B0);
  static const BorderColor = Color(0xFF4A2050);
  static const SuccessColor = Color(0xFF10B981);
  static const WarningColor = Color(0xFFF59E0B);
  static const DangerColor = Color(0xFFEF4444);

  static ThemeData getTheme({bool isArabic = true}) {
    final font = isArabic ? 'Tajawal' : 'Plus Jakarta Sans';

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: PrimaryColor,
      scaffoldBackgroundColor: BackgroundColor,
      fontFamily: font,
      colorScheme: const ColorScheme.dark(
        primary: PrimaryColor,
        secondary: AccentColor,
        surface: CardColor,
        error: DangerColor,
        onPrimary: Colors.white,
        onSecondary: Colors.black,
        onSurface: Colors.white,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: const Color(0xFF2D1035),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontFamily: font,
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      cardTheme: CardThemeData(
        color: CardColor,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: BorderColor.withValues(alpha: 0.3), width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: PrimaryColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: TextStyle(
            fontFamily: font,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: SurfaceColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: BorderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: BorderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AccentColor, width: 2),
        ),
        labelStyle: TextStyle(fontFamily: font, color: TextSecondary),
        floatingLabelStyle: TextStyle(
          fontFamily: font,
          fontWeight: FontWeight.bold,
          color: AccentColor,
        ),
        hintStyle: TextStyle(
          fontFamily: font,
          color: TextSecondary.withValues(alpha: 0.6),
        ),
      ),
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: AccentColor,
        selectionColor: Color(0x66D4AF37),
        selectionHandleColor: AccentColor,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Color(0xFF2D1035),
        selectedItemColor: AccentColor,
        unselectedItemColor: TextSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      dividerTheme: DividerThemeData(color: BorderColor.withValues(alpha: 0.3)),
      dialogTheme: DialogThemeData(
        backgroundColor: CardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }

  static ThemeData get darkTheme => getTheme(isArabic: true);
  static ThemeData get lightTheme => darkTheme;
}
