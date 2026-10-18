import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../config/app_theme.dart';
import '../../config/discover_content.dart';
import '../../widgets/gentle_reveal.dart';
import '../../widgets/hover_lift.dart';
import '../../widgets/lemon_motion.dart';
import '../../widgets/page_parts.dart';
import '../../models/itinerary_models.dart';

const _lemonArt = 'assets/images/lemon_avatar.png';

class DiscoverView extends StatelessWidget {
  final VoidCallback onOpenLemon;
  final ValueChanged<int> onSelectTab;
  final ValueChanged<String>? onDestination;
  final ItineraryResponse? activeItinerary;
  const DiscoverView(
      {super.key,
      required this.onOpenLemon,
      required this.onSelectTab,
      this.onDestination,
      this.activeItinerary});
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 120),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1320),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _Hero(onOpenLemon: onOpenLemon, onExplore: () => onSelectTab(3)),
              if (activeItinerary != null) ...[
                const SizedBox(height: 24),
                Card(
                    child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Wrap(
                            spacing: 24,
                            runSpacing: 12,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              const Icon(Icons.map_outlined,
                                  color: AppTheme.teal),
                              Text(
                                  '${activeItinerary!.destination} · ${activeItinerary!.days.length} day${activeItinerary!.days.length == 1 ? '' : 's'}',
                                  style: const TextStyle(
                                      fontFamily: AppTheme.tripHeadingFont,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700)),
                              if (activeItinerary!.providerUsed == 'mock')
                                const Chip(label: Text('Demo itinerary')),
                              TextButton(
                                  onPressed: () => onSelectTab(4),
                                  child: const Text('Continue your trip →')),
                            ])))
              ],
              const SizedBox(height: 72),
              const _SectionHeading(
                  eyebrow: 'How Lemon plans',
                  title: 'Three answers away from a full plan',
                  note:
                      "Everything happens inside Lemon's chat. No forms, no tabs to juggle."),
              const SizedBox(height: 28),
              const _HowItWorks(),
              const SizedBox(height: 72),
              const _SectionHeading(
                  eyebrow: 'Explore on your own',
                  title: 'Everything for your next escape'),
              const SizedBox(height: 28),
              _ExploreCards(onSelectTab: onSelectTab),
              const SizedBox(height: 72),
              const _SectionHeading(
                  eyebrow: 'Need a spark?',
                  title: 'Where will curiosity take you?',
                  note:
                      'Tap a place and Lemon starts planning with it already filled in.'),
              const SizedBox(height: 28),
              _Destinations(onDestination: onDestination),
              const SizedBox(height: 72),
              _ReadyBand(onOpenLemon: onOpenLemon),
              const SizedBox(height: 40),
              const _Credits(),
            ]),
          ),
        ),
      );
}

/// Columns for a responsive card row, and the width each card receives.
(int, double) _grid(double width, {int max = 3, double gap = 20}) {
  final columns = width > 1000
      ? max
      : width > 560
          ? (max > 2 ? 2 : max)
          : 1;
  return (columns, (width - (columns - 1) * gap) / columns);
}

class _Hero extends StatelessWidget {
  final VoidCallback onOpenLemon;
  final VoidCallback onExplore;
  const _Hero({required this.onOpenLemon, required this.onExplore});

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
        final wide = box.maxWidth > 900;
        final title = TextStyle(
            fontFamily: AppTheme.tripHeadingFont,
            color: AppTheme.textPrimary,
            fontSize: (box.maxWidth / 24).clamp(28.0, 54.0),
            height: 1.12,
            letterSpacing: -1.6,
            fontWeight: FontWeight.w700);
        final copy = Padding(
          padding: EdgeInsets.fromLTRB(
              wide ? 52 : 24, wide ? 52 : 28, 24, wide ? 52 : 12),
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const GentleReveal(
                    child: Text('YOUR AI TRAVEL COMPANION',
                        style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 13,
                            letterSpacing: 1.4,
                            fontWeight: FontWeight.w700))),
                const SizedBox(height: 16),
                GentleReveal(
                    delay: const Duration(milliseconds: 80),
                    child: Text('A little curiosity.', style: title)),
                GentleReveal(
                    delay: const Duration(milliseconds: 160),
                    child: Text.rich(
                        TextSpan(text: 'A whole new ', children: [
                          WidgetSpan(
                              alignment: PlaceholderAlignment.baseline,
                              baseline: TextBaseline.alphabetic,
                              child: _Highlight('adventure.', style: title)),
                        ]),
                        style: title)),
                const SizedBox(height: 20),
                GentleReveal(
                    delay: const Duration(milliseconds: 240),
                    child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 520),
                        child: const Text(
                            "Tell Lemon where you're dreaming of. She'll ask a few quick questions, then build a day-by-day plan around you.",
                            style: TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 18,
                                height: 1.6)))),
                const SizedBox(height: 28),
                GentleReveal(
                    delay: const Duration(milliseconds: 320),
                    child: Wrap(spacing: 12, runSpacing: 12, children: [
                      HoverLift(
                          child: ElevatedButton.icon(
                              onPressed: onOpenLemon,
                              style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 26, vertical: 18),
                                  textStyle: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700)),
                              icon: const Icon(Icons.auto_awesome, size: 19),
                              label: const Text('Plan a trip with Lemon'))),
                      HoverLift(
                          child: OutlinedButton.icon(
                              onPressed: onExplore,
                              iconAlignment: IconAlignment.end,
                              style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 24, vertical: 18),
                                  textStyle: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700)),
                              icon: const Icon(Icons.arrow_forward, size: 18),
                              label: const Text('Explore places'))),
                    ])),
                const SizedBox(height: 30),
                GentleReveal(
                    delay: const Duration(milliseconds: 400),
                    child: Wrap(spacing: 18, runSpacing: 8, children: [
                      for (final step in const [
                        'Pick your somewhere',
                        'Add a little of you',
                        'Lemon connects the dots'
                      ])
                        Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.check_rounded,
                              size: 18, color: Color(0xFFC9A21A)),
                          const SizedBox(width: 6),
                          Flexible(
                              child: Text(step,
                                  style: const TextStyle(
                                      color: AppTheme.textSecondary,
                                      fontSize: 14))),
                        ]),
                    ])),
              ]),
        );
        return ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: Stack(children: [
            Positioned.fill(
                child: SlowZoom(
                    child: Image.asset(DiscoverContent.hero.asset,
                        fit: BoxFit.cover,
                        alignment: const Alignment(.4, 0),
                        semanticLabel: DiscoverContent.hero.description))),
            Positioned.fill(
                child: DecoratedBox(
                    decoration: BoxDecoration(
                        gradient: wide
                            ? LinearGradient(colors: [
                                AppTheme.background.withValues(alpha: .97),
                                AppTheme.background.withValues(alpha: .9),
                                AppTheme.background.withValues(alpha: .25),
                                AppTheme.background.withValues(alpha: 0),
                              ], stops: const [
                                0,
                                .38,
                                .66,
                                1
                              ])
                            : LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                    AppTheme.background.withValues(alpha: .95),
                                    AppTheme.background.withValues(alpha: .7),
                                  ])))),
            if (wide)
              Padding(
                  padding: const EdgeInsets.only(right: 48),
                  child: Row(children: [
                    Expanded(child: copy),
                    const SizedBox(width: 32),
                    const _LemonShowcase(halo: 340),
                  ]))
            else
              Column(children: [
                copy,
                const _LemonShowcase(halo: 190, withBubble: false),
              ]),
          ]),
        );
      });
}

/// A lemon highlighter stroke behind part of the headline.
class _Highlight extends StatelessWidget {
  final String text;
  final TextStyle style;
  const _Highlight(this.text, {required this.style});
  @override
  Widget build(BuildContext context) {
    final size = style.fontSize ?? 40;
    return Stack(clipBehavior: Clip.none, children: [
      Positioned(
          left: -2,
          right: -2,
          bottom: size * .1,
          height: size * .36,
          child: const ColoredBox(color: AppTheme.accentLemon)),
      Text(text, style: style),
    ]);
  }
}

/// Lemon on her yellow halo, floating, with a greeting bubble.
class _LemonShowcase extends StatelessWidget {
  final double halo;
  final bool withBubble;
  const _LemonShowcase({required this.halo, this.withBubble = true});
  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    final bubble = Container(
      constraints: const BoxConstraints(maxWidth: 240),
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
      decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: const BorderRadius.only(
              // The sharp corner points down-right, at Lemon.
              topLeft: Radius.circular(22),
              topRight: Radius.circular(22),
              bottomLeft: Radius.circular(22),
              bottomRight: Radius.circular(6)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: .12),
                blurRadius: 32,
                offset: const Offset(0, 14))
          ]),
      child: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Hi, I'm Lemon!",
                style: TextStyle(
                    fontFamily: AppTheme.noteFont,
                    color: AppTheme.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w600)),
            SizedBox(height: 4),
            Text("Where should we go first? I'll take care of the plan.",
                style: TextStyle(
                    fontFamily: AppTheme.noteFont,
                    color: AppTheme.textSecondary,
                    fontSize: 15.5,
                    height: 1.45,
                    fontWeight: FontWeight.w500)),
          ]),
    );
    return SizedBox(
      width: halo + 70,
      height: halo * (withBubble ? 1.6 : 1.45),
      child: Stack(
          alignment: Alignment.bottomCenter,
          clipBehavior: Clip.none,
          children: [
            Positioned(
                bottom: halo * .1,
                child: PulseRing(size: halo, color: AppTheme.surface)),
            Positioned(
                bottom: halo * .1,
                child: Container(
                    width: halo,
                    height: halo,
                    decoration: BoxDecoration(
                        color: AppTheme.accentLemon,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                              color: AppTheme.surface.withValues(alpha: .75),
                              spreadRadius: 12)
                        ]))),
            Positioned(
                bottom: 0,
                child: LemonFloat(
                    child: Image.asset(_lemonArt,
                        width: halo * 1.05,
                        filterQuality: FilterQuality.high,
                        semanticLabel: 'Lemon, your travel planner'))),
            if (withBubble)
              // Inset from the hero's top edge so the bubble never touches it.
              Positioned(
                  top: 32,
                  left: 0,
                  child: reduced
                      ? bubble
                      : bubble
                          .animate(delay: const Duration(milliseconds: 900))
                          .fadeIn(duration: AppTheme.motionEntrance)
                          .scale(
                              begin: const Offset(.9, .9),
                              duration: AppTheme.motionEntrance,
                              curve: Curves.easeOutBack)),
          ]),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String? note;
  const _SectionHeading(
      {required this.eyebrow, required this.title, this.note});
  @override
  Widget build(BuildContext context) => Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.end,
          spacing: 24,
          runSpacing: 12,
          children: [
            Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(eyebrow.toUpperCase(),
                      style: const TextStyle(
                          color: AppTheme.primary,
                          fontSize: 13,
                          letterSpacing: 1.3,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Text(title,
                      style: const TextStyle(
                          fontFamily: AppTheme.tripHeadingFont,
                          color: AppTheme.textPrimary,
                          fontSize: 28,
                          height: 1.2,
                          letterSpacing: -.8,
                          fontWeight: FontWeight.w700)),
                ]),
            if (note != null)
              ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 380),
                  child: Text(note!,
                      style: const TextStyle(
                          color: AppTheme.textSecondary, height: 1.55))),
          ]);
}

/// Lifts and deepens its shadow on hover or keyboard focus.
class _HoverCard extends StatefulWidget {
  final Widget Function(bool active) builder;
  final VoidCallback? onTap;
  final String? semanticLabel;
  final double radius;
  final double lift;
  const _HoverCard(
      {required this.builder,
      this.onTap,
      this.semanticLabel,
      this.radius = 26,
      this.lift = 6});
  @override
  State<_HoverCard> createState() => _HoverCardState();
}

class _HoverCardState extends State<_HoverCard> {
  bool _hover = false, _focus = false;
  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    final active = _hover || _focus;
    final radius = BorderRadius.circular(widget.radius);
    return Semantics(
      label: widget.semanticLabel,
      button: widget.onTap != null,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: AnimatedContainer(
          duration: reduced ? Duration.zero : const Duration(milliseconds: 350),
          curve: AppTheme.motionCurve,
          transform: Matrix4.translationValues(
              0, active && !reduced ? -widget.lift : 0, 0),
          decoration: BoxDecoration(borderRadius: radius, boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: active ? .12 : .04),
                blurRadius: active ? 40 : 10,
                offset: Offset(0, active ? 18 : 2))
          ]),
          child: Material(
            color: AppTheme.surface,
            borderRadius: radius,
            clipBehavior: Clip.antiAlias,
            child: InkWell(
                onTap: widget.onTap,
                onFocusChange: (value) => setState(() => _focus = value),
                child: widget.builder(active && !reduced)),
          ),
        ),
      ),
    );
  }
}

/// A photo that eases into a slight zoom while its card is active.
class _ZoomPhoto extends StatelessWidget {
  final DiscoverPhoto photo;
  final bool active;
  final Alignment alignment;
  const _ZoomPhoto(this.photo,
      {required this.active, this.alignment = Alignment.center});
  @override
  Widget build(BuildContext context) => AnimatedScale(
      scale: active ? 1.07 : 1,
      duration: const Duration(milliseconds: 800),
      curve: AppTheme.motionCurve,
      child: Image.asset(photo.asset,
          fit: BoxFit.cover,
          alignment: alignment,
          width: double.infinity,
          height: double.infinity,
          semanticLabel: photo.description));
}

class _HowItWorks extends StatelessWidget {
  const _HowItWorks();
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
        final (_, width) = _grid(box.maxWidth);
        return Wrap(spacing: 20, runSpacing: 20, children: [
          for (final step in const [
            (
              '01',
              Icons.place_outlined,
              'Tell her where',
              "Type a city or country, or tap one of Lemon's suggestions."
            ),
            (
              '02',
              Icons.calendar_month_outlined,
              'Add when, who and what you love',
              'Dates, travelers, budget and interests, picked with quick taps.'
            ),
            (
              '03',
              null,
              'Lemon builds your days',
              'Confirm, and she writes a day-by-day itinerary using weather and nearby sights.'
            ),
          ])
            SizedBox(
                width: width,
                child: GentleReveal(
                    child: _HoverCard(
                        radius: 24,
                        lift: 4,
                        builder: (_) => Container(
                            padding: const EdgeInsets.all(28),
                            decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                    color:
                                        Colors.black.withValues(alpha: .06))),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(children: [
                                    step.$2 == null
                                        ? ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(16),
                                            child: Container(
                                                width: 52,
                                                height: 52,
                                                // Matches the white card.
                                                decoration: BoxDecoration(
                                                    color: AppTheme.surface,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            16),
                                                    border: Border.all(
                                                        color: AppTheme.skyMint,
                                                        width: 1.5)),
                                                child: Image.asset(_lemonArt,
                                                    fit: BoxFit.cover,
                                                    alignment: const Alignment(
                                                        .2, -.85),
                                                    excludeFromSemantics:
                                                        true)))
                                        : Container(
                                            width: 52,
                                            height: 52,
                                            decoration: BoxDecoration(
                                                color: AppTheme.skyMint,
                                                borderRadius:
                                                    BorderRadius.circular(16)),
                                            child: Icon(step.$2,
                                                color: AppTheme.textPrimary)),
                                    const Spacer(),
                                    Text(step.$1,
                                        style: const TextStyle(
                                            fontFamily:
                                                AppTheme.tripHeadingFont,
                                            fontSize: 36,
                                            height: 1,
                                            fontWeight: FontWeight.w800,
                                            color: Color(0xFFEEE8DA))),
                                  ]),
                                  const SizedBox(height: 22),
                                  Text(step.$3,
                                      style: const TextStyle(
                                          fontFamily: AppTheme.tripHeadingFont,
                                          color: AppTheme.textPrimary,
                                          fontSize: 17,
                                          fontWeight: FontWeight.w700)),
                                  const SizedBox(height: 8),
                                  Text(step.$4,
                                      style: const TextStyle(
                                          color: AppTheme.textSecondary,
                                          height: 1.55)),
                                ]))))),
        ]);
      });
}

class _ExploreCards extends StatelessWidget {
  final ValueChanged<int> onSelectTab;
  const _ExploreCards({required this.onSelectTab});
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
        final (_, width) = _grid(box.maxWidth, gap: 24);
        return Wrap(spacing: 24, runSpacing: 24, children: [
          for (final item in const [
            (
              1,
              Icons.flight_takeoff,
              'Find your flight',
              'Compare routes, schedules and available offers.',
              'Search flights',
              DiscoverContent.flights
            ),
            (
              2,
              Icons.hotel_outlined,
              'Find a place to stay',
              'Browse hotel locations around your destination.',
              'Browse stays',
              DiscoverContent.stays
            ),
            (
              3,
              Icons.explore_outlined,
              'Follow your curiosity',
              'Find local sights and places worth exploring.',
              'See attractions',
              DiscoverContent.sights
            ),
          ])
            SizedBox(
                width: width,
                child: GentleReveal(
                    child: _HoverCard(
                        onTap: () => onSelectTab(item.$1),
                        builder: (active) => Stack(children: [
                              Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    SizedBox(
                                        height: 200,
                                        child: ClipRect(
                                            child: _ZoomPhoto(item.$6,
                                                active: active,
                                                alignment:
                                                    const Alignment(0, .1)))),
                                    Padding(
                                        padding: const EdgeInsets.fromLTRB(
                                            26, 40, 26, 26),
                                        child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(item.$3,
                                                  style: const TextStyle(
                                                      fontFamily: AppTheme
                                                          .tripHeadingFont,
                                                      color:
                                                          AppTheme.textPrimary,
                                                      fontSize: 17,
                                                      fontWeight:
                                                          FontWeight.w700)),
                                              const SizedBox(height: 8),
                                              Text(item.$4,
                                                  style: const TextStyle(
                                                      color: AppTheme
                                                          .textSecondary,
                                                      height: 1.5)),
                                              const SizedBox(height: 18),
                                              Row(children: [
                                                Text(item.$5,
                                                    style: const TextStyle(
                                                        color: AppTheme.primary,
                                                        fontWeight:
                                                            FontWeight.w700)),
                                                const SizedBox(width: 8),
                                                AnimatedSlide(
                                                    offset: active
                                                        ? const Offset(.3, 0)
                                                        : Offset.zero,
                                                    duration:
                                                        AppTheme.motionStandard,
                                                    curve: AppTheme.motionCurve,
                                                    child: const Icon(
                                                        Icons.arrow_forward,
                                                        size: 18,
                                                        color:
                                                            AppTheme.primary)),
                                              ]),
                                            ])),
                                  ]),
                              Positioned(
                                  top: 172,
                                  left: 24,
                                  child: Container(
                                      width: 56,
                                      height: 56,
                                      decoration: BoxDecoration(
                                          color: AppTheme.surface,
                                          borderRadius:
                                              BorderRadius.circular(18),
                                          boxShadow: [
                                            BoxShadow(
                                                color: Colors.black
                                                    .withValues(alpha: .12),
                                                blurRadius: 18,
                                                offset: const Offset(0, 8))
                                          ]),
                                      child: Icon(item.$2,
                                          color: AppTheme.primary))),
                            ])))),
        ]);
      });
}

class _Destinations extends StatelessWidget {
  final ValueChanged<String>? onDestination;
  const _Destinations({required this.onDestination});
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
        final (_, width) = _grid(box.maxWidth, max: 4);
        return Wrap(spacing: 20, runSpacing: 20, children: [
          for (final place in DiscoverContent.destinations)
            SizedBox(
                width: width,
                height: 340,
                child: GentleReveal(
                    child: _HoverCard(
                        onTap: () => onDestination?.call(place.name),
                        semanticLabel:
                            'Plan a trip to ${place.name} with Lemon',
                        builder: (active) =>
                            Stack(fit: StackFit.expand, children: [
                              _ZoomPhoto(place.photo, active: active),
                              DecoratedBox(
                                  decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          stops: const [
                                    .4,
                                    1
                                  ],
                                          colors: [
                                    Colors.black.withValues(alpha: 0),
                                    const Color(0xFF0F141E)
                                        .withValues(alpha: .74),
                                  ]))),
                              Positioned(
                                  top: 16,
                                  left: 16,
                                  child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                          color: AppTheme.surface
                                              .withValues(alpha: .92),
                                          borderRadius:
                                              BorderRadius.circular(999)),
                                      child: Text(place.country,
                                          style: const TextStyle(
                                              color: AppTheme.textPrimary,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700)))),
                              Positioned(
                                  left: 22,
                                  right: 22,
                                  bottom: 22,
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(place.name,
                                            style: const TextStyle(
                                                fontFamily:
                                                    AppTheme.tripHeadingFont,
                                                color: Colors.white,
                                                fontSize: 22,
                                                fontWeight: FontWeight.w700)),
                                        Text(place.tagline,
                                            style: TextStyle(
                                                color: Colors.white
                                                    .withValues(alpha: .9))),
                                        const SizedBox(height: 12),
                                        AnimatedOpacity(
                                            opacity: active ? 1 : 0,
                                            duration: AppTheme.motionStandard,
                                            child: AnimatedSlide(
                                                offset: active
                                                    ? Offset.zero
                                                    : const Offset(0, .3),
                                                duration:
                                                    AppTheme.motionStandard,
                                                curve: AppTheme.motionCurve,
                                                child: Container(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        horizontal: 16,
                                                        vertical: 10),
                                                    decoration: BoxDecoration(
                                                        color: AppTheme
                                                            .accentLemon,
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(999)),
                                                    child: const Row(
                                                        mainAxisSize:
                                                            MainAxisSize.min,
                                                        children: [
                                                          Text(
                                                              'Plan with Lemon',
                                                              style: TextStyle(
                                                                  color: AppTheme
                                                                      .lemonInk,
                                                                  fontSize: 14,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w700)),
                                                          SizedBox(width: 8),
                                                          Icon(
                                                              Icons
                                                                  .arrow_forward,
                                                              size: 16,
                                                              color: AppTheme
                                                                  .lemonInk),
                                                        ])))),
                                      ])),
                            ])))),
        ]);
      });
}

class _ReadyBand extends StatelessWidget {
  final VoidCallback onOpenLemon;
  const _ReadyBand({required this.onOpenLemon});
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
        final wide = box.maxWidth > 700;
        // Lemon takes the band's own colour (only the hero keeps her yellow).
        const avatar = LemonCircle(size: 112, background: AppTheme.sky);
        const copy = Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Ready when you are.',
                  style: TextStyle(
                      fontFamily: AppTheme.tripHeadingFont,
                      color: AppTheme.textPrimary,
                      fontSize: 24,
                      height: 1.2,
                      fontWeight: FontWeight.w700)),
              SizedBox(height: 6),
              Text('Lemon is one tap away, from any page.',
                  style:
                      TextStyle(color: AppTheme.textSecondary, fontSize: 16)),
            ]);
        final button = HoverLift(
            child: ElevatedButton.icon(
                onPressed: onOpenLemon,
                iconAlignment: IconAlignment.end,
                style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 26, vertical: 18),
                    textStyle: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700)),
                icon: const Icon(Icons.arrow_forward, size: 18),
                label: const Text('Start planning')));
        return Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(
              horizontal: wide ? 44 : 24, vertical: wide ? 36 : 28),
          decoration: BoxDecoration(
              color: AppTheme.sky,
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: AppTheme.skyMint)),
          child: wide
              ? Row(children: [
                  avatar,
                  const SizedBox(width: 28),
                  const Expanded(child: copy),
                  const SizedBox(width: 20),
                  button,
                ])
              : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  avatar,
                  const SizedBox(height: 20),
                  copy,
                  const SizedBox(height: 20),
                  button,
                ]),
        );
      });
}

class _Credits extends StatelessWidget {
  const _Credits();
  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Photo credits (Wikimedia Commons)',
            style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(DiscoverContent.credits.join(' · '),
            style: const TextStyle(
                color: AppTheme.textSecondary, fontSize: 12.5, height: 1.6)),
      ]);
}
