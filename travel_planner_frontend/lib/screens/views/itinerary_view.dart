import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../config/app_theme.dart';
import '../../widgets/lemon_avatar_image.dart';
import '../../models/itinerary_models.dart';

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
                    const Text('Your next adventure starts here',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 28, fontWeight: FontWeight.w700)),
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
    return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 96),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Wrap(
              spacing: 12,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Chip(
                    label: Text(demo ? 'Demo itinerary' : 'Your travel plan'),
                    avatar: Icon(demo ? Icons.info_outline : Icons.auto_awesome,
                        size: 16),
                    backgroundColor: demo
                        ? const Color(0xFFFFECCD)
                        : const Color(0xFFE1F1EB)),
                Text(
                    '${trip.days.length} day${trip.days.length == 1 ? '' : 's'}',
                    style: const TextStyle(color: AppTheme.textSecondary)),
                OutlinedButton.icon(
                    onPressed: () => _copy(trip),
                    icon: const Icon(Icons.copy_outlined, size: 18),
                    label: const Text('Copy itinerary')),
                TextButton(
                    onPressed: widget.onOpenLemon,
                    child: const Text('Ask Lemon')),
              ]),
          const SizedBox(height: 14),
          Text('${trip.destination} itinerary',
              style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.6)),
          if (demo)
            const Padding(
                padding: EdgeInsets.only(top: 10),
                child: Text(
                    'This is a sample plan, not a personalized itinerary for your dates. Open Lemon to retry generation.',
                    style: TextStyle(color: AppTheme.accentLemonDark))),
          if (trip.summary?.isNotEmpty == true)
            Padding(
                padding: const EdgeInsets.only(top: 12),
                child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 850),
                    child: Text(trip.summary!,
                        style: const TextStyle(
                            fontSize: 16,
                            height: 1.6,
                            color: AppTheme.textSecondary)))),
          const SizedBox(height: 24),
          if (trip.days.length > 1)
            Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: Wrap(spacing: 8, runSpacing: 8, children: [
                  ChoiceChip(
                      label: const Text('All days'),
                      selected: _day == 0,
                      onSelected: (_) => setState(() => _day = 0)),
                  for (final day in trip.days)
                    ChoiceChip(
                        label: Text('Day ${day.day}'),
                        selected: _day == day.day,
                        onSelected: (_) => setState(() => _day = day.day)),
                ])),
          LayoutBuilder(builder: (context, box) {
            final days =
                trip.days.where((d) => _day == 0 || d.day == _day).toList();
            final columns = box.maxWidth >= 1050 &&
                    days.length > 1 &&
                    MediaQuery.textScalerOf(context).scale(16) <= 22
                ? 2
                : 1;
            final width = (box.maxWidth - (columns - 1) * 20) / columns;
            return Wrap(spacing: 20, runSpacing: 20, children: [
              for (final day in days)
                SizedBox(width: width, child: _dayCard(day)),
            ]);
          }),
        ]));
  }

  Widget _dayCard(ItineraryDay day) {
    const colors = [
      AppTheme.mint,
      AppTheme.sky,
      AppTheme.peach,
      AppTheme.lemon
    ];
    final tint = colors[(day.day - 1).abs() % colors.length];
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          color: tint,
          padding: const EdgeInsets.all(14),
          child: Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Icon(Icons.calendar_today_outlined, size: 22),
                Text('Day ${day.day}',
                    style: const TextStyle(
                        fontSize: 23, fontWeight: FontWeight.w800)),
                if (day.date != null) Text(_date(day.date)),
                Text('${day.activities.length} activities',
                    style: const TextStyle(color: AppTheme.textSecondary)),
              ]),
        ),
        Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (day.activities.isEmpty)
                    const Text('No activities planned for this day.'),
                  for (var i = 0; i < day.activities.length; i++)
                    _activity(day.activities[i], i + 1, tint, day.day + i - 1),
                ])),
      ]),
    );
  }

  static const _tipIntros = [
    'Psst... a little something for your adventure ✨',
    'A tiny tip for a happier wander 🌿',
    'Before you head off, adventure buddy... 🧭',
    'Let’s make this stop a little sweeter 💫',
    'Tuck this one into your travel pocket 🎒',
    'A little nudge from your travel buddy 💬',
  ];

  Widget _activity(
          ItineraryActivity activity, int number, Color tint, int tipIndex) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.border),
          ),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Wrap(
                spacing: 10,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                          color: tint, borderRadius: BorderRadius.circular(8)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.schedule, size: 16),
                        const SizedBox(width: 6),
                        Text(activity.time,
                            style:
                                const TextStyle(fontWeight: FontWeight.w700)),
                      ])),
                  Text('STOP $number',
                      style: const TextStyle(
                          fontSize: 11,
                          letterSpacing: 1,
                          color: AppTheme.textSecondary)),
                ]),
            const SizedBox(height: 12),
            Text(activity.activity,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w700, height: 1.4)),
            if (activity.location?.isNotEmpty == true)
              Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.place_outlined,
                            size: 18, color: AppTheme.teal),
                        const SizedBox(width: 6),
                        Expanded(
                            child: Text(activity.location!,
                                style: const TextStyle(
                                    color: AppTheme.textSecondary,
                                    height: 1.4))),
                      ])),
            if (activity.notes?.isNotEmpty == true)
              Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Theme(
                      data: Theme.of(context)
                          .copyWith(dividerColor: Colors.transparent),
                      child: ExpansionTile(
                        tilePadding: const EdgeInsets.symmetric(horizontal: 8),
                        collapsedBackgroundColor: AppTheme.mint,
                        backgroundColor: AppTheme.mint,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        collapsedShape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        childrenPadding:
                            const EdgeInsets.fromLTRB(12, 0, 12, 12),
                        leading: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: const BoxDecoration(
                                color: Colors.white, shape: BoxShape.circle),
                            child: const LemonAvatarImage(radius: 20)),
                        title: const Text("A little tip from Lemon",
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.teal)),
                        subtitle: Text(
                            _tipIntros[tipIndex.abs() % _tipIntros.length],
                            style: const TextStyle(fontSize: 12, height: 1.4)),
                        children: [
                          Align(
                              alignment: Alignment.centerLeft,
                              child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: .8),
                                      borderRadius: BorderRadius.circular(12)),
                                  child: Text(activity.notes!,
                                      style: const TextStyle(
                                          height: 1.5,
                                          color: AppTheme.textPrimary))))
                        ],
                      ))),
          ]),
        ),
      );
}
