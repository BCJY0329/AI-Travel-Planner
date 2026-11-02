import 'package:flutter/material.dart';

/// One page's colour from the palette. The search pages use sky blue (the
/// default) and the pre-plan itinerary uses sand (DECISIONS 044, 046, 047).
/// It tints the hero, search card, field labels, step numbers and tiles.
class PagePalette {
  final Color tint, mid, card, accent, deep, ink, body, field;
  final Color search, searchInk;
  const PagePalette(
      {required this.tint,
      required this.mid,
      required this.card,
      required this.accent,
      required this.deep,
      required this.ink,
      required this.body,
      required this.field,
      required this.search,
      required this.searchInk});

  // Contrast: deep labels are 5.6–6.8:1 on white, ink and body 7:1 or more
  // on tint, field outlines at least 3:1 on white.
  static const sky = PagePalette(
      tint: Color(0xFFEEF5FC),
      mid: Color(0xFFCFE1F6),
      card: Color(0xFFCFE1F6),
      accent: Color(0xFFB5D3F2),
      deep: Color(0xFF2F5F98),
      ink: Color(0xFF23395B),
      body: Color(0xFF52637A),
      field: Color(0xFF7189A6),
      search: Color(0xFFB5D3F2),
      searchInk: Color(0xFF23395B));
  static const sand = PagePalette(
      tint: Color(0xFFFBF6E3),
      mid: Color(0xFFF1E6D3),
      card: Color(0xFFF1E6D3),
      accent: Color(0xFFEADBC2),
      deep: Color(0xFF7A5C2E),
      ink: Color(0xFF4E3B22),
      body: Color(0xFF5E4A1A),
      field: Color(0xFF9A8259),
      search: Color(0xFFE8D3AC),
      searchInk: Color(0xFF4E3B22));
}

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
  // Outline for the pale partner buttons: one step deeper than [cta] so
  // the edge holds on white and on the pale tints.
  static const Color ctaEdge = Color(0xFF9CC2EA);

  // Warm neutrals for Lemon's voice and quiet details.
  static const Color sorbet = Color(0xFFFBF6E3);
  static const Color sand = Color(0xFFF1E6D3);
  static const Color sandBorder = Color(0xFFEADBC2);
  static const Color sandInk = Color(0xFF4E3B22); // 8.6:1 on sand
  static const Color sorbetInk = Color(0xFF5E4A1A); // 7.9:1 on sorbet
  // Peach and lilac belong to the itinerary, Discover and the traveller's
  // chat bubble only; Flights, Hotels and Attractions use sky blue, lemon
  // and sand (DECISIONS 048).
  static const Color peach = Color(0xFFFFEADF);
  static const Color peachAccent = Color(0xFFFFC9AE);
  static const Color lilac = Color(0xFFECE8FB);
  static const Color lilacAccent = Color(0xFFCFC6F2);
  // Soft lemon for tiles, steps and day colours; textPrimary is 6.8:1 or
  // more on both, lemonInk 12.8:1 or more.
  static const Color lemonTint = Color(0xFFFFF6CC);
  static const Color lemonAccent = Color(0xFFFCE89A);

  // Chat bubbles. Lemon's are plain white with a warm hairline edge and a
  // soft shadow (DECISIONS 055): white keeps yellow and blue emoji vivid,
  // and her yellow stays on her avatar instead of outlining every message.
  // chatText is 9:1 on white. The traveller's fade sky blue into lilac
  // (ctaInk, 7.5:1 or more; DECISIONS 048).
  static const Color lemonBubbleEdge = Color(0xFFEDE6D6);
  static const Color bubbleShadow = Color(0xFF6B5A3A);
  static const travellerBubble = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [cta, lilac]);

  // Chat progress: grey before a step, sand while it waits for an answer,
  // lemon once answered.
  static const stepTodo = Color(0xFFDDE1E6);
  static const stepCurrent = Color(0xFFE2CBA2);

  // Warm sand "Plan with Lemon" buttons (DECISIONS 044): sandInk is 7.4:1.
  static const planButton = Color(0xFFE8D3AC);
  static const planButtonBorder = Color(0xFFD9BF92);

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
  // Lemon.ai chat: message bubbles, option hints, the hover card and what
  // the traveller types (DECISIONS 057, replacing 050's Nunito). Lexend is
  // built for easy reading, so Lemon's words stay clear without drawing
  // attention; bundled at 400, 600 and 700.
  static const String chatFont = 'Lexend';
  // Every button label, on every page and in the chat panel (DECISIONS
  // 056): Outfit, extra bold (800) on filled buttons and bold (700) on
  // outlined, text and pill buttons, so no button falls back to Roboto.
  static const String buttonFont = 'Outfit';

  /// A button label in [buttonFont].
  static TextStyle buttonText(
          {double size = 15, FontWeight weight = FontWeight.w800}) =>
      TextStyle(
          fontFamily: buttonFont,
          fontSize: size,
          fontWeight: weight,
          letterSpacing: .1);

  // Solid buttons (DECISIONS 056): a soft coloured shadow under every
  // filled button at rest, deeper on hover, none while disabled, matching
  // the Find Flights button.
  static const Color ctaShadow = Color(0x806EA0DC);
  static WidgetStateProperty<double?> solidElevation(
          {double rest = 3, double hover = 6}) =>
      WidgetStateProperty.resolveWith((states) =>
          states.contains(WidgetState.disabled)
              ? 0
              : states.contains(WidgetState.hovered) ||
                      states.contains(WidgetState.focused)
                  ? hover
                  : rest);

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
          shadowColor: ctaShadow,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
          minimumSize: const Size(64, 48),
          shape: const StadiumBorder(),
          textStyle: buttonText(),
        ).copyWith(side: focusOutline(), elevation: solidElevation()),
      ),
      // Partner buttons: pale sky blue with a deeper sky edge and a faint shadow, so
      // they read as pressable without competing with the filled action.
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          backgroundColor: ctaSoft,
          foregroundColor: ctaInk,
          shadowColor: ctaShadow,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          minimumSize: const Size(64, 44),
          shape: const StadiumBorder(),
          textStyle: buttonText(size: 14, weight: FontWeight.w700),
        ).copyWith(
            side: focusOutline(const BorderSide(color: ctaEdge, width: 1.5)),
            elevation: solidElevation(rest: 1, hover: 3)),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
                foregroundColor: primary,
                textStyle: buttonText(size: 14, weight: FontWeight.w700))
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
