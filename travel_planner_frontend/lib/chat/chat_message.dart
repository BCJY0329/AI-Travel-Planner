import '../models/itinerary_models.dart';

enum ChatSender { bot, user }

enum ChatMessageType { text, quickReplies, datePicker, itinerary, loading }

class ChatMessage {
  final ChatSender sender;
  final ChatMessageType type;
  final String? text;
  final List<String>? quickReplies;
  final ItineraryResponse? itinerary;

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
  });

  factory ChatMessage.text(ChatSender sender, String text) =>
      ChatMessage._(sender: sender, type: ChatMessageType.text, text: text);

  factory ChatMessage.quickReplies(String prompt, List<String> options) => ChatMessage._(
        sender: ChatSender.bot,
        type: ChatMessageType.quickReplies,
        text: prompt,
        quickReplies: options,
      );

  factory ChatMessage.datePickerPrompt(String prompt, {DateTime? minDate}) => ChatMessage._(
        sender: ChatSender.bot,
        type: ChatMessageType.datePicker,
        text: prompt,
        minDate: minDate,
      );

  factory ChatMessage.itineraryResult(ItineraryResponse itinerary) =>
      ChatMessage._(sender: ChatSender.bot, type: ChatMessageType.itinerary, itinerary: itinerary);

  factory ChatMessage.loading([String label = 'Lemon is thinking...']) => ChatMessage._(
        sender: ChatSender.bot,
        type: ChatMessageType.loading,
        text: label,
      );
}