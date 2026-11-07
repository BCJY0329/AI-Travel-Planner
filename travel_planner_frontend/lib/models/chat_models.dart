import 'itinerary_models.dart' show MustVisitPlace, PlanEdit, cleanAiText;

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

  /// The first required detail still missing: 'destination', 'start_date',
  /// 'end_date', or 'confirm' once those are known; null when [ready].
  /// Travelers, budget and interests are optional (the app shows defaults).
  final String? nextField;

  /// What the traveller's latest message was (DECISIONS 059): 'trip',
  /// 'small_talk', 'off_topic', 'gibberish', 'unsafe', 'unhappy',
  /// 'switch_to_guided' or 'switch_to_free'.
  final String intent;

  /// Fields guessed from indirect wording ("me and my wife" -> travelers).
  final List<String> inferred;

  /// 'verified', 'unverified', 'not_found', 'ambiguous', or null when there
  /// is no destination yet.
  final String? destinationStatus;

  /// Labels such as 'Paris, France' when [destinationStatus] is 'ambiguous'.
  final List<String> destinationOptions;

  /// The exact place when [destinationStatus] is 'verified', e.g.
  /// 'Paris, France' (DECISIONS 068). Shown on the brief and sent to the plan.
  final String? destinationLabel;

  /// When Lemon picked the famous one of several same-name places: the
  /// others, for "Not this one?". Empty otherwise.
  final List<String> destinationAlternatives;

  /// True when the backend's local parser answered instead of an AI model.
  final bool fallbackUsed;

  /// 'relaxed', 'balanced' or 'packed' when the traveller said so (069).
  final String? pace;

  /// Places the traveller named, each checked near the destination.
  final List<MustVisitPlace> mustVisit;

  /// The latest message left the choice of spots to Lemon ("surprise me").
  final bool spotsToLemon;

  /// When [intent] is 'edit_plan': the change to make to the plan.
  final PlanEdit? edit;

  LemonChatResult({
    required this.reply,
    this.destination,
    this.startDate,
    this.endDate,
    this.travelers,
    this.budgetLevel,
    this.interests = const [],
    this.ready = false,
    this.nextField,
    this.intent = 'trip',
    this.inferred = const [],
    this.destinationStatus,
    this.destinationOptions = const [],
    this.destinationLabel,
    this.destinationAlternatives = const [],
    this.fallbackUsed = false,
    this.pace,
    this.mustVisit = const [],
    this.spotsToLemon = false,
    this.edit,
  });

  static List<String> _strings(Object? value) =>
      (value as List? ?? []).map((e) => e.toString()).toList();

  factory LemonChatResult.fromJson(Map<String, dynamic> json) =>
      LemonChatResult(
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
        interests: _strings(json['interests']),
        ready: json['ready'] as bool? ?? false,
        nextField: json['next_field'] as String?,
        intent: json['intent'] as String? ?? 'trip',
        inferred: _strings(json['inferred']),
        destinationStatus: json['destination_status'] as String?,
        destinationOptions: _strings(json['destination_options']),
        destinationLabel:
            (json['destination_label'] as String?)?.trim().isNotEmpty == true
                ? (json['destination_label'] as String).trim()
                : null,
        destinationAlternatives: _strings(json['destination_alternatives']),
        fallbackUsed: json['fallback_used'] as bool? ?? false,
        pace: const ['relaxed', 'balanced', 'packed'].contains(json['pace'])
            ? json['pace'] as String
            : null,
        mustVisit: (json['must_visit'] as List? ?? [])
            .whereType<Map<String, dynamic>>()
            .map(MustVisitPlace.fromJson)
            .where((m) => m.name.isNotEmpty && m.name.length <= 120)
            .toList(),
        spotsToLemon: json['spots_to_lemon'] as bool? ?? false,
        edit: PlanEdit.fromJson(json['edit']),
      );
}
