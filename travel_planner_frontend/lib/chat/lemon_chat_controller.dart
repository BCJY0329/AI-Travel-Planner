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

  // The backend picks — and silently swaps between — whichever LLM provider
  // is actually available, so there's no manual engine picker in the UI
  // anymore. `auto` is the only value ever sent.
  final String provider = 'auto';

  // Best-known trip fields, filled in progressively by the backend as the
  // conversation goes on. Any of these may still be null.
  String? destination;
  String? startDate;
  String? endDate;
  int? travelers;
  String? budgetLevel;
  List<String> interests = [];

  /// Which field Lemon is currently asking about, per the backend's explicit
  /// signal — 'destination', 'start_date', 'end_date', 'travelers',
  /// 'budget_level', 'confirm', or null. Drives the date-picker bubble and
  /// the input field's hint text.
  String? nextField;

  ItineraryResponse? latestItinerary;
  final ValueNotifier<ItineraryResponse?> itineraryNotifier = ValueNotifier(null);

  bool _greeted = false;

  void startIfNeeded() {
    if (_greeted) return;
    _greeted = true;
    nextField = 'destination';
    // "\n\n" splits this into two separate bubbles — see _addBot below.
    _addBot(
      "Hi, I'm Lemon! 🍋 I'm your travel planner assistant, and I'm genuinely excited to help you plan something great!\n\n"
      "So — where are you dreaming of going?",
    );
  }

  void _addBot(String text) {
    // A blank line ("\n\n") signals a natural break between separate
    // thoughts (e.g. a greeting and a question) — split those into their
    // own bubbles instead of rendering everything as one dense block.
    final segments = text.split('\n\n').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    if (segments.isEmpty) return;
    for (final segment in segments) {
      messages.add(ChatMessage.text(ChatSender.bot, segment));
    }
    // The backend only ever sees ONE assistant turn per reply, even though
    // it may render as multiple bubbles — bubble-splitting is a display
    // convention the backend doesn't need to know about.
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

  /// Fallback only, used when the backend doesn't supply `next_field` (an
  /// older backend build, or a real LLM provider response that ever omits
  /// it). `nextField` from the backend is the primary signal now — this
  /// keyword match is a stopgap, not the main detection path anymore.
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
      nextField = result.nextField;

      final reply = result.reply.isNotEmpty
          ? result.reply
          : "Got it! Anything else you'd like to add, or shall I plan the trip?";

      // Prefer the backend's explicit next_field signal; only fall back to
      // pattern-matching the reply text if next_field wasn't provided.
      final isDateField = nextField == 'start_date' || nextField == 'end_date';
      final looksLikeDate = nextField == null && _looksLikeDateQuestion(reply);

      if (!result.ready && (isDateField || looksLikeDate) && (startDate == null || endDate == null)) {
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
      _addBot("Ta-da! ✨ Here's your itinerary — want to plan another trip?");
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
    _addBot("Oops, I tripped over my own suitcase there! 🧳 Let's try that again.");
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
    nextField = 'destination';
    _history.clear();
    phase = ChatPhase.chatting;
  }

  void _resetFlow() {
    _resetFlowState();
    _addBot("Yay, another adventure! 🌍 Where would you like to go, and when?");
  }

  @override
  void dispose() {
    itineraryNotifier.dispose();
    super.dispose();
  }
}