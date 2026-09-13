import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../config/app_theme.dart';
import '../../models/itinerary_models.dart';
import '../../widgets/lemon_avatar_image.dart';

class ItineraryView extends StatefulWidget {
  final ItineraryResponse? itinerary;
  final VoidCallback onOpenLemon;

  const ItineraryView({
    super.key,
    required this.itinerary,
    required this.onOpenLemon,
  });

  @override
  State<ItineraryView> createState() => _ItineraryViewState();
}

class _ItineraryViewState extends State<ItineraryView> {
  int _selectedDayFilter = 0; // 0 = all days

  @override
  Widget build(BuildContext context) {
    if (widget.itinerary == null) {
      return _buildEmptyState(context);
    }
    return _buildItineraryDetails(context, widget.itinerary!);
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 560),
          padding: const EdgeInsets.all(36),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppTheme.border),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primary.withValues(alpha: 0.06),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppTheme.lavenderTint,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppTheme.border, width: 2),
                ),
                padding: const EdgeInsets.all(4),
                child: const LemonAvatarImage(radius: 32),
              ),
              const SizedBox(height: 20),
              const Text(
                'No Itinerary Generated Yet',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Let Lemon.ai know where you want to go, your travel dates, and your favorite activities. Lemon will craft a clean, day-by-day plan tailored to your preferences!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: widget.onOpenLemon,
                icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                label: const Text('Start Planning with Lemon.ai 🍋'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildItineraryDetails(BuildContext context, ItineraryResponse itinerary) {
    final daysToDisplay = _selectedDayFilter == 0
        ? itinerary.days
        : itinerary.days.where((d) => d.day == _selectedDayFilter).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppTheme.primary, AppTheme.primaryLight],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'AI GENERATED • ${itinerary.providerUsed.toUpperCase()}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.accentLemon,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${itinerary.days.length} Days Trip',
                              style: const TextStyle(
                                color: AppTheme.textPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '${itinerary.destination} Itinerary',
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      if (itinerary.summary != null && itinerary.summary!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          itinerary.summary!,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withValues(alpha: 0.92),
                            height: 1.4,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy_rounded, color: Colors.white),
                  tooltip: 'Copy Summary',
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: itinerary.summary ?? itinerary.destination));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Itinerary copied to clipboard!'),
                        backgroundColor: AppTheme.primary,
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Day Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ChoiceChip(
                  label: const Text('All Days'),
                  selected: _selectedDayFilter == 0,
                  selectedColor: AppTheme.lavenderTint,
                  backgroundColor: AppTheme.surface,
                  side: BorderSide(
                    color: _selectedDayFilter == 0 ? AppTheme.primary : AppTheme.border,
                  ),
                  labelStyle: TextStyle(
                    color: _selectedDayFilter == 0 ? AppTheme.primary : AppTheme.textPrimary,
                    fontWeight: _selectedDayFilter == 0 ? FontWeight.w700 : FontWeight.w500,
                  ),
                  onSelected: (_) => setState(() => _selectedDayFilter = 0),
                ),
                const SizedBox(width: 8),
                for (final day in itinerary.days)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text('Day ${day.day}'),
                      selected: _selectedDayFilter == day.day,
                      selectedColor: AppTheme.lavenderTint,
                      backgroundColor: AppTheme.surface,
                      side: BorderSide(
                        color: _selectedDayFilter == day.day ? AppTheme.primary : AppTheme.border,
                      ),
                      labelStyle: TextStyle(
                        color: _selectedDayFilter == day.day ? AppTheme.primary : AppTheme.textPrimary,
                        fontWeight: _selectedDayFilter == day.day ? FontWeight.w700 : FontWeight.w500,
                      ),
                      onSelected: (_) => setState(() => _selectedDayFilter = day.day),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Day Schedule Cards
          for (final day in daysToDisplay) ...[
            _buildDayScheduleCard(context, day),
            const SizedBox(height: 20),
          ],
        ],
      ),
    );
  }

  Widget _buildDayScheduleCard(BuildContext context, ItineraryDay day) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.lavenderTint,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Day ${day.day}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: AppTheme.primary,
                  ),
                ),
              ),
              if (day.date != null && day.date!.isNotEmpty) ...[
                const SizedBox(width: 10),
                Text(
                  day.date!,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
              const Spacer(),
              Text(
                '${day.activities.length} Activities',
                style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: AppTheme.borderLight),
          const SizedBox(height: 16),
          for (var i = 0; i < day.activities.length; i++) ...[
            _buildActivityTimelineRow(day.activities[i], isLast: i == day.activities.length - 1),
          ],
        ],
      ),
    );
  }

  Widget _buildActivityTimelineRow(ItineraryActivity act, {required bool isLast}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Time badge & timeline dot
          SizedBox(
            width: 75,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.lavenderSubtle,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Text(
                    act.time,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // Activity Content (no ## or markdown symbols!)
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.background,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.borderLight),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    act.activity,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  if (act.location != null && act.location!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.place_outlined, size: 14, color: AppTheme.primary),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            act.location!,
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: AppTheme.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (act.notes != null && act.notes!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('💡 ', style: TextStyle(fontSize: 11)),
                          Expanded(
                            child: Text(
                              act.notes!,
                              style: TextStyle(
                                fontSize: 11.5,
                                color: Colors.amber.shade900,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
