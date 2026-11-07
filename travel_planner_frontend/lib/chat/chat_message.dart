import '../models/itinerary_models.dart';

enum ChatSender { bot, user }

enum ChatMessageType {
  text,
  quickReplies,
  datePicker,
  itinerary,
  loading,

  /// Lemon's popular spots as buttons (DECISIONS 069).
  spots,

  /// A changed day to accept or turn down (DECISIONS 069).
  editPreview,
}

/// A changed day waiting for "Use this" / "Keep old" (DECISIONS 069).
class EditPreview {
  final PlanEdit edit;
  final ItineraryDay oldDay;
  final ItineraryDay newDay;
  final String providerUsed;

  /// Must-visits this day no longer has (DECISIONS 070).
  final List<String> missingMustVisits;

  /// 'pending', 'accepted' or 'kept'. Only a pending preview has buttons.
  String state = 'pending';

  EditPreview(
      {required this.edit,
      required this.oldDay,
      required this.newDay,
      required this.providerUsed,
      this.missingMustVisits = const []});

  bool get isDemo => providerUsed == 'mock';
}

class ChatMessage {
  final ChatSender sender;
  final ChatMessageType type;
  final String? text;
  final List<String>? quickReplies;
  final ItineraryResponse? itinerary;

  /// [ChatMessageType.spots]: the spots shown as buttons.
  final List<PopularSpot> spots;

  /// [ChatMessageType.editPreview]: the day to accept or turn down.
  final EditPreview? preview;

  /// Only used for [ChatMessageType.datePicker]: the earliest date the user
  /// should be allowed to pick. Null means "no lower bound beyond today"
  /// (used for the first/departure date). When asking for the return date,
  /// this is set to the day after the already-chosen departure date so the
  /// calendar can't show dates before it.
  final DateTime? minDate;

  ChatMessage._({
    required this.sender,
    required this.type,
    this.text,
    this.quickReplies,
    this.itinerary,
    this.minDate,
    this.spots = const [],
    this.preview,
  });

  factory ChatMessage.text(ChatSender sender, String text) =>
      ChatMessage._(sender: sender, type: ChatMessageType.text, text: text);

  factory ChatMessage.quickReplies(String prompt, List<String> options) =>
      ChatMessage._(
        sender: ChatSender.bot,
        type: ChatMessageType.quickReplies,
        text: prompt,
        quickReplies: options,
      );

  factory ChatMessage.datePickerPrompt(String prompt, {DateTime? minDate}) =>
      ChatMessage._(
        sender: ChatSender.bot,
        type: ChatMessageType.datePicker,
        text: prompt,
        minDate: minDate,
      );

  factory ChatMessage.itineraryResult(ItineraryResponse itinerary) =>
      ChatMessage._(
          sender: ChatSender.bot,
          type: ChatMessageType.itinerary,
          itinerary: itinerary);

  factory ChatMessage.loading([String label = 'Lemon is thinking...']) =>
      ChatMessage._(
        sender: ChatSender.bot,
        type: ChatMessageType.loading,
        text: label,
      );

  factory ChatMessage.spotList(String prompt, List<PopularSpot> spots) =>
      ChatMessage._(
          sender: ChatSender.bot,
          type: ChatMessageType.spots,
          text: prompt,
          spots: List.unmodifiable(spots));

  factory ChatMessage.editPreview(String prompt, EditPreview preview) =>
      ChatMessage._(
          sender: ChatSender.bot,
          type: ChatMessageType.editPreview,
          text: prompt,
          preview: preview);
}
