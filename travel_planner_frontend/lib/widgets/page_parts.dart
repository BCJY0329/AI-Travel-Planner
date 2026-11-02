import 'package:flutter/material.dart';
import '../config/app_theme.dart';
import '../config/discover_content.dart';
import 'focus_ring.dart';
import 'gentle_reveal.dart';
import 'hover_lift.dart';
import 'lemon_motion.dart';

/// Building blocks shared by the Flights, Hotels, Attractions and itinerary
/// pages: photo banner with Lemon's tip, search card, how-to steps, results
/// banner and hover cards.

const _lemonArt = 'assets/images/lemon_avatar.png';
const _chipSelected = Color(0xFF9EC2EA);

/// Gives a trip page its own type: Outfit body text under Unbounded
/// headings. Dialogs and pickers opened from inside inherit it too.
class TripTypography extends StatelessWidget {
  final Widget child;
  const TripTypography({super.key, required this.child});
  @override
  Widget build(BuildContext context) => Theme(
      data: AppTheme.tripTheme,
      child: DefaultTextStyle.merge(
          style: const TextStyle(fontFamily: AppTheme.tripBodyFont),
          child: child));
}

/// Gives the shared page parts below their page's colour (DECISIONS 044).
class PageTone extends InheritedWidget {
  final PagePalette palette;
  const PageTone({super.key, required this.palette, required super.child});
  static PagePalette of(BuildContext context) =>
      maybeOf(context) ?? PagePalette.sky;
  static PagePalette? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PageTone>()?.palette;
  @override
  bool updateShouldNotify(PageTone old) => old.palette != palette;
}

/// Unbounded is wide, so trip-page headings sit a touch tighter.
const tripHeading = TextStyle(
    fontFamily: AppTheme.tripHeadingFont,
    letterSpacing: -.4,
    fontWeight: FontWeight.w700);

/// Lemon's voice for her notes: rounded and friendly, but easy to read.
const lemonNote = TextStyle(
    fontFamily: AppTheme.noteFont, height: 1.45, fontWeight: FontWeight.w500);

/// Lemon in a circle filled with the colour of whatever she sits on, so she
/// never brings a coloured disc of her own.
class LemonCircle extends StatelessWidget {
  final double size;
  final Color background;
  final Color ring;
  final bool float;
  const LemonCircle(
      {super.key,
      required this.size,
      required this.background,
      this.ring = AppTheme.skyBlue,
      this.float = true});
  @override
  Widget build(BuildContext context) {
    final circle = Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
            color: background,
            shape: BoxShape.circle,
            border: Border.all(
                color: ring, width: ring == AppTheme.skyBlue ? 1.5 : 2)),
        child: ClipOval(
            child: Image.asset(_lemonArt,
                fit: BoxFit.cover,
                alignment: const Alignment(.15, -.9),
                excludeFromSemantics: true)));
    // Float the whole circle so the artwork never slides inside the clip.
    return float ? LemonFloat(distance: 5, child: circle) : circle;
  }
}

/// A speech bubble from Lemon, sized to be read rather than skimmed.
class LemonTip extends StatelessWidget {
  final String text;
  const LemonTip({super.key, required this.text});
  static const _avatar = 84.0;
  @override
  Widget build(BuildContext context) => Semantics(
      container: true,
      label: "Lemon's tip",
      child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Lifted so the bubble's sharp corner sits level with Lemon's
            // face rather than her shoulders.
            Flexible(
                child: Padding(
                    padding: const EdgeInsets.only(bottom: _avatar * .55),
                    child: Container(
                        padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
                        decoration: BoxDecoration(
                            color: AppTheme.sorbet,
                            borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(20),
                                topRight: Radius.circular(20),
                                bottomLeft: Radius.circular(20),
                                bottomRight: Radius.circular(3)),
                            border: Border.all(
                                color: AppTheme.accentLemon, width: 2),
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.black.withValues(alpha: .1),
                                  blurRadius: 30,
                                  offset: const Offset(0, 12))
                            ]),
                        child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.lightbulb_rounded,
                                        size: 20,
                                        color: AppTheme.accentLemonDark),
                                    SizedBox(width: 6),
                                    Flexible(
                                        child: Text("Lemon's tip",
                                            style: TextStyle(
                                                fontFamily: AppTheme.noteFont,
                                                color: AppTheme.sandInk,
                                                fontSize: 18,
                                                height: 1.2,
                                                fontWeight: FontWeight.w600))),
                                  ]),
                              const SizedBox(height: 6),
                              Text(text,
                                  style: lemonNote.copyWith(
                                      color: AppTheme.sandInk, fontSize: 16.5)),
                            ])))),
            const SizedBox(width: 12),
            const LemonCircle(
                size: _avatar,
                background: AppTheme.sorbet,
                ring: AppTheme.accentLemon),
          ]));
}

/// Photo banner with the page title and Lemon's tip; [search] overlaps its
/// lower edge.
class PageBanner extends StatelessWidget {
  final DiscoverPhoto photo;
  final Alignment photoAlignment;
  final String eyebrow, title, subtitle, tip;
  final Widget search;
  const PageBanner(
      {super.key,
      required this.photo,
      required this.eyebrow,
      required this.title,
      required this.subtitle,
      required this.tip,
      required this.search,
      this.photoAlignment = Alignment.center});
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
        final wide = box.maxWidth >= 820;
        final pad = wide ? 48.0 : 22.0;
        final tone = PageTone.of(context);
        final cream = tone.tint;
        final heading = Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GentleReveal(
                  child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                          color: tone.accent,
                          borderRadius: BorderRadius.circular(999)),
                      child: Text(eyebrow.toUpperCase(),
                          style: TextStyle(
                              color: tone.ink,
                              fontSize: 12.5,
                              letterSpacing: 1.4,
                              fontWeight: FontWeight.w800)))),
              const SizedBox(height: 10),
              GentleReveal(
                  delay: const Duration(milliseconds: 80),
                  child: Text(title,
                      style: tripHeading.copyWith(
                          color: tone.ink,
                          fontSize: wide ? 40 : 28,
                          height: 1.15,
                          letterSpacing: -1))),
              const SizedBox(height: 12),
              GentleReveal(
                  delay: const Duration(milliseconds: 160),
                  child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 460),
                      child: Text(subtitle,
                          style: TextStyle(
                              color: tone.body, fontSize: 17, height: 1.5)))),
            ]);
        final tipBubble = GentleReveal(
            delay: const Duration(milliseconds: 240),
            child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: LemonTip(text: tip)));
        return Stack(clipBehavior: Clip.none, children: [
          Positioned.fill(
              bottom: 56,
              child: ClipRRect(
                  borderRadius: BorderRadius.circular(30),
                  child: Stack(fit: StackFit.expand, children: [
                    ColoredBox(color: tone.tint),
                    SlowZoom(
                        child: BannerImage(photo, alignment: photoAlignment)),
                    DecoratedBox(
                        decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [
                      cream.withValues(alpha: .97),
                      cream.withValues(alpha: .88),
                      cream.withValues(alpha: wide ? .15 : .72),
                      cream.withValues(alpha: wide ? 0 : .6),
                    ], stops: const [
                      0,
                      .42,
                      .75,
                      1
                    ]))),
                  ]))),
          Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Padding(
                padding: EdgeInsets.fromLTRB(
                    pad, wide ? 44 : 28, pad, wide ? 36 : 28),
                child: wide
                    ? Row(children: [
                        Expanded(child: heading),
                        const SizedBox(width: 24),
                        tipBubble,
                      ])
                    : heading),
            Padding(
                padding: EdgeInsets.symmetric(horizontal: wide ? 24 : 10),
                child: GentleReveal(
                    delay: const Duration(milliseconds: 320), child: search)),
            // On small screens the search comes first and Lemon follows it.
            if (!wide) ...[
              const SizedBox(height: 20),
              Align(alignment: Alignment.centerLeft, child: tipBubble),
            ],
          ]),
        ]);
      });
}

/// The white card that holds a page's search fields.
class SearchCard extends StatelessWidget {
  final Widget child;

  /// Caps the card's width, centred on the page, so a short search row does
  /// not stretch into dead space across a wide page (DECISIONS 049, 053,
  /// centred by 057).
  final double? maxWidth;
  const SearchCard({super.key, required this.child, this.maxWidth});
  @override
  Widget build(BuildContext context) => maxWidth == null
      ? _card(context)
      : Align(
          alignment: Alignment.center,
          child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth!),
              child: _card(context)));

  Widget _card(BuildContext context) => Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          // Filled with the page colour so the white fields stand out.
          color: PageTone.of(context).card,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
                color: PageTone.of(context).ink.withValues(alpha: .14),
                blurRadius: 40,
                offset: const Offset(0, 18))
          ]),
      child: child);
}

/// Text style for values typed into a [SearchField].
const searchValueStyle = TextStyle(
    color: AppTheme.textPrimary, fontSize: 19, fontWeight: FontWeight.w700);

/// Whether a search row fits on one line: [width] must reach [needed],
/// scaled up with the reader's text size so large text stacks the fields
/// instead of squeezing them.
bool searchRowFits(BuildContext context, double width, double needed) =>
    width >=
    needed *
        (MediaQuery.textScalerOf(context).scale(16) / 16)
            .clamp(1.0, double.infinity);

/// The main search action on Flights, Hotels and Attractions (DECISIONS 047):
/// a sky blue rounded box with a soft blue shadow, Outfit extra bold, at
/// least as tall as a [SearchField] so it lines up with the fields.
class SearchButton extends StatelessWidget {
  static const _radius = 18.0;
  // rgba(110, 160, 220, .4), the mock's shadow.
  static const _shadow = Color(0x666EA0DC);
  final String label;
  final VoidCallback? onPressed;
  const SearchButton({super.key, required this.label, required this.onPressed});
  @override
  Widget build(BuildContext context) => DecoratedBox(
      decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(_radius),
          boxShadow: [
            if (onPressed != null)
              const BoxShadow(
                  color: _shadow, blurRadius: 10, offset: Offset(0, 3))
          ]),
      child: ElevatedButton.icon(
          onPressed: onPressed,
          icon: const Icon(Icons.search_rounded, size: 20),
          label: Text(label),
          style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.cta,
                  foregroundColor: AppTheme.ctaInk,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                  minimumSize: const Size(0, 66),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(_radius)),
                  textStyle: AppTheme.buttonText(size: 16))
              .copyWith(
                  side: AppTheme.focusOutline(),
                  // The DecoratedBox draws this button's shadow.
                  elevation: const WidgetStatePropertyAll(0))));
}

/// A labelled field box that glows on hover and highlights while focused.
class SearchField extends StatefulWidget {
  final String label;
  final Widget child;
  final VoidCallback? onTap;
  const SearchField(
      {super.key, required this.label, required this.child, this.onTap});
  @override
  State<SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<SearchField> {
  bool _hover = false, _focus = false;
  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    final tone = PageTone.of(context);
    final radius = BorderRadius.circular(16);
    final body = Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.label,
                  style: TextStyle(
                      color: tone.deep,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              // The white box itself is the field, so the text field inside
              // drops the theme's own border and fill.
              Theme(
                  data: Theme.of(context).copyWith(
                      inputDecorationTheme: Theme.of(context)
                          .inputDecorationTheme
                          .copyWith(
                              filled: false,
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none)),
                  child: widget.child),
            ]));
    return MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: Focus(
            canRequestFocus: false,
            skipTraversal: true,
            onFocusChange: (value) => setState(() => _focus = value),
            child: AnimatedContainer(
                duration: reduced ? Duration.zero : AppTheme.motionFast,
                constraints: const BoxConstraints(minHeight: 66),
                // A white field on the page-coloured search card; the outline
                // keeps 3:1 on white and deepens on hover and focus.
                decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: radius,
                    border: Border.all(
                        color: _focus || _hover ? tone.deep : tone.field,
                        width: _focus ? 2 : 1.5),
                    boxShadow: [
                      if (_focus)
                        BoxShadow(
                            color: tone.deep.withValues(alpha: .18),
                            spreadRadius: 4)
                    ]),
                child: widget.onTap == null
                    ? body
                    : Material(
                        type: MaterialType.transparency,
                        child: InkWell(
                            borderRadius: radius,
                            onTap: widget.onTap,
                            child: body)))));
  }
}

/// Numbered hints on how to use a page, in the page's colour. Outside a
/// [PageTone] (the planned itinerary) each step keeps its own soft tint.
class HowToSteps extends StatelessWidget {
  /// Sky blue, lemon and sand: the search pages' step colours.
  static const searchTints = [
    AppTheme.ctaSoft,
    AppTheme.lemonTint,
    AppTheme.sorbet
  ];
  final List<(String, String)> steps;
  final List<Color> tints;
  const HowToSteps({super.key, required this.steps, this.tints = searchTints});
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
        final tone = PageTone.maybeOf(context);
        final columns = box.maxWidth >= 760 ? steps.length : 1;
        final width = (box.maxWidth - (columns - 1) * 14) / columns;
        return Wrap(spacing: 14, runSpacing: 14, children: [
          for (var i = 0; i < steps.length; i++)
            SizedBox(
                width: width,
                child: GentleReveal(
                    delay: Duration(milliseconds: 80 * i),
                    child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                            color: tone?.tint ?? tints[i % tints.length],
                            borderRadius: BorderRadius.circular(18)),
                        child: Row(children: [
                          Container(
                              width: 32,
                              height: 32,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                  color: tone?.deep ?? AppTheme.sand,
                                  shape: BoxShape.circle),
                              child: Text('${i + 1}',
                                  style: TextStyle(
                                      color: tone == null
                                          ? AppTheme.sandInk
                                          : Colors.white,
                                      fontWeight: FontWeight.w700))),
                          const SizedBox(width: 12),
                          Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                Text(steps[i].$1,
                                    style: TextStyle(
                                        color:
                                            tone?.ink ?? AppTheme.textPrimary,
                                        fontSize: 15.5,
                                        fontWeight: FontWeight.w700)),
                                Text(steps[i].$2,
                                    style: TextStyle(
                                        color: tone?.body ??
                                            AppTheme.textSecondary,
                                        fontSize: 14,
                                        height: 1.4)),
                              ])),
                        ])))),
        ]);
      });
}

/// Pill-shaped picks with a small photo of each place.
class CityChips extends StatelessWidget {
  final List<String> cities;
  final String selected;
  final ValueChanged<String> onPick;
  const CityChips(
      {super.key,
      required this.cities,
      required this.selected,
      required this.onPick});
  @override
  Widget build(BuildContext context) => Wrap(
          spacing: 10,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const Text('Popular:',
                style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700)),
            for (final city in cities)
              _CityChip(
                  city: city,
                  selected: city.toLowerCase() == selected.trim().toLowerCase(),
                  onTap: () => onPick(city)),
          ]);
}

class _CityChip extends StatelessWidget {
  final String city;
  final bool selected;
  final VoidCallback onTap;
  const _CityChip(
      {required this.city, required this.selected, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final photo = DiscoverContent.photoForPlace(city);
    return Semantics(
        selected: selected,
        child: HoverLift(
            child: FocusRing(
          borderRadius: BorderRadius.circular(999),
          child: Material(
            color: selected ? AppTheme.skyBlue : AppTheme.surface,
            shape: StadiumBorder(
                side: BorderSide(
                    color: selected ? _chipSelected : AppTheme.border,
                    width: 1.5)),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
                onTap: onTap,
                child: Padding(
                    padding: const EdgeInsets.fromLTRB(6, 6, 16, 6),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      CircleAvatar(
                          radius: 15,
                          backgroundColor: AppTheme.skyBlue,
                          backgroundImage:
                              photo == null ? null : AssetImage(photo.asset),
                          child: photo == null
                              ? Text(city[0],
                                  style: const TextStyle(
                                      color: AppTheme.textPrimary,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700))
                              : null),
                      const SizedBox(width: 8),
                      Text(city,
                          style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w600)),
                    ]))),
          ),
        )));
  }
}

/// A short photo strip that titles a list of results.
class ResultsBanner extends StatelessWidget {
  final DiscoverPhoto? photo;
  final Alignment photoAlignment;
  final String title, subtitle;
  const ResultsBanner(
      {super.key,
      required this.photo,
      required this.title,
      required this.subtitle,
      this.photoAlignment = Alignment.center});
  @override
  Widget build(BuildContext context) => LayoutBuilder(
      builder: (context, box) => ClipRRect(
          borderRadius: BorderRadius.circular(24),
          // At least 150 px tall, growing with large text (KI-28); the photo
          // and its shade fill whatever height the words need.
          child: Stack(children: [
            if (photo != null) ...[
              Positioned.fill(
                  child: BannerImage(photo!,
                      alignment: photoAlignment,
                      fallback: const DecoratedBox(
                          decoration: BoxDecoration(
                              gradient: LinearGradient(colors: [
                        AppTheme.primaryDark,
                        AppTheme.primaryLight
                      ]))))),
              const Positioned.fill(
                  child: DecoratedBox(
                      decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [
                Color(0xC7141C24),
                Color(0x59141C24),
                Color(0x1A141C24)
              ], stops: [
                0,
                .6,
                1
              ])))),
            ] else
              const Positioned.fill(
                  child: DecoratedBox(
                      decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [
                AppTheme.primaryDark,
                AppTheme.primaryLight
              ])))),
            Container(
                width: double.infinity,
                constraints: const BoxConstraints(minHeight: 150),
                alignment: Alignment.centerLeft,
                padding: EdgeInsets.symmetric(
                    horizontal: box.maxWidth >= 600 ? 32 : 20, vertical: 18),
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: tripHeading.copyWith(
                              color: Colors.white,
                              fontSize: box.maxWidth >= 600 ? 26 : 20,
                              height: 1.2)),
                      const SizedBox(height: 4),
                      Text(subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: .9),
                              fontSize: 15)),
                    ])),
          ])));
}

/// Plain facts about where results come from and what they leave out.
class InfoChips extends StatelessWidget {
  final List<String> notes;
  const InfoChips({super.key, required this.notes});
  @override
  Widget build(BuildContext context) =>
      Wrap(spacing: 10, runSpacing: 10, children: [
        for (final note in notes)
          Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: AppTheme.border)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.info_outline_rounded,
                    size: 16, color: AppTheme.primary),
                const SizedBox(width: 6),
                Flexible(
                    child: Text(note,
                        style: const TextStyle(
                            color: AppTheme.textSecondary, fontSize: 13.5))),
              ])),
      ]);
}

/// A white card that lifts on hover; [builder] learns when it is active so
/// small details (a plane, a pin, an icon) can move too.
class HoverCard extends StatefulWidget {
  final Widget Function(bool active) builder;
  const HoverCard({super.key, required this.builder});
  @override
  State<HoverCard> createState() => _HoverCardState();
}

class _HoverCardState extends State<HoverCard> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    final active = _hover && !reduced;
    final radius = BorderRadius.circular(22);
    return MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: AnimatedContainer(
            duration:
                reduced ? Duration.zero : const Duration(milliseconds: 350),
            curve: AppTheme.motionCurve,
            transform: Matrix4.translationValues(0, active ? -5 : 0, 0),
            decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: radius,
                border: Border.all(color: Colors.black.withValues(alpha: .05)),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: active ? .1 : .03),
                      blurRadius: active ? 40 : 10,
                      offset: Offset(0, active ? 20 : 2))
                ]),
            child: widget.builder(active)));
  }
}

/// Gives [MapAction]'s text button the soft pill look used on result cards.
class PillButtonTheme extends StatelessWidget {
  final Widget child;
  const PillButtonTheme({super.key, required this.child});
  @override
  Widget build(BuildContext context) => TextButtonTheme(
      data: TextButtonThemeData(
          style: TextButton.styleFrom(
                  backgroundColor: AppTheme.skyBlue,
                  foregroundColor: AppTheme.textPrimary,
                  shadowColor: AppTheme.ctaShadow,
                  shape: const StadiumBorder(),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  textStyle:
                      AppTheme.buttonText(size: 14, weight: FontWeight.w700))
              .copyWith(
                  side: AppTheme.focusOutline(),
                  elevation: AppTheme.solidElevation(rest: 1.5, hover: 4))),
      child: child);
}

/// Invites the traveller back to Lemon once they have found something.
class LemonPromptBand extends StatelessWidget {
  final String title, text, action;
  final VoidCallback onPressed;
  const LemonPromptBand(
      {super.key,
      required this.title,
      required this.text,
      required this.action,
      required this.onPressed});
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
        final wide = box.maxWidth >= 700;
        final copy = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontFamily: AppTheme.noteFont,
                      color: AppTheme.sandInk,
                      fontSize: 19,
                      height: 1.3,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(text,
                  style: const TextStyle(
                      color: AppTheme.sorbetInk, fontSize: 15.5)),
            ]);
        final button = HoverLift(
            child: ElevatedButton(
                onPressed: onPressed,
                style: planWithLemonStyle(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 16)),
                child: Text(action)));
        return Container(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            decoration: BoxDecoration(
                color: AppTheme.sorbet,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppTheme.sandBorder)),
            child: wide
                ? Row(children: [
                    const LemonCircle(
                        size: 64,
                        background: AppTheme.surface,
                        ring: AppTheme.accentLemon),
                    const SizedBox(width: 20),
                    Expanded(child: copy),
                    const SizedBox(width: 20),
                    button,
                  ])
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                        const LemonCircle(
                            size: 64,
                            background: AppTheme.surface,
                            ring: AppTheme.accentLemon),
                        const SizedBox(height: 14),
                        copy,
                        const SizedBox(height: 16),
                        button,
                      ]));
      });
}

/// Warm sand "Plan with Lemon" buttons (DECISIONS 044); every other main
/// action keeps the theme's sky blue.
ButtonStyle planWithLemonStyle({EdgeInsetsGeometry? padding}) =>
    ElevatedButton.styleFrom(
            backgroundColor: AppTheme.planButton,
            foregroundColor: AppTheme.sandInk,
            shadowColor: AppTheme.sandDeep.withValues(alpha: .55),
            padding: padding,
            textStyle: AppTheme.buttonText(size: 16))
        .copyWith(
            side: AppTheme.focusOutline(
                const BorderSide(color: AppTheme.planButtonBorder, width: 1.5)),
            elevation: AppTheme.solidElevation());

/// Credits for the photos a page shows.
class PhotoCredits extends StatelessWidget {
  final List<DiscoverPhoto?> photos;
  const PhotoCredits({super.key, required this.photos});
  @override
  Widget build(BuildContext context) {
    final bySource = <String, Set<String>>{};
    for (final photo in photos) {
      if (photo != null && photo.credit.isNotEmpty) {
        bySource.putIfAbsent(photo.source, () => {}).add(photo.credit);
      }
    }
    if (bySource.isEmpty) return const SizedBox.shrink();
    return Text(
        [
          for (final MapEntry(key: source, value: credits) in bySource.entries)
            'Photos ($source): ${credits.join(' · ')}'
        ].join('  ·  '),
        style: const TextStyle(
            color: AppTheme.textSecondary, fontSize: 12.5, height: 1.6));
  }
}

/// A cover-fit banner photo, bundled or from the network. A network photo
/// that fails to load shows [fallback] (the plain background by default).
class BannerImage extends StatelessWidget {
  final DiscoverPhoto photo;
  final Alignment alignment;
  final Widget fallback;
  const BannerImage(this.photo,
      {super.key,
      this.alignment = Alignment.center,
      this.fallback = const SizedBox.shrink()});
  @override
  Widget build(BuildContext context) => Image(
      image: photo.image,
      fit: BoxFit.cover,
      alignment: alignment,
      width: double.infinity,
      height: double.infinity,
      semanticLabel: photo.description,
      // Network photos fade in rather than popping over the plain banner.
      frameBuilder: (context, child, frame, sync) => sync
          ? child
          : AnimatedOpacity(
              opacity: frame == null ? 0 : 1,
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 500),
              child: child),
      errorBuilder: (_, __, ___) => fallback);
}

/// Lays out [children] in up to [maxColumns] equal columns.
class ResponsiveGrid extends StatelessWidget {
  final List<Widget> children;
  final int maxColumns;
  const ResponsiveGrid(
      {super.key, required this.children, this.maxColumns = 3});
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
        final fits = box.maxWidth >= 1000
            ? 3
            : box.maxWidth >= 640
                ? 2
                : 1;
        final columns = fits < maxColumns ? fits : maxColumns;
        final width = (box.maxWidth - (columns - 1) * 16) / columns;
        return Wrap(spacing: 16, runSpacing: 16, children: [
          for (var i = 0; i < children.length; i++)
            SizedBox(
                width: width,
                child: GentleReveal(
                    delay: Duration(milliseconds: 60 * (i < 8 ? i : 8)),
                    child: children[i])),
        ]);
      });
}
