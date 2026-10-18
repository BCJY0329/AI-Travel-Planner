import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../config/app_theme.dart';
import '../../config/discover_content.dart';
import '../../models/itinerary_models.dart';
import '../../widgets/gentle_reveal.dart';
import '../../widgets/hover_lift.dart';
import '../../widgets/lemon_motion.dart';
import '../../widgets/page_parts.dart';

// Lemon's tip colours: a warm lemon wash with dark honey text.
const _tipFill = Color(0xFFFFF6CC);
const _tipNoteFill = Color(0xFFFFFBEA);
const _tipBorder = Color(0xFFF5DC7A);
const _tipInk = Color(0xFF5E4500);

/// Each day gets its own soft colour (header tint, accent) so days are easy
/// to tell apart, as in the original itinerary.
const _dayTones = [
  (AppTheme.mint, Color(0xFF9FD9CF)),
  (AppTheme.peach, Color(0xFFFFC9AE)),
  (AppTheme.lemon, AppTheme.accentLemon),
  (Color(0xFFE3EFFB), Color(0xFFB5D3F2)),
];

class ItineraryView extends StatefulWidget {
  final ItineraryResponse? itinerary;
  final VoidCallback onOpenLemon;
  const ItineraryView(
      {super.key, required this.itinerary, required this.onOpenLemon});
  @override
  State<ItineraryView> createState() => _ItineraryViewState();
}

class _ItineraryViewState extends State<ItineraryView> {
  int _day = 0;
  @override
  void didUpdateWidget(covariant ItineraryView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.itinerary, widget.itinerary)) _day = 0;
  }

  String _date(String? value) {
    final date = DateTime.tryParse(value ?? '');
    if (date == null) return value ?? '';
    return MaterialLocalizations.of(context).formatMediumDate(date);
  }

  /// "Nov 12 – Nov 14" from the first and last dated days, if any.
  String? _dateRange(ItineraryResponse trip) {
    final dates = [
      for (final day in trip.days)
        if (DateTime.tryParse(day.date ?? '') case final date?) date
    ];
    if (dates.isEmpty) return null;
    final format = MaterialLocalizations.of(context).formatShortMonthDay;
    final first = format(dates.first), last = format(dates.last);
    return first == last ? first : '$first – $last';
  }

  Future<void> _copy(ItineraryResponse trip) async {
    final text = StringBuffer(
        '${trip.destination} itinerary${trip.providerUsed == 'mock' ? ' (DEMO)' : ''}\n${trip.summary ?? ''}\n');
    for (final day in trip.days) {
      text.writeln('\nDay ${day.day} ${day.date ?? ''}');
      for (final activity in day.activities) {
        text.writeln('${activity.time} ${activity.activity}');
        if (activity.location != null) text.writeln(activity.location);
        if (activity.notes != null) text.writeln(activity.notes);
      }
    }
    try {
      await Clipboard.setData(ClipboardData(text: text.toString()));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Full itinerary copied')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not copy. Please try again.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final trip = widget.itinerary;
    if (trip == null) {
      return Center(
          child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 500),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                        padding: const EdgeInsets.all(24),
                        decoration: const BoxDecoration(
                            color: Color(0xFFE1F1EB), shape: BoxShape.circle),
                        child: const Icon(Icons.route_outlined,
                            color: AppTheme.teal, size: 44)),
                    const SizedBox(height: 24),
                    Text('Your next adventure starts here',
                        textAlign: TextAlign.center,
                        style:
                            tripHeading.copyWith(fontSize: 24, height: 1.25)),
                    const SizedBox(height: 12),
                    const Text(
                        'Tell Lemon where you want to go. Choose your dates and interests, then build a day-by-day plan.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: AppTheme.textSecondary, height: 1.6)),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                        onPressed: widget.onOpenLemon,
                        icon: const Icon(Icons.auto_awesome),
                        label: const Text('Plan with Lemon')),
                  ]))));
    }
    final demo = trip.providerUsed == 'mock';
    final photo = DiscoverContent.photoForPlace(trip.destination);
    return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 120),
        child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1320),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _TripBanner(
                          trip: trip,
                          photo: photo,
                          demo: demo,
                          dateRange: _dateRange(trip),
                          onCopy: () => _copy(trip),
                          onOpenLemon: widget.onOpenLemon),
                      if (demo)
                        Container(
                            margin: const EdgeInsets.only(top: 16),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 18, vertical: 14),
                            decoration: BoxDecoration(
                                color: AppTheme.lemon,
                                borderRadius: BorderRadius.circular(18)),
                            child: const Row(children: [
                              Icon(Icons.info_outline_rounded, color: _tipInk),
                              SizedBox(width: 10),
                              Expanded(
                                  child: Text(
                                      'This is a sample plan, not a personalized itinerary for your dates. Open Lemon to retry generation.',
                                      style: TextStyle(
                                          color: _tipInk,
                                          fontWeight: FontWeight.w600))),
                            ])),
                      if (trip.summary?.isNotEmpty == true)
                        Padding(
                            padding: const EdgeInsets.only(top: 22),
                            child: GentleReveal(
                                child: _Overview(summary: trip.summary!))),
                      const SizedBox(height: 18),
                      HowToSteps(steps: [
                        if (trip.days.length > 1)
                          (
                            'Pick a day to focus',
                            'Or keep All days to see the whole trip.'
                          ),
                        (
                          "Open Lemon's tips",
                          'Little bits of local advice for each stop.'
                        ),
                        (
                          'Copy and share',
                          'Send the whole plan to your travel buddies.'
                        ),
                      ]),
                      const SizedBox(height: 30),
                      if (trip.days.length > 1)
                        Padding(
                            padding: const EdgeInsets.only(bottom: 18),
                            child: Wrap(spacing: 8, runSpacing: 8, children: [
                              ChoiceChip(
                                  label: const Text('All days'),
                                  showCheckmark: false,
                                  selected: _day == 0,
                                  onSelected: (_) => setState(() => _day = 0)),
                              for (final day in trip.days)
                                ChoiceChip(
                                    label: Text('Day ${day.day}'),
                                    showCheckmark: false,
                                    selected: _day == day.day,
                                    onSelected: (_) =>
                                        setState(() => _day = day.day)),
                            ])),
                      LayoutBuilder(builder: (context, box) {
                        final days = trip.days
                            .where((d) => _day == 0 || d.day == _day)
                            .toList();
                        final columns = box.maxWidth >= 1050 &&
                                days.length > 1 &&
                                MediaQuery.textScalerOf(context).scale(16) <= 22
                            ? 2
                            : 1;
                        final width =
                            (box.maxWidth - (columns - 1) * 20) / columns;
                        return Wrap(spacing: 20, runSpacing: 20, children: [
                          for (var i = 0; i < days.length; i++)
                            SizedBox(
                                width: width,
                                child: GentleReveal(
                                    delay: Duration(
                                        milliseconds: 90 * (i < 6 ? i : 6)),
                                    child: _dayCard(days[i]))),
                        ]);
                      }),
                      const SizedBox(height: 28),
                      PhotoCredits(photos: [photo]),
                    ]))));
  }

  Widget _dayCard(ItineraryDay day) {
    final (tint, accent) = _dayTones[(day.day - 1).abs() % _dayTones.length];
    final count = day.activities.length;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.black.withValues(alpha: .05))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          color: tint,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
          child: Row(children: [
            Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                    color: accent, borderRadius: BorderRadius.circular(14)),
                child: Text('${day.day}',
                    style: tripHeading.copyWith(
                        color: AppTheme.lemonInk, fontSize: 17))),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text('Day ${day.day}',
                      style: tripHeading.copyWith(
                          color: AppTheme.textPrimary, fontSize: 17)),
                  if (day.date != null)
                    Text(_date(day.date),
                        style: const TextStyle(
                            color: AppTheme.textSecondary, fontSize: 13.5)),
                ])),
            Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(999)),
                child: Text('$count stop${count == 1 ? '' : 's'}',
                    style: const TextStyle(
                        color: AppTheme.primary,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700))),
          ]),
        ),
        Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (day.activities.isEmpty)
                    const Padding(
                        padding: EdgeInsets.all(22),
                        child: Text('No activities planned for this day.')),
                  for (var i = 0; i < day.activities.length; i++)
                    _Stop(
                        activity: day.activities[i],
                        number: i + 1,
                        tint: tint,
                        accent: accent,
                        last: i == day.activities.length - 1),
                ])),
      ]),
    );
  }
}

/// Photo header with the trip's name, facts and main actions.
class _TripBanner extends StatelessWidget {
  final ItineraryResponse trip;
  final DiscoverPhoto? photo;
  final bool demo;
  final String? dateRange;
  final VoidCallback onCopy, onOpenLemon;
  const _TripBanner(
      {required this.trip,
      required this.photo,
      required this.demo,
      required this.dateRange,
      required this.onCopy,
      required this.onOpenLemon});
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
        final wide = box.maxWidth >= 820;
        final stops =
            trip.days.fold<int>(0, (sum, day) => sum + day.activities.length);
        final days = trip.days.length;
        Widget fact(String text) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .18),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.white.withValues(alpha: .35))),
            child: Text(text,
                style: const TextStyle(color: Colors.white, fontSize: 14)));
        return ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: wide ? 340 : 300),
                child: Stack(alignment: Alignment.bottomLeft, children: [
                  Positioned.fill(
                      child: photo == null
                          ? const DecoratedBox(
                              decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                  AppTheme.primaryLight,
                                  AppTheme.primaryDark
                                ])))
                          : SlowZoom(
                              child: Image.asset(photo!.asset,
                                  fit: BoxFit.cover,
                                  semanticLabel: photo!.description))),
                  const Positioned.fill(
                      child: DecoratedBox(
                          decoration: BoxDecoration(
                              gradient: LinearGradient(
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                  colors: [
                        Color(0xD1141C24),
                        Color(0x59141C24),
                        Color(0x26141C24)
                      ],
                                  stops: [
                        0,
                        .55,
                        1
                      ])))),
                  Padding(
                      padding: EdgeInsets.symmetric(
                          horizontal: wide ? 44 : 22, vertical: wide ? 40 : 26),
                      child: SizedBox(
                          width: double.infinity,
                          child: Wrap(
                              alignment: WrapAlignment.spaceBetween,
                              crossAxisAlignment: WrapCrossAlignment.end,
                              spacing: 20,
                              runSpacing: 20,
                              children: [
                                ConstrainedBox(
                                    constraints:
                                        const BoxConstraints(maxWidth: 680),
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          GentleReveal(
                                              child: Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 12,
                                                      vertical: 5),
                                                  decoration: BoxDecoration(
                                                      color: demo
                                                          ? AppTheme.lemon
                                                          : AppTheme
                                                              .accentLemon,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              999)),
                                                  child: Row(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        Icon(
                                                            demo
                                                                ? Icons
                                                                    .info_outline
                                                                : Icons
                                                                    .auto_awesome,
                                                            size: 15,
                                                            color: AppTheme
                                                                .lemonInk),
                                                        const SizedBox(
                                                            width: 6),
                                                        Text(
                                                            demo
                                                                ? 'Demo itinerary'
                                                                : 'Planned by Lemon',
                                                            style: const TextStyle(
                                                                color: AppTheme
                                                                    .lemonInk,
                                                                fontSize: 13,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w700)),
                                                      ]))),
                                          const SizedBox(height: 12),
                                          GentleReveal(
                                              delay: const Duration(
                                                  milliseconds: 80),
                                              child: Text(
                                                  '${trip.destination} itinerary',
                                                  style: tripHeading.copyWith(
                                                      color: Colors.white,
                                                      fontSize: wide ? 42 : 28,
                                                      height: 1.12,
                                                      letterSpacing: -1))),
                                          const SizedBox(height: 14),
                                          GentleReveal(
                                              delay: const Duration(
                                                  milliseconds: 160),
                                              child: Wrap(
                                                  spacing: 8,
                                                  runSpacing: 8,
                                                  children: [
                                                    fact(
                                                        '$days day${days == 1 ? '' : 's'}'),
                                                    if (dateRange != null)
                                                      fact(dateRange!),
                                                    fact(
                                                        '$stops stop${stops == 1 ? '' : 's'}'),
                                                  ])),
                                        ])),
                                GentleReveal(
                                    delay: const Duration(milliseconds: 240),
                                    child: Wrap(
                                        spacing: 10,
                                        runSpacing: 10,
                                        children: [
                                          HoverLift(
                                              child: OutlinedButton.icon(
                                                  onPressed: onCopy,
                                                  style: OutlinedButton.styleFrom(
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                          horizontal: 20,
                                                          vertical: 16),
                                                      textStyle:
                                                          const TextStyle(
                                                              fontSize: 14,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w700)),
                                                  icon: const Icon(
                                                      Icons.copy_outlined,
                                                      size: 18),
                                                  label: const Text(
                                                      'Copy itinerary'))),
                                          HoverLift(
                                              child: ElevatedButton(
                                                  onPressed: onOpenLemon,
                                                  style:
                                                      ElevatedButton.styleFrom(
                                                          padding:
                                                              const EdgeInsets
                                                                  .symmetric(
                                                                  horizontal:
                                                                      20,
                                                                  vertical:
                                                                      16)),
                                                  child: const Text(
                                                      'Change with Lemon'))),
                                        ])),
                              ]))),
                ])));
      });
}

/// Lemon's summary of the whole trip.
class _Overview extends StatelessWidget {
  final String summary;
  const _Overview({required this.summary});
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
      decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.black.withValues(alpha: .05))),
      child: Row(children: [
        const LemonCircle(size: 72, background: AppTheme.surface),
        const SizedBox(width: 18),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text("LEMON'S OVERVIEW",
              style: TextStyle(
                  color: AppTheme.primary,
                  fontSize: 14,
                  letterSpacing: 1.4,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(summary,
              style: lemonNote.copyWith(
                  color: AppTheme.textPrimary, fontSize: 17.5)),
        ])),
      ]));
}

// Lemon's invitations to open a tip, rotated by stop so they don't repeat.
const _tipLabels = [
  'A little tip from Lemon',
  'Psst! Lemon has an idea',
  'Ooh, Lemon’s secret for this one',
  'Lemon’s happy hint',
];

/// One stop on a day's timeline, with Lemon's tip behind a toggle.
class _Stop extends StatefulWidget {
  final ItineraryActivity activity;
  final int number;
  final Color tint, accent;
  final bool last;
  const _Stop(
      {required this.activity,
      required this.number,
      required this.tint,
      required this.accent,
      required this.last});
  @override
  State<_Stop> createState() => _StopState();
}

class _StopState extends State<_Stop> {
  bool _hover = false, _open = false;
  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    final motion = reduced ? Duration.zero : AppTheme.motionStandard;
    final activity = widget.activity;
    final hasTip = activity.notes?.isNotEmpty == true;
    return MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: AnimatedContainer(
            duration: motion,
            color: _hover ? const Color(0xFFF8FCFB) : const Color(0x00FFFFFF),
            padding: const EdgeInsets.fromLTRB(22, 12, 22, 12),
            child: Stack(clipBehavior: Clip.none, children: [
              // The timeline thread, running on to the next stop's dot.
              if (!widget.last)
                Positioned(
                    left: 5,
                    top: 18,
                    bottom: -30,
                    child: Container(width: 2, color: widget.accent)),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: AnimatedScale(
                        scale: _hover && !reduced ? 1.3 : 1,
                        duration: motion,
                        curve: Curves.easeOutBack,
                        child: Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                                color: AppTheme.primary,
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: AppTheme.surface, width: 2))))),
                const SizedBox(width: 14),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 9, vertical: 2),
                                decoration: BoxDecoration(
                                    color: widget.tint,
                                    borderRadius: BorderRadius.circular(8)),
                                child: Text(activity.time,
                                    style: const TextStyle(
                                        color: AppTheme.textPrimary,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700))),
                            Text('STOP ${widget.number}',
                                style: const TextStyle(
                                    fontSize: 11.5,
                                    letterSpacing: 1,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.textSecondary)),
                          ]),
                      const SizedBox(height: 6),
                      Text(activity.activity,
                          style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 16.5,
                              height: 1.35,
                              fontWeight: FontWeight.w700)),
                      if (activity.location?.isNotEmpty == true)
                        Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Padding(
                                      padding: EdgeInsets.only(top: 2),
                                      child: Icon(Icons.place_outlined,
                                          size: 16, color: AppTheme.primary)),
                                  const SizedBox(width: 5),
                                  Expanded(
                                      child: Text(activity.location!,
                                          style: const TextStyle(
                                              color: AppTheme.textSecondary,
                                              fontSize: 14,
                                              height: 1.4))),
                                ])),
                      if (hasTip) ...[
                        const SizedBox(height: 10),
                        _tipToggle(),
                        AnimatedSize(
                            duration: motion,
                            curve: AppTheme.motionCurve,
                            alignment: Alignment.topLeft,
                            child: _open
                                ? Container(
                                    width: double.infinity,
                                    margin: const EdgeInsets.only(top: 10),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 14),
                                    decoration: BoxDecoration(
                                        color: _tipNoteFill,
                                        borderRadius: const BorderRadius.only(
                                            topLeft: Radius.circular(6),
                                            topRight: Radius.circular(18),
                                            bottomLeft: Radius.circular(18),
                                            bottomRight: Radius.circular(18)),
                                        border: Border.all(color: _tipBorder)),
                                    child: Text(activity.notes!,
                                        style: lemonNote.copyWith(
                                            color: _tipInk, fontSize: 16)))
                                : const SizedBox(width: double.infinity)),
                      ],
                    ])),
              ]),
            ])));
  }

  Widget _tipToggle() => Semantics(
      button: true,
      expanded: _open,
      child: HoverLift(
          child: Material(
              color: _tipFill,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: const BorderSide(color: _tipBorder)),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                  onTap: () => setState(() => _open = !_open),
                  child: Padding(
                      padding: const EdgeInsets.fromLTRB(6, 6, 12, 6),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const LemonCircle(
                            size: 30, background: _tipFill, float: false),
                        const SizedBox(width: 8),
                        Flexible(
                            child: Text(
                                _open
                                    ? 'Hide Lemon’s tip'
                                    : _tipLabels[(widget.number - 1) %
                                        _tipLabels.length],
                                style: lemonNote.copyWith(
                                    color: _tipInk,
                                    fontSize: 15.5,
                                    fontWeight: FontWeight.w600))),
                        const SizedBox(width: 4),
                        AnimatedRotation(
                            turns: _open ? .5 : 0,
                            duration: AppTheme.motionStandard,
                            child: const Icon(Icons.expand_more_rounded,
                                size: 20, color: _tipInk)),
                      ]))))));
}
