import 'package:flutter/material.dart';
import '../chat/chat_message.dart';
import '../config/app_theme.dart';
import '../models/itinerary_models.dart';
import 'lemon_avatar_image.dart';

class ChatBubbleWidget extends StatelessWidget {
  final ChatMessage message;
  final ValueChanged<String> onQuickReply;
  final ValueChanged<DateTime?> onPickDate;

  const ChatBubbleWidget({
    super.key,
    required this.message,
    required this.onQuickReply,
    required this.onPickDate,
  });

  @override
  Widget build(BuildContext context) {
    final isBot = message.sender == ChatSender.bot;

    switch (message.type) {
      case ChatMessageType.text:
        return _row(isBot, _textBubble(message.text ?? '', isBot));

      case ChatMessageType.loading:
        return _row(
          true,
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.lavenderTint,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppTheme.primary,
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    message.text ?? 'Lemon is thinking...',
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );

      case ChatMessageType.quickReplies:
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if ((message.text ?? '').isNotEmpty)
                _row(true, _textBubble(message.text!, true)),
              Padding(
                padding: const EdgeInsets.only(left: 38, top: 6),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: (message.quickReplies ?? []).map((opt) {
                    final isPlanIt = opt.contains('plan it');
                    return ActionChip(
                      onPressed: () => onQuickReply(opt),
                      backgroundColor: isPlanIt ? AppTheme.primary : AppTheme.surface,
                      side: BorderSide(
                        color: isPlanIt ? AppTheme.primary : AppTheme.primaryLight,
                        width: 1.2,
                      ),
                      label: Text(
                        opt,
                        style: TextStyle(
                          color: isPlanIt ? Colors.white : AppTheme.primary,
                          fontWeight: FontWeight.w600,
                          fontSize: 12.5,
                        ),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        );

      case ChatMessageType.datePicker:
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _row(true, _textBubble(message.text ?? '', true)),
              Padding(
                padding: const EdgeInsets.only(left: 38, top: 6),
                child: ElevatedButton.icon(
                  onPressed: () => onPickDate(message.minDate),
                  icon: const Icon(Icons.calendar_today_rounded, size: 15),
                  label: const Text('Pick a Date'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );

      case ChatMessageType.itinerary:
        return _itineraryCard(context, message.itinerary!);
    }
  }

  Widget _row(bool isBot, Widget bubble) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: isBot ? MainAxisAlignment.start : MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (isBot) ...[
            const LemonAvatarImage(radius: 14),
            const SizedBox(width: 8),
          ],
          Flexible(child: bubble),
        ],
      ),
    );
  }

  Widget _textBubble(String text, bool isBot, {bool italic = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isBot ? AppTheme.surface : AppTheme.primary,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(16),
          topRight: const Radius.circular(16),
          bottomLeft: Radius.circular(isBot ? 4 : 16),
          bottomRight: Radius.circular(isBot ? 16 : 4),
        ),
        border: Border.all(
          color: isBot ? AppTheme.border : AppTheme.primaryDark,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        text,
        style: TextStyle(
          color: isBot ? AppTheme.textPrimary : Colors.white,
          fontSize: 13.5,
          height: 1.35,
          fontStyle: italic ? FontStyle.italic : FontStyle.normal,
        ),
      ),
    );
  }

  Widget _itineraryCard(BuildContext context, ItineraryResponse itinerary) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.border, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primary.withValues(alpha: 0.08),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Banner
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppTheme.primary, AppTheme.primaryLight],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(14),
                  topRight: Radius.circular(14),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.explore_rounded, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${itinerary.destination} Itinerary',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      itinerary.providerUsed.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 10.5,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Summary
            if (itinerary.summary != null && itinerary.summary!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.lavenderSubtle,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.borderLight),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.auto_awesome_rounded, color: AppTheme.primary, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          itinerary.summary!,
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12.5,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Days & Activities
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final day in itinerary.days) ...[
                    // Day Pill
                    Container(
                      margin: const EdgeInsets.only(top: 8, bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.lavenderTint,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Day ${day.day}${day.date != null ? " • ${day.date}" : ""}',
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),

                    // Activities Timeline
                    for (final act in day.activities)
                      Padding(
                        padding: const EdgeInsets.only(left: 6, bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Time Chip
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppTheme.background,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: AppTheme.border),
                              ),
                              child: Text(
                                act.time,
                                style: const TextStyle(
                                  color: AppTheme.primary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Activity details
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    act.activity,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                      color: AppTheme.textPrimary,
                                    ),
                                  ),
                                  if (act.location != null && act.location!.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Row(
                                      children: [
                                        const Icon(Icons.place_outlined, size: 12, color: AppTheme.textSecondary),
                                        const SizedBox(width: 3),
                                        Expanded(
                                          child: Text(
                                            act.location!,
                                            style: const TextStyle(
                                              fontSize: 11.5,
                                              color: AppTheme.textSecondary,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                  if (act.notes != null && act.notes!.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      '💡 ${act.notes!}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.amber.shade900,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}