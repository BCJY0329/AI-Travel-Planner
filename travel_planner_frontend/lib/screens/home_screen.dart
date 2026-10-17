import 'package:flutter/material.dart';
import '../chat/lemon_chat_controller.dart';
import '../config/app_theme.dart';
import '../widgets/lemon_bubble.dart';
import '../widgets/lemon_brand.dart';
import '../widgets/hover_lift.dart';
import '../widgets/lemon_chat_panel.dart';
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
  int _tab = 0;
  bool _open = false;
  bool _expandedChat = false;
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
          InkWell(
              onTap: () => _select(0),
              borderRadius: BorderRadius.circular(12),
              child: const HoverLift(child: LemonBrand())),
          if (!compact) ...[
            const SizedBox(width: 24),
            Expanded(
                child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(children: [
                      for (var i = 0; i < labels.length; i++)
                        Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: TextButton.icon(
                                style: TextButton.styleFrom(
                                    backgroundColor: _tab == i
                                        ? AppTheme.lavenderTint
                                        : null,
                                    foregroundColor: _tab == i
                                        ? AppTheme.primary
                                        : AppTheme.textSecondary),
                                onPressed: () => _select(i),
                                icon: Icon(icons[i], size: 18),
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
                child: OutlinedButton.icon(
                    onPressed: _openChat,
                    icon: const Icon(Icons.chat_bubble_outline, size: 18),
                    label: const Text('Ask Lemon'))),
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
                              DiscoverView(
                                  onOpenLemon: _openChat,
                                  onSelectTab: _select,
                                  activeItinerary: _chat.latestItinerary,
                                  onDestination: (place) {
                                    _openChat();
                                    _chat.startOver();
                                    _chat.handleUserInput(place);
                                  }),
                              _visited.contains(1)
                                  ? const FlightsView()
                                  : const SizedBox.shrink(),
                              _visited.contains(2)
                                  ? const HotelsView()
                                  : const SizedBox.shrink(),
                              _visited.contains(3)
                                  ? const AttractionsView()
                                  : const SizedBox.shrink(),
                              ItineraryView(
                                  itinerary: _chat.latestItinerary,
                                  onOpenLemon: _openChat),
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
                              : (_expandedChat
                                  ? (constraints.maxWidth - 40)
                                      .clamp(420, 860)
                                      .toDouble()
                                  : 420),
                          height: compact
                              ? constraints.maxHeight
                              : (constraints.maxHeight - 32)
                                  .clamp(0, _expandedChat ? 1000 : 720),
                          child: LemonChatPanel(
                              controller: _chat,
                              expanded: _expandedChat,
                              onToggleSize: compact
                                  ? null
                                  : () => setState(
                                      () => _expandedChat = !_expandedChat),
                              onClose: () => setState(() => _open = false),
                              onViewItinerary: () {
                                _select(4);
                                setState(() => _open = false);
                              })),
                  ]))),
    );
  }
}
