import 'package:flutter/material.dart';
import '../../config/app_theme.dart';
import '../../widgets/gentle_reveal.dart';
import '../../widgets/lemon_avatar_image.dart';
import '../../widgets/hover_lift.dart';
import '../../models/itinerary_models.dart';

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
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 96),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [
                  AppTheme.lavenderTint,
                  AppTheme.mint,
                  AppTheme.sky
                ], begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(28)),
            child: GentleReveal(
                child: LayoutBuilder(
                    builder: (context, box) => Row(children: [
                          Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                const Text(
                                    'LEMONTRIP  /  MADE FOR YOUR KIND OF TRAVEL',
                                    style: TextStyle(
                                        color: AppTheme.teal,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 1)),
                                const SizedBox(height: 20),
                                const GentleReveal(
                                    child: Text(
                                        'A little curiosity.\nA whole new adventure.',
                                        style: TextStyle(
                                            color: AppTheme.textPrimary,
                                            fontSize: 36,
                                            fontWeight: FontWeight.w800,
                                            height: 1.15))),
                                const SizedBox(height: 18),
                                const Text('Your personal travel companion',
                                    style: TextStyle(
                                        color: AppTheme.textPrimary,
                                        fontSize: 19,
                                        fontWeight: FontWeight.w600)),
                                const SizedBox(height: 8),
                                const Text(
                                    'Choose your dates, share what you love, and let Lemon help shape your next trip.',
                                    style: TextStyle(
                                        color: AppTheme.textSecondary,
                                        fontSize: 15,
                                        height: 1.6)),
                                const SizedBox(height: 24),
                                Wrap(spacing: 12, runSpacing: 12, children: [
                                  ElevatedButton.icon(
                                      onPressed: onOpenLemon,
                                      style: ElevatedButton.styleFrom(
                                          backgroundColor: AppTheme.primary,
                                          foregroundColor: Colors.white),
                                      icon: const Icon(Icons.auto_awesome,
                                          size: 18),
                                      label:
                                          const Text('Plan a trip with Lemon')),
                                  TextButton.icon(
                                      onPressed: () => onSelectTab(3),
                                      style: TextButton.styleFrom(
                                          foregroundColor: AppTheme.primary),
                                      icon: const Icon(Icons.explore_outlined),
                                      label: const Text('Explore places')),
                                ]),
                              ])),
                          if (box.maxWidth > 850) ...[
                            const SizedBox(width: 40),
                            const SizedBox(width: 320, child: _LemonPostcard())
                          ],
                        ]))),
          ),
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
                          const Icon(Icons.map_outlined, color: AppTheme.teal),
                          Text(
                              '${activeItinerary!.destination} · ${activeItinerary!.days.length} day${activeItinerary!.days.length == 1 ? '' : 's'}',
                              style: const TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.w700)),
                          if (activeItinerary!.providerUsed == 'mock')
                            const Chip(label: Text('Demo itinerary')),
                          TextButton(
                              onPressed: () => onSelectTab(4),
                              child: const Text('Continue your trip →')),
                        ])))
          ],
          const SizedBox(height: 32),
          const Text('Everything for your next escape',
              style: TextStyle(fontSize: 23, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          const Text('Explore the possibilities, one detail at a time.',
              style: TextStyle(color: AppTheme.textSecondary)),
          const SizedBox(height: 18),
          LayoutBuilder(builder: (context, box) {
            final columns = box.maxWidth > 850
                ? 3
                : box.maxWidth > 550
                    ? 2
                    : 1;
            final width = (box.maxWidth - (columns - 1) * 16) / columns;
            return Wrap(spacing: 16, runSpacing: 16, children: [
              for (final item in [
                (
                  1,
                  Icons.flight_takeoff,
                  'Find your flight',
                  'Explore routes, schedules and available offers.',
                  AppTheme.lavenderTint
                ),
                (
                  2,
                  Icons.hotel_outlined,
                  'Find a place to stay',
                  'Browse hotel locations around your destination.',
                  const Color(0xFFE1F1EB)
                ),
                (
                  3,
                  Icons.explore_outlined,
                  'Follow your curiosity',
                  'Find local sights and places worth exploring.',
                  AppTheme.sky
                )
              ])
                SizedBox(
                    width: width,
                    child: GentleReveal(
                        child: HoverLift(
                            child: Card(
                                color: item.$5,
                                child: InkWell(
                                    borderRadius: BorderRadius.circular(16),
                                    onTap: () => onSelectTab(item.$1),
                                    child: Padding(
                                        padding: const EdgeInsets.all(22),
                                        child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(children: [
                                                Container(
                                                    padding:
                                                        const EdgeInsets.all(
                                                            12),
                                                    decoration: BoxDecoration(
                                                        color: Colors.white
                                                            .withValues(
                                                                alpha: .7),
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(14)),
                                                    child: Icon(item.$2,
                                                        color: AppTheme.teal)),
                                                const Spacer(),
                                                Text('0${item.$1} / EXPLORE',
                                                    style: const TextStyle(
                                                        letterSpacing: 1.5,
                                                        fontSize: 11,
                                                        color: AppTheme
                                                            .textSecondary)),
                                              ]),
                                              const SizedBox(height: 18),
                                              Text(item.$3,
                                                  style: const TextStyle(
                                                      fontSize: 18,
                                                      fontWeight:
                                                          FontWeight.w700)),
                                              const SizedBox(height: 8),
                                              Text(item.$4,
                                                  style: const TextStyle(
                                                      color: AppTheme
                                                          .textSecondary,
                                                      height: 1.5)),
                                              const SizedBox(height: 16),
                                              const Row(children: [
                                                Text('Take a look',
                                                    style: TextStyle(
                                                        color: AppTheme.primary,
                                                        fontWeight:
                                                            FontWeight.w600)),
                                                SizedBox(width: 8),
                                                Icon(Icons.arrow_forward,
                                                    size: 20,
                                                    color: AppTheme.primary),
                                              ]),
                                            ]))))))),
            ]);
          }),
          const SizedBox(height: 32),
          const Text('Where will curiosity take you?',
              style: TextStyle(fontSize: 23, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          Wrap(spacing: 12, runSpacing: 12, children: [
            for (final place in [
              ('Tokyo', 'Culture & food', Icons.temple_buddhist_outlined),
              ('Bali', 'Beaches & nature', Icons.beach_access_outlined),
              ('Paris', 'Art & city walks', Icons.museum_outlined),
              ('Rome', 'History & discovery', Icons.account_balance_outlined)
            ])
              HoverLift(
                  child: ActionChip(
                      avatar: Icon(place.$3, size: 18, color: AppTheme.teal),
                      label: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text('${place.$1} · ${place.$2}')),
                      onPressed: () => onDestination?.call(place.$1))),
          ]),
        ]),
      );
}

class _LemonPostcard extends StatelessWidget {
  const _LemonPostcard();
  @override
  Widget build(BuildContext context) => HoverLift(
          child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .85),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(
                  color: AppTheme.teal.withValues(alpha: .06),
                  blurRadius: 24,
                  offset: const Offset(0, 12))
            ]),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [
            Expanded(
                child: Text('YOUR NEXT CHAPTER',
                    style: TextStyle(
                        fontSize: 11,
                        letterSpacing: 1.5,
                        color: AppTheme.teal,
                        fontWeight: FontWeight.w700))),
            LemonAvatarImage(radius: 28),
          ]),
          const SizedBox(height: 14),
          const Text('Less planning.\nMore “we should go!”',
              style: TextStyle(
                  fontSize: 25, height: 1.2, fontWeight: FontWeight.w800)),
          const SizedBox(height: 20),
          for (final step in [
            (Icons.place_outlined, 'Pick your somewhere'),
            (Icons.favorite_border, 'Add a little of you'),
            (Icons.route_outlined, 'Let Lemon connect the dots'),
          ])
            Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(children: [
                  Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                          color: AppTheme.mint, shape: BoxShape.circle),
                      child: Icon(step.$1, size: 16, color: AppTheme.teal)),
                  const SizedBox(width: 10),
                  Expanded(child: Text(step.$2)),
                ])),
        ]),
      ));
}
