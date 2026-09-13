import '../models/itinerary_models.dart';

enum ChatSender { bot, user }

enum ChatMessageType { text, quickReplies, datePicker, itinerary, loading }

class ChatMessage {
  final ChatSender sender;
  final ChatMessageType type;
  final String? text;
  final List<String>? quickReplies;
  final ItineraryResponse? itinerary;

  ChatMessage._({
    required this.sender,
    required this.type,
    this.text,
    this.quickReplies,
    this.itinerary,
  });

  factory ChatMessage.text(ChatSender sender, String text) =>
      ChatMessage._(sender: sender, type: ChatMessageType.text, text: text);

  factory ChatMessage.quickReplies(String prompt, List<String> options) => ChatMessage._(
        sender: ChatSender.bot,
        type: ChatMessageType.quickReplies,
        text: prompt,
        quickReplies: options,
      );

  factory ChatMessage.datePickerPrompt(String prompt) =>
      ChatMessage._(sender: ChatSender.bot, type: ChatMessageType.datePicker, text: prompt);

  factory ChatMessage.itineraryResult(ItineraryResponse itinerary) =>
      ChatMessage._(sender: ChatSender.bot, type: ChatMessageType.itinerary, itinerary: itinerary);

  factory ChatMessage.loading([String label = 'Lemon is thinking...']) => ChatMessage._(
        sender: ChatSender.bot,
        type: ChatMessageType.loading,
        text: label,
      );
}
