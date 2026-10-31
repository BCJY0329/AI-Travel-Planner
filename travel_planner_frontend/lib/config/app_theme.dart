import 'package:flutter/material.dart';

class AppTheme {
  static const motionFast = Duration(milliseconds: 200);
  static const motionStandard = Duration(milliseconds: 300);
  static const motionEntrance = Duration(milliseconds: 400);
  static const motionCurve = Curves.easeOutCubic;
  // Calm Sky Blue, lemon and warm sand on cream, balanced 60/30/10:
  // - 60% warm neutrals (cream page, [sorbet], [sand]) carry Lemon's halo,
  //   her tips, step numbers, tags and badges;
  // - 30% sky blue marks everything you can press ([cta], [ctaSoft]), the
  //   selected tab and chips ([skyBlue]), links and icons ([primary]);
  // - 10% lemon yellow belongs to Lemon herself: her avatar ring, the
  //   lemon on the wordmark's "i", a ring round her halo and her tip bulb.
  static const Color paleBlue = Color(0xFFE6F0FB); // Calendar range, day tint
  static const Color peach = Color(0xFFFFEADF);
  static const Color sky = Color(0xFFEEF5FC); // Soft blue tint for boxes
  static const Color skyBlue = Color(0xFFCFE1F6); // Selected tab and chips
  static const Color skyBlueBright = Color(0xFF3D8BD9);
  static const Color primary = Color(0xFF2F5F98); // Links, icons (6.5:1)
  static const Color primaryDark = Color(0xFF234A78);
  static const Color primaryLight = Color(0xFF3E73B0);
  // Historical names: these hold the pale sky blue container tints.
  static const Color lavenderTint = Color(0xFFDDEAF8);
  static const Color lavenderSubtle = Color(0xFFEEF5FC);
  static const Color background = Color(0xFFFFFBF2); // Warm cream page
  static const Color surface = Color(0xFFFFFFFF);
  static const Color border = Color(0xFFE9E4D8);
  static const Color borderLight = Color(0xFFF2EEE4);
  // Input outlines need 3:1 against white and the pale tints (3.6:1 on
  // white, 3.3:1 on sky); [border] stays for decorative card edges.
  static const Color fieldBorder = Color(0xFF7189A6);
  // Keyboard focus ring: 5.8:1 on the sky blue button, 9:1 on white.
  static const Color focusRing = Color(0xFF234A78);
  // Pale sky blue, set apart from the cream page but lighter than the
  // selected-tab pill (skyBlue) so tabs and the wordmark stay clear.
  static const Color navBar = Color(0xFFEAF2FB);
  static const Color navBarBorder = Color(0xFFCCDDF1);
  static const Color navBarText = Color(0xFF55667A); // 5.2:1 on navBar

  // Pressable things: one sky blue main action, pale blue partners.
  static const Color cta = Color(0xFFB5D3F2);
  static const Color ctaInk = Color(0xFF23395B); // 7.5:1 on cta
  static const Color ctaSoft = Color(0xFFE3EFFB);

  // Warm neutrals for Lemon's voice and quiet details.
  static const Color sorbet = Color(0xFFFBF6E3);
  static const Color sand = Color(0xFFF1E6D3);
  static const Color sandBorder = Color(0xFFEADBC2);
  static const Color sandInk = Color(0xFF4E3B22); // 8.6:1 on sand
  static const Color sorbetInk = Color(0xFF5E4A1A); // 7.9:1 on sorbet
  static const Color lilac = Color(0xFFECE8FB); // Fourth itinerary day
  static const Color lilacAccent = Color(0xFFCFC6F2);
  static const Color peachAccent = Color(0xFFFFC9AE);

  /// Soft (tint, accent) pairs from the palette (sky, peach, sand, lilac)
  /// that the search pages rotate through so cards and steps don't all share
  /// one blue. textPrimary reads above 4.5:1 on every one of them.
  static const List<(Color, Color)> softTones = [
    (ctaSoft, cta),
    (peach, peachAccent),
    (sorbet, sand),
    (lilac, lilacAccent),
  ];

  /// A stable tone for [key], so the same carrier or category keeps its
  /// colour across searches.
  static (Color, Color) toneFor(String key) =>
      softTones[key.codeUnits.fold<int>(0, (a, c) => a + c) % softTones.length];

  // Text colors: slate-blue ink that stays above 4.5:1 on cream, white,
  // the blue tints and sand (secondary: 4.6:1 on skyBlue, 6.1:1 on white).
  static const Color textPrimary = Color(0xFF3E4F66);
  static const Color textSecondary = Color(0xFF52637A);
  static const Color textMuted = Color(0xFF52637A);
  // Chat copy uses a crisper neutral slate.
  static const Color chatText = Color(0xFF3A4A5A);

  // Lemon's own yellow, kept to small accents.
  static const Color accentLemon = Color(0xFFF9D648);
  static const Color accentLemonDark = Color(0xFFE9B824);
  static const Color lemonInk = Color(0xFF2A2410); // Text on lemon
  // Deeper lemon and sand for the wordmark's colour wave: 3.5:1 on navBar,
  // enough for large bold text.
  static const Color lemonDeep = Color(0xFFA07A00);
  static const Color sandDeep = Color(0xFF9A7A4C);
  static const Color success = Color(0xFF10B981);
  static const Color error = Color(0xFFC62828); // 5.6:1 on white

  // Typography: Discover uses Poppins for headings; body text keeps the
  // platform default (Roboto on Web/Android).
  static const String headingFont = 'Poppins';
  // Flights, Hotels, Attractions and Itinerary: Unbounded headings, Outfit
  // body, and rounded Fredoka for Lemon's notes.
  static const String tripHeadingFont = 'Unbounded';
  static const String tripBodyFont = 'Outfit';
  static const String noteFont = 'Fredoka';

  /// Whether focus should be drawn: never after touch input, matching
  /// Material's own focus highlight.
  static bool get showFocus =>
      FocusManager.instance.highlightMode == FocusHighlightMode.traditional;

  static const focusSide = BorderSide(color: focusRing, width: 2.5);

  /// A button outline that becomes the focus ring while focused.
  static WidgetStateProperty<BorderSide?> focusOutline([BorderSide? rest]) =>
      WidgetStateProperty.resolveWith((states) =>
          states.contains(WidgetState.focused) && showFocus ? focusSide : rest);

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
        secondary: primary,
        onSecondary: Colors.white,
        secondaryContainer: lavenderSubtle,
        onSecondaryContainer: textPrimary,
        surface: surface,
        onSurface: textPrimary,
        surfaceContainerLowest: surface,
        surfaceContainerLow: background,
        surfaceContainer: Color(0xFFF3F7FC),
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
          backgroundColor: cta,
          foregroundColor: ctaInk,
          elevation: 0,
          shadowColor: const Color(0xFF6EA0DC).withValues(alpha: .5),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          shape: const StadiumBorder(),
          textStyle: TextStyle(
              fontFamily: body, fontWeight: FontWeight.w700, fontSize: 14),
        ).copyWith(
            side: focusOutline(),
            elevation: WidgetStateProperty.resolveWith(
                (states) => states.contains(WidgetState.hovered) ? 4 : 0)),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          backgroundColor: ctaSoft,
          foregroundColor: ctaInk,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: const StadiumBorder(),
          textStyle: TextStyle(
              fontFamily: body, fontWeight: FontWeight.w600, fontSize: 13),
        ).copyWith(
            side: focusOutline(const BorderSide(color: cta, width: 1.5))),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: primary)
            .copyWith(side: focusOutline()),
      ),
      iconButtonTheme:
          IconButtonThemeData(style: ButtonStyle(side: focusOutline())),
      chipTheme: ChipThemeData(
        backgroundColor: surface,
        selectedColor: skyBlue,
        checkmarkColor: textPrimary,
        side: WidgetStateBorderSide.resolveWith((states) =>
            states.contains(WidgetState.focused) && showFocus
                ? focusSide
                : const BorderSide(color: border)),
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
          borderSide: const BorderSide(color: fieldBorder, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: fieldBorder, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primary, width: 1.8),
        ),
      ),
    );
  }
}
