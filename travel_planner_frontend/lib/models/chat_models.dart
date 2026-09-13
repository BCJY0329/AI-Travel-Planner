import 'itinerary_models.dart' show cleanAiText;

/// One turn of the raw conversation, sent to the backend so it has full
/// context on every request (the backend itself is stateless between calls).
class ChatTurn {
  final String role; // 'user' or 'assistant'
  final String content;

  ChatTurn({required this.role, required this.content});

  Map<String, dynamic> toJson() => {'role': role, 'content': content};
}

/// What the backend hands back after each freeform chat turn: a natural-
/// language reply to show, plus whatever trip fields it has managed to
/// extract from the conversation so far (any of them may still be null).
class LemonChatResult {
  final String reply;
  final String? destination;
  final String? startDate;
  final String? endDate;
  final int? travelers;
  final String? budgetLevel;
  final List<String> interests;
  final bool ready;

  LemonChatResult({
    required this.reply,
    this.destination,
    this.startDate,
    this.endDate,
    this.travelers,
    this.budgetLevel,
    this.interests = const [],
    this.ready = false,
  });

  factory LemonChatResult.fromJson(Map<String, dynamic> json) => LemonChatResult(
        // Defense-in-depth: also sanitize on the client even though the
        // backend already strips markdown before sending this over.
        reply: cleanAiText(json['reply'] as String? ?? ''),
        destination: (json['destination'] as String?)?.trim().isNotEmpty == true
            ? (json['destination'] as String).trim()
            : null,
        startDate: json['start_date'] as String?,
        endDate: json['end_date'] as String?,
        travelers: (json['travelers'] as num?)?.toInt(),
        budgetLevel: json['budget_level'] as String?,
        interests: (json['interests'] as List? ?? []).map((e) => e.toString()).toList(),
        ready: json['ready'] as bool? ?? false,
      );
}
