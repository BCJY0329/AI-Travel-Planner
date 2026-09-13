import 'package:flutter/foundation.dart';
import '../models/chat_models.dart';
import '../models/itinerary_models.dart';
import '../services/lemon_api_service.dart';
import 'chat_message.dart';

/// Phase of the overall flow. The freeform conversation itself has no fixed
/// steps anymore — Lemon (via the backend) decides what to ask about next —
/// this just tracks the coarse state of the widget.
enum ChatPhase { chatting, generating, done }

class LemonChatController extends ChangeNotifier {
  final LemonApiService _api = LemonApiService();

  /// Everything rendered in the chat UI (text bubbles, quick replies, the
  /// itinerary card, loading indicators).
  final List<ChatMessage> messages = [];

  /// The raw conversational turns only (no UI-only elements like loading
  /// spinners or quick-reply chips) — this is what gets sent to the backend
  /// so it has full context, since the backend itself is stateless.
  final List<ChatTurn> _history = [];

  ChatPhase phase = ChatPhase.chatting;
  bool get isBusy => _busy;
  bool _busy = false;

  String provider = 'mock';

  // Best-known trip fields, filled in progressively by the backend as the
  // conversation goes on. Any of these may still be null.
  String? destination;
  String? startDate;
  String? endDate;
  int? travelers;
  String? budgetLevel;
  List<String> interests = [];

  ItineraryResponse? latestItinerary;
  final ValueNotifier<ItineraryResponse?> itineraryNotifier = ValueNotifier(null);

  bool _greeted = false;

  void startIfNeeded() {
    if (_greeted) return;
    _greeted = true;
    _addBot(
      "Hi, I'm Lemon! 🍋 And I'm your travel planner assistant!"
      " I will help you create your travel itinerary, just provide me all the sufficient details!"
      " What city or destination are you thinking of travelling to?",
    );
  }

  void setProvider(String value) {
    if (_busy) return;
    provider = value;
    notifyListeners();
  }

  void _addBot(String text) {
    messages.add(ChatMessage.text(ChatSender.bot, text));
    _history.add(ChatTurn(role: 'assistant', content: text));
    notifyListeners();
  }

  /// Same bookkeeping as [_addBot] (still logs the plain text to history so
  /// the backend sees a normal assistant turn), but renders a date-picker
  /// bubble with a "Pick a Date" button instead of a plain text bubble.
  void _addBotDatePrompt(String text, {DateTime? minDate}) {
    messages.add(ChatMessage.datePickerPrompt(text, minDate: minDate));
    _history.add(ChatTurn(role: 'assistant', content: text));
    notifyListeners();
  }

  /// Best-effort detection of "Lemon is currently asking about dates" from
  /// the reply text alone. This is a stopgap: the real fix is for the
  /// backend to tell us explicitly which field it's asking about next, but
  /// until that's in place we pattern-match on common phrasing.
  bool _looksLikeDateQuestion(String text) {
    final lower = text.toLowerCase();
    const keywords = [
      'what date',
      'which date',
      'when would you like',
      'when are you',
      'when do you plan',
      'when will you',
      'when is your trip',
      'what dates',
      'travel date',
      'departure date',
      'return date',
      'start date',
      'end date',
      'check-in',
      'check in',
      'check-out',
      'check out',
      'come back',
      'come home',
    ];
    return keywords.any(lower.contains);
  }

  void _addUser(String text) {
    messages.add(ChatMessage.text(ChatSender.user, text));
    _history.add(ChatTurn(role: 'user', content: text));
    notifyListeners();
  }

  void handleQuickReply(String value) {
    if (value == 'Plan another trip') {
      _resetFlow();
      return;
    }
    handleUserInput(value);
  }

  Future<void> handleUserInput(String raw) async {
    final text = raw.trim();
    if (text.isEmpty || _busy) return;

    if (phase == ChatPhase.done) {
      final lower = text.toLowerCase();
      if (lower.contains('another') || lower.contains('new trip')) {
        _resetFlow();
        return;
      }
    }

    _addUser(text);
    await _sendToLemon();
  }

  Future<void> _sendToLemon() async {
    _busy = true;
    messages.add(ChatMessage.loading('Lemon is thinking...'));
    notifyListeners();

    try {
      final result = await _api.sendChatTurn(messages: _history, provider: provider);
      _removeTrailingLoading();

      // Only overwrite a known field when the backend actually returned a
      // fresh value for it, so earlier answers aren't clobbered by nulls.
      destination = result.destination ?? destination;
      startDate = result.startDate ?? startDate;
      endDate = result.endDate ?? endDate;
      travelers = result.travelers ?? travelers;
      budgetLevel = result.budgetLevel ?? budgetLevel;
      if (result.interests.isNotEmpty) interests = result.interests;

      final reply = result.reply.isNotEmpty
          ? result.reply
          : "Got it! Anything else you'd like to add, or shall I plan the trip?";

      // If we still need a date and the reply reads like a date question,
      // show the calendar-button bubble instead of a plain text bubble, and
      // constrain it: no lower bound for the departure date, or
      // "the day after departure" for the return date.
      if (!result.ready && _looksLikeDateQuestion(reply) && (startDate == null || endDate == null)) {
        DateTime? minDate;
        if (startDate != null) {
          final parsedStart = DateTime.tryParse(startDate!);
          if (parsedStart != null) {
            minDate = parsedStart.add(const Duration(days: 1));
          }
        }
        _addBotDatePrompt(reply, minDate: minDate);
      } else {
        _addBot(reply);
      }

      final haveMinimum = destination != null && startDate != null && endDate != null;
      if (result.ready && haveMinimum) {
        await _generateItinerary();
      } else {
        _busy = false;
        notifyListeners();
      }
    } catch (_) {
      _removeTrailingLoading();
      _busy = false;
      _handleSnagAndReloop();
    }
  }

  Future<void> _generateItinerary() async {
    phase = ChatPhase.generating;
    messages.add(ChatMessage.loading('Lemon is crafting your itinerary...'));
    notifyListeners();

    try {
      final response = await _api.planTrip(
        TripRequest(
          destination: destination!,
          startDate: startDate!,
          endDate: endDate!,
          travelers: travelers ?? 1,
          budgetLevel: budgetLevel ?? 'medium',
          interests: interests,
          provider: provider,
        ),
      );
      _removeTrailingLoading();

      latestItinerary = response;
      itineraryNotifier.value = response;
      messages.add(ChatMessage.itineraryResult(response));
      _addBot("Here's your itinerary! Want to plan another trip?");
      messages.add(ChatMessage.quickReplies('', ['Plan another trip']));
      phase = ChatPhase.done;
      _busy = false;
      notifyListeners();
    } catch (_) {
      // Whenever Lemon.ai faces an error or a snag, never show a raw
      // backend/terminal error — just say something friendly and reloop
      // back to the start of the conversation.
      _removeTrailingLoading();
      _busy = false;
      _handleSnagAndReloop();
    }
  }

  void _removeTrailingLoading() {
    if (messages.isNotEmpty && messages.last.type == ChatMessageType.loading) {
      messages.removeLast();
    }
  }

  void _handleSnagAndReloop() {
    _addBot("Sorry, I hit an error. Please try again! 🍋");
    _resetFlowState();
    _addBot("So — where would you like to go, and when?");
  }

  void _resetFlowState() {
    destination = null;
    startDate = null;
    endDate = null;
    travelers = null;
    budgetLevel = null;
    interests = [];
    _history.clear();
    phase = ChatPhase.chatting;
  }

  void _resetFlow() {
    _resetFlowState();
    _addBot("Sure! Let's plan a new trip. Where would you like to go, and when?");
  }

  @override
  void dispose() {
    itineraryNotifier.dispose();
    super.dispose();
  }
}