import 'package:flutter/material.dart';
import '../chat/lemon_chat_controller.dart';
import '../config/app_theme.dart';
import '../models/itinerary_models.dart';
import '../widgets/lemon_avatar_image.dart';
import '../widgets/lemon_bubble.dart';
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
  final LemonChatController _chatController = LemonChatController();
  int _currentTabIndex = 0;
  bool _chatOpen = false;

  @override
  void initState() {
    super.initState();
    _chatController.itineraryNotifier.addListener(_onItineraryGenerated);
  }

  void _onItineraryGenerated() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _chatController.itineraryNotifier.removeListener(_onItineraryGenerated);
    _chatController.dispose();
    super.dispose();
  }

  void _toggleChat() {
    setState(() => _chatOpen = !_chatOpen);
    if (_chatOpen) _chatController.startIfNeeded();
  }

  void _openChat() {
    if (!_chatOpen) {
      setState(() => _chatOpen = true);
      _chatController.startIfNeeded();
    }
  }

  void _selectTab(int index) {
    setState(() => _currentTabIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final activeItinerary = _chatController.latestItinerary;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: _buildTopNavBar(context, activeItinerary),
      body: Stack(
        children: [
          // Main tab content
          IndexedStack(
            index: _currentTabIndex,
            children: [
              DiscoverView(
                onOpenLemon: _openChat,
                onSelectTab: _selectTab,
                activeItinerary: activeItinerary,
              ),
              const FlightsView(),
              const HotelsView(),
              const AttractionsView(),
              ItineraryView(
                itinerary: activeItinerary,
                onOpenLemon: _openChat,
              ),
            ],
          ),

          // Floating Lemon assistant
          Positioned(
            right: 20,
            bottom: 20,
            child: _chatOpen
                ? LemonChatPanel(controller: _chatController, onClose: _toggleChat)
                : LemonBubble(onTap: _toggleChat),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildTopNavBar(BuildContext context, ItineraryResponse? activeItinerary) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 800;

    return PreferredSize(
      preferredSize: const Size.fromHeight(68),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surface,
          border: const Border(bottom: BorderSide(color: AppTheme.border, width: 1)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Row(
          children: [
            // Brand Logo
            InkWell(
              onTap: () => _selectTab(0),
              borderRadius: BorderRadius.circular(12),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppTheme.primary, AppTheme.primaryLight],
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.travel_explore_rounded, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'VoyageAI',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      Row(
                        children: [
                          const Text(
                            'Powered by ',
                            style: TextStyle(fontSize: 10.5, color: AppTheme.textSecondary),
                          ),
                          Text(
                            'Lemon.ai 🍋',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: Colors.amber.shade800,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(width: 32),

            // Nav Tabs
            if (!isCompact)
              Expanded(
                child: Row(
                  children: [
                    _buildNavTab(0, 'Discover', Icons.explore_outlined, Icons.explore_rounded),
                    _buildNavTab(1, 'Flights', Icons.flight_outlined, Icons.flight_rounded),
                    _buildNavTab(2, 'Hotels', Icons.hotel_outlined, Icons.hotel_rounded),
                    _buildNavTab(3, 'Attractions', Icons.place_outlined, Icons.place_rounded),
                    _buildNavTab(
                      4,
                      'My Itinerary',
                      Icons.map_outlined,
                      Icons.map_rounded,
                      badge: activeItinerary != null ? 'READY' : null,
                    ),
                  ],
                ),
              )
            else
              const Spacer(),

            // Right Action: Ask Lemon
            OutlinedButton.icon(
              onPressed: _toggleChat,
              icon: const LemonAvatarImage(radius: 11),
              label: Text(
                _chatOpen ? 'Hide Assistant' : 'Ask Lemon.ai',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.primary,
                side: const BorderSide(color: AppTheme.primary, width: 1.5),
                backgroundColor: _chatOpen ? AppTheme.lavenderTint : AppTheme.surface,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavTab(int index, String title, IconData icon, IconData activeIcon, {String? badge}) {
    final isSelected = _currentTabIndex == index;
    return InkWell(
      onTap: () => _selectTab(index),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.lavenderTint : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? activeIcon : icon,
              size: 18,
              color: isSelected ? AppTheme.primary : AppTheme.textSecondary,
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                fontSize: 13.5,
                color: isSelected ? AppTheme.primary : AppTheme.textSecondary,
              ),
            ),
            if (badge != null) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                decoration: BoxDecoration(
                  color: AppTheme.accentLemon,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  badge,
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
