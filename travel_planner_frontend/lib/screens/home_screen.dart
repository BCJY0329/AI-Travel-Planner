import 'package:flutter/material.dart';
import '../chat/lemon_chat_controller.dart';
import '../config/app_theme.dart';
import '../widgets/focus_ring.dart';
import '../widgets/lemon_bubble.dart';
import '../widgets/lemon_brand.dart';
import '../widgets/hover_lift.dart';
import '../widgets/lemon_chat_panel.dart';
import '../services/place_photos.dart';
import '../services/travel_api_service.dart';
import '../widgets/page_parts.dart';
import 'views/attractions_view.dart';
import 'views/discover_view.dart';
import 'views/flights_view.dart';
import 'views/hotels_view.dart';
import 'views/itinerary_view.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _chat = LemonChatController();
  final _photos = PlacePhotoSource(TravelApiService());
  int _tab = 0;
  bool _open = false;
  double _chatWidth = 440;
  double _chatHeight = 640;
  final Set<int> _visited = {0};
  static const labels = [
    'Discover',
    'Flights',
    'Hotels',
    'Attractions',
    'My itinerary'
  ];
  static const icons = [
    Icons.explore_outlined,
    Icons.flight_outlined,
    Icons.hotel_outlined,
    Icons.place_outlined,
    Icons.map_outlined
  ];
  @override
  void initState() {
    super.initState();
    _chat.itineraryNotifier.addListener(_updated);
  }

  void _updated() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _chat.itineraryNotifier.removeListener(_updated);
    _chat.dispose();
    super.dispose();
  }

  void _select(int value) => setState(() {
        _tab = value;
        _visited.add(value);
      });
  void _openChat() {
    setState(() => _open = true);
    _chat.startIfNeeded();
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 1050 ||
        MediaQuery.textScalerOf(context).scale(14) > 20;
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 72,
        titleSpacing: compact ? 16 : 28,
        title: Row(children: [
          FocusRing(
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                  onTap: () => _select(0),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                      padding: const EdgeInsets.fromLTRB(6, 8, 6, 4),
                      child: LemonBrand(fontSize: compact ? 26 : 29)))),
          if (!compact) ...[
            // Room and a divider so the name reads as the app's brand, not
            // the first of the tabs.
            const SizedBox(width: 20),
            Container(width: 1.5, height: 32, color: AppTheme.navBarBorder),
            const SizedBox(width: 20),
            Expanded(
                child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(children: [
                      for (var i = 0; i < labels.length; i++)
                        Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: TextButton.icon(
                                style: TextButton.styleFrom(
                                    backgroundColor:
                                        _tab == i ? AppTheme.skyBlue : null,
                                    foregroundColor: _tab == i
                                        ? AppTheme.textPrimary
                                        : AppTheme.navBarText,
                                    textStyle: TextStyle(
                                        fontFamily: AppTheme.tripBodyFont,
                                        fontSize: 16,
                                        fontWeight: _tab == i
                                            ? FontWeight.w700
                                            : FontWeight.w600)),
                                onPressed: () => _select(i),
                                icon: Icon(icons[i], size: 20),
                                label: Text(labels[i]))),
                    ]))),
          ],
        ]),
        actions: [
          if (compact)
            PopupMenuButton<int>(
                tooltip: 'Navigation',
                initialValue: _tab,
                onSelected: _select,
                itemBuilder: (_) => [
                      for (var i = 0; i < labels.length; i++)
                        PopupMenuItem(
                            value: i,
                            child: Row(children: [
                              Icon(icons[i]),
                              const SizedBox(width: 12),
                              Text(labels[i])
                            ]))
                    ]),
          if (!compact)
            Padding(
                padding: const EdgeInsets.only(right: 24),
                // Placeholder until accounts exist; it must not imply a login.
                child: Tooltip(
                    message: 'Accounts are coming soon',
                    child: HoverLift(
                        child: OutlinedButton.icon(
                            onPressed: () => ScaffoldMessenger.of(context)
                                .showSnackBar(const SnackBar(
                                    content: Text('Sign in is coming soon.'))),
                            style: OutlinedButton.styleFrom(
                                    backgroundColor: AppTheme.surface)
                                .copyWith(
                                    side: AppTheme.focusOutline(const BorderSide(
                                        color: AppTheme.border))),
                            icon:
                                const Icon(Icons.person_outline_rounded, size: 18),
                            label: const Text('Sign in'))))),
        ],
      ),
      body: SafeArea(
          child: LayoutBuilder(
              builder: (context, constraints) => Stack(children: [
                    Align(
                        alignment: Alignment.topCenter,
                        child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 1720),
                            child: IndexedStack(index: _tab, children: [
                              TripTypography(
                                  child: DiscoverView(
                                      onOpenLemon: _openChat,
                                      onSelectTab: _select,
                                      activeItinerary: _chat.latestItinerary,
                                      photos: _photos,
                                      onDestination: (place) {
                                        _openChat();
                                        _chat.startOver();
                                        _chat.handleUserInput(place);
                                      })),
                              _visited.contains(1)
                                  ? TripTypography(
                                      child: FlightsView(
                                          onOpenLemon: _openChat,
                                          photos: _photos,
                                          trip: _chat.latestTrip))
                                  : const SizedBox.shrink(),
                              _visited.contains(2)
                                  ? TripTypography(
                                      child: HotelsView(
                                          onOpenLemon: _openChat,
                                          photos: _photos,
                                          trip: _chat.latestTrip))
                                  : const SizedBox.shrink(),
                              _visited.contains(3)
                                  ? TripTypography(
                                      child: AttractionsView(
                                          onOpenLemon: _openChat,
                                          photos: _photos,
                                          trip: _chat.latestTrip))
                                  : const SizedBox.shrink(),
                              TripTypography(
                                  child: ItineraryView(
                                      itinerary: _chat.latestItinerary,
                                      onOpenLemon: _openChat,
                                      photos: _photos)),
                            ]))),
                    if (!_open)
                      Positioned(
                          right: 20,
                          bottom: 16,
                          child: LemonBubble(onTap: _openChat)),
                    if (_open)
                      Positioned(
                          right: compact ? 0 : 20,
                          bottom: compact ? 0 : 16,
                          width: compact
                              ? constraints.maxWidth
                              : _chatWidth
                                  .clamp(
                                      360,
                                      (constraints.maxWidth - 40)
                                          .clamp(360, 900))
                                  .toDouble(),
                          height: compact
                              ? constraints.maxHeight
                              : _chatHeight
                                  .clamp(
                                      360,
                                      (constraints.maxHeight - 32)
                                          .clamp(360, 850))
                                  .toDouble(),
                          child: LemonChatPanel(
                              controller: _chat,
                              onResize: compact
                                  ? null
                                  : (delta) => setState(() {
                                        _chatWidth = (_chatWidth - delta.dx)
                                            .clamp(
                                                360,
                                                (constraints.maxWidth - 40)
                                                    .clamp(360, 900))
                                            .toDouble();
                                        _chatHeight = (_chatHeight - delta.dy)
                                            .clamp(
                                                360,
                                                (constraints.maxHeight - 32)
                                                    .clamp(360, 850))
                                            .toDouble();
                                      }),
                              onClose: () => setState(() => _open = false),
                              onViewItinerary: () {
                                _select(4);
                                setState(() => _open = false);
                              })),
                  ]))),
    );
  }
}
