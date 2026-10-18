import 'package:flutter/material.dart';

class AppTheme {
  static const motionFast = Duration(milliseconds: 200);
  static const motionStandard = Duration(milliseconds: 300);
  static const motionEntrance = Duration(milliseconds: 400);
  static const motionCurve = Curves.easeOutCubic;
  // Sky Mint on cream: lemon yellow is reserved for Lemon.ai and the main
  // action; the pastel carries supporting controls; deeper mint is for small
  // text links only.
  static const Color mint = Color(0xFFE4F6F1);
  static const Color peach = Color(0xFFFFEADF);
  static const Color sky = Color(0xFFEEF9F7);
  static const Color lemon = Color(0xFFFFF3BD);
  static const Color teal = Color(0xFF2E7A73);
  static const Color skyMint = Color(0xFFC9EEE7); // Secondary buttons, tabs
  static const Color skyMintBright = Color(0xFF36C2B0); // "Trip" in the logo
  static const Color primary = Color(0xFF2E7A73); // Links, focus, icons
  static const Color primaryDark = Color(0xFF245F5A);
  static const Color primaryLight = Color(0xFF3B8C84);
  // Historical names: these now hold the Sky Mint container tints.
  static const Color lavenderTint = Color(0xFFDDF3EF);
  static const Color lavenderSubtle = Color(0xFFEEF9F7);
  static const Color background = Color(0xFFFFFBF2); // Warm cream page
  static const Color surface = Color(0xFFFFFFFF);
  static const Color border = Color(0xFFE9E4D8);
  static const Color borderLight = Color(0xFFF2EEE4);
  // Pale Sky Mint, set apart from the cream page but lighter than the
  // selected-tab pill (skyMint) so tabs and logo stay clear.
  static const Color navBar = Color(0xFFE8F7F3);
  static const Color navBarBorder = Color(0xFFCBE8E1);
  static const Color navBarText = Color(0xFF56696A); // ~5.2:1 on pale mint

  // Text colors: lighter slate-mint ink that stays above 4.5:1 on cream.
  static const Color textPrimary = Color(0xFF3F5A58);
  static const Color textSecondary = Color(0xFF637775);
  static const Color textMuted = Color(0xFF637775);
  // Chat copy uses a crisper neutral slate.
  static const Color chatText = Color(0xFF3A4A5A);

  // Accent colors
  static const Color accentLemon = Color(0xFFF9D648); // Lemon.ai + primary CTA
  static const Color accentLemonDark = Color(0xFFE9B824);
  static const Color lemonInk = Color(0xFF2A2410); // Text on lemon
  static const Color success = Color(0xFF10B981);
  static const Color error = Color(0xFFEF4444);

  // Typography: Discover uses Poppins for headings; body text keeps the
  // platform default (Roboto on Web/Android).
  static const String headingFont = 'Poppins';
  // Flights, Hotels, Attractions and Itinerary: Unbounded headings, Outfit
  // body, and rounded Fredoka for Lemon's notes.
  static const String tripHeadingFont = 'Unbounded';
  static const String tripBodyFont = 'Outfit';
  static const String noteFont = 'Fredoka';

  static ThemeData get lightTheme => _build(heading: headingFont);

  static ThemeData get tripTheme =>
      _build(heading: tripHeadingFont, body: tripBodyFont);

  static ThemeData _build({required String heading, String? body}) {
    var textTheme = TextTheme(
      bodyLarge: TextStyle(fontFamily: body, fontSize: 16, height: 1.5),
      bodyMedium: TextStyle(fontFamily: body, fontSize: 15, height: 1.5),
      bodySmall: TextStyle(fontFamily: body, fontSize: 13, height: 1.4),
      labelLarge: TextStyle(
          fontFamily: body, fontSize: 14, fontWeight: FontWeight.w600),
      titleMedium: TextStyle(
          fontFamily: body,
          fontSize: 18,
          height: 1.3,
          fontWeight: FontWeight.w700),
      titleLarge: TextStyle(
          fontFamily: heading,
          fontSize: 24,
          height: 1.2,
          fontWeight: FontWeight.w800),
    );
    if (body != null) {
      // Fill every other style so nothing falls back to the platform font,
      // then give the large display/headline styles the heading face.
      final full = ThemeData(useMaterial3: true)
          .textTheme
          .merge(textTheme)
          .apply(fontFamily: body);
      TextStyle? head(TextStyle? s) => s?.copyWith(fontFamily: heading);
      textTheme = full.copyWith(
        displayLarge: head(full.displayLarge),
        displayMedium: head(full.displayMedium),
        displaySmall: head(full.displaySmall),
        headlineLarge: head(full.headlineLarge),
        headlineMedium: head(full.headlineMedium),
        headlineSmall: head(full.headlineSmall),
        titleLarge: head(full.titleLarge),
      );
    }
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: background,
      primaryColor: primary,
      colorScheme: const ColorScheme(
        brightness: Brightness.light,
        primary: primary,
        onPrimary: Colors.white,
        primaryContainer: lavenderTint,
        onPrimaryContainer: textPrimary,
        secondary: teal,
        onSecondary: Colors.white,
        secondaryContainer: lavenderSubtle,
        onSecondaryContainer: textPrimary,
        surface: surface,
        onSurface: textPrimary,
        surfaceContainerLowest: surface,
        surfaceContainerLow: background,
        surfaceContainer: Color(0xFFF2F8F5),
        error: error,
        onError: Colors.white,
        outline: border,
        outlineVariant: borderLight,
      ),
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: navBar,
        surfaceTintColor: Colors.transparent,
        foregroundColor: textPrimary,
        elevation: 0,
        scrolledUnderElevation: 1,
        shape: const Border(bottom: BorderSide(color: navBarBorder)),
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: heading,
          color: textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: border, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accentLemon,
          foregroundColor: lemonInk,
          elevation: 0,
          shadowColor: accentLemon.withValues(alpha: .5),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          shape: const StadiumBorder(),
          textStyle: TextStyle(
              fontFamily: body, fontWeight: FontWeight.w700, fontSize: 14),
        ).copyWith(
            elevation: WidgetStateProperty.resolveWith(
                (states) => states.contains(WidgetState.hovered) ? 4 : 0)),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          backgroundColor: skyMint,
          foregroundColor: textPrimary,
          side: BorderSide.none,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: const StadiumBorder(),
          textStyle: TextStyle(
              fontFamily: body, fontWeight: FontWeight.w600, fontSize: 13),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: primary),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surface,
        selectedColor: skyMint,
        checkmarkColor: textPrimary,
        side: const BorderSide(color: border),
        shape: const StadiumBorder(),
        labelStyle: TextStyle(
            fontFamily: body,
            color: textPrimary,
            fontWeight: FontWeight.w500,
            fontSize: 13),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        hintStyle: TextStyle(fontFamily: body, color: textMuted, fontSize: 14),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: border, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: border, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primary, width: 1.8),
        ),
      ),
    );
  }
}
