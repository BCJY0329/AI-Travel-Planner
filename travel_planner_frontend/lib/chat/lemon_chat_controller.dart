import 'package:flutter/foundation.dart';
import '../models/itinerary_models.dart';
import '../services/lemon_api_service.dart';
import 'chat_message.dart';

enum ChatStep {
  destination,
  startDate,
  endDate,
  travelers,
  budget,
  interests,
  provider,
  confirm,
  generating,
  done,
}

class LemonChatController extends ChangeNotifier {
  final LemonApiService _api = LemonApiService();
  final List<ChatMessage> messages = [];

  ChatStep _step = ChatStep.destination;
  ChatStep get step => _step;

  String? destination;
  String? startDate;
  String? endDate;
  int? travelers;
  String? budgetLevel;
  List<String> interests = [];
  String provider = 'mock';

  ItineraryResponse? latestItinerary;
  final ValueNotifier<ItineraryResponse?> itineraryNotifier = ValueNotifier(null);

  bool _greeted = false;
  static final RegExp _dateRegex = RegExp(r'^\d{4}-\d{2}-\d{2}$');

  void startIfNeeded() {
    if (_greeted) return;
    _greeted = true;
    _addBot(
      "Hi, I'm Lemon! 🍋 I'll help you put together a dream trip itinerary. "
      "First — where are you headed?",
    );
  }

  void _addBot(String text) {
    messages.add(ChatMessage.text(ChatSender.bot, text));
    notifyListeners();
  }

  void _addUser(String text) {
    messages.add(ChatMessage.text(ChatSender.user, text));
    notifyListeners();
  }

  void _addQuickReplies(String text, List<String> options) {
    messages.add(ChatMessage.quickReplies(text, options));
    notifyListeners();
  }

  void _askDate(String prompt) {
    messages.add(ChatMessage.datePickerPrompt(prompt));
    notifyListeners();
  }

  void _dontKnow() {
    _addBot("Hmm, I don't know how to answer that. I'm just here to help plan your trip! 🍋");
    _rePromptCurrentStep();
  }

  void _rePromptCurrentStep() {
    switch (_step) {
      case ChatStep.destination:
        _addBot("So — where are you headed?");
        break;
      case ChatStep.startDate:
        _askDate("When does your trip start?");
        break;
      case ChatStep.endDate:
        _askDate("And when does it end?");
        break;
      case ChatStep.travelers:
        _addBot("How many people are travelling? (1–20)");
        break;
      case ChatStep.budget:
        _addQuickReplies("What's your budget level?", ['low', 'medium', 'high']);
        break;
      case ChatStep.interests:
        _addBot(
          "What are you interested in? List a few, separated by commas "
          "(e.g. food, temples, nightlife).",
        );
        break;
      case ChatStep.provider:
        _addQuickReplies(
          "Which AI should I use to plan this?",
          ['mock', 'claude', 'gpt', 'gemini'],
        );
        break;
      case ChatStep.confirm:
        _showConfirmSummary();
        break;
      case ChatStep.generating:
      case ChatStep.done:
        break;
    }
  }

  void _showConfirmSummary() {
    _addQuickReplies(
      "Here's what I've got:\n"
      "📍 $destination\n"
      "📅 $startDate → $endDate\n"
      "👥 $travelers traveler(s)\n"
      "💰 $budgetLevel budget\n"
      "❤️ ${interests.join(', ')}\n"
      "🤖 AI: $provider\n\n"
      "Ready for me to plan it?",
      ['Yes, plan it!', 'Start over'],
    );
  }

  void handleQuickReply(String value) => handleUserInput(value);

  void handleUserInput(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return;
    _addUser(text);

    switch (_step) {
      case ChatStep.destination:
        destination = text;
        _step = ChatStep.startDate;
        _askDate("Got it — $destination! When does your trip start?");
        break;

      case ChatStep.startDate:
        if (!_dateRegex.hasMatch(text)) {
          _addBot("That doesn't look like a valid date. Use YYYY-MM-DD, or tap Pick a date.");
          _askDate("When does your trip start?");
          return;
        }
        startDate = text;
        _step = ChatStep.endDate;
        _askDate("And when does it end?");
        break;

      case ChatStep.endDate:
        if (!_dateRegex.hasMatch(text)) {
          _addBot("That doesn't look like a valid date. Use YYYY-MM-DD, or tap Pick a date.");
          _askDate("And when does it end?");
          return;
        }
        if (text.compareTo(startDate!) < 0) {
          _addBot("Your end date is before your start date — mind double-checking it?");
          _askDate("And when does it end?");
          return;
        }
        endDate = text;
        _step = ChatStep.travelers;
        _addBot("How many people are travelling? (1–20)");
        break;

      case ChatStep.travelers:
        final n = int.tryParse(text);
        if (n == null || n < 1 || n > 20) {
          _addBot("Please give me a number of travelers between 1 and 20.");
          return;
        }
        travelers = n;
        _step = ChatStep.budget;
        _addQuickReplies("What's your budget level?", ['low', 'medium', 'high']);
        break;

      case ChatStep.budget:
        final lower = text.toLowerCase();
        if (!['low', 'medium', 'high'].contains(lower)) {
          _dontKnow();
          return;
        }
        budgetLevel = lower;
        _step = ChatStep.interests;
        _addBot(
          "What are you interested in? List a few, separated by commas "
          "(e.g. food, temples, nightlife).",
        );
        break;

      case ChatStep.interests:
        interests = text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
        if (interests.isEmpty) {
          _addBot("Give me at least one interest, comma-separated.");
          return;
        }
        _step = ChatStep.provider;
        _addQuickReplies(
          "Which AI should I use to plan this?",
          ['mock', 'claude', 'gpt', 'gemini'],
        );
        break;

      case ChatStep.provider:
        final lower = text.toLowerCase();
        if (!['mock', 'claude', 'gpt', 'gemini'].contains(lower)) {
          _dontKnow();
          return;
        }
        provider = lower;
        _step = ChatStep.confirm;
        _showConfirmSummary();
        break;

      case ChatStep.confirm:
        final lower = text.toLowerCase();
        if (lower.contains('start over')) {
          _resetFlow();
          return;
        }
        if (lower.contains('yes')) {
          _generateItinerary();
          return;
        }
        _dontKnow();
        break;

      case ChatStep.generating:
        _addBot("Hang tight, I'm still working on your itinerary! 🍋");
        break;

      case ChatStep.done:
        final lower = text.toLowerCase();
        if (lower.contains('another') || lower.contains('new trip')) {
          _resetFlow();
          return;
        }
        _addBot(
          "I only help with trip planning! "
          "Would you like to plan another trip?",
        );
        messages.add(ChatMessage.quickReplies('', ['Plan another trip']));
        notifyListeners();
        break;
    }
  }

  Future<void> _generateItinerary() async {
    _step = ChatStep.generating;
    messages.add(ChatMessage.loading());
    notifyListeners();

    try {
      final response = await _api.planTrip(
        TripRequest(
          destination: destination!,
          startDate: startDate!,
          endDate: endDate!,
          travelers: travelers!,
          budgetLevel: budgetLevel!,
          interests: interests,
          provider: provider,
        ),
      );
      if (messages.isNotEmpty && messages.last.type == ChatMessageType.loading) {
        messages.removeLast();
      }
      latestItinerary = response;
      itineraryNotifier.value = response;
      messages.add(ChatMessage.itineraryResult(response));
      _addBot("Here's your itinerary! Want to plan another trip?");
      messages.add(ChatMessage.quickReplies('', ['Plan another trip']));
      _step = ChatStep.done;
      notifyListeners();
    } catch (_) {
      // Whenever Lemon.ai faces an error or a snag, never show raw terminal error or backend traces.
      // Instead say friendly error message and reloop back to the start!
      if (messages.isNotEmpty && messages.last.type == ChatMessageType.loading) {
        messages.removeLast();
      }
      _handleSnagAndReloop();
    }
  }

  void _handleSnagAndReloop() {
    _addBot("Sorry, I hit an error. Please try again! 🍋");
    _resetFlowState();
    _addBot("Where are you headed?");
    notifyListeners();
  }

  void _resetFlowState() {
    destination = null;
    startDate = null;
    endDate = null;
    travelers = null;
    budgetLevel = null;
    interests = [];
    provider = 'mock';
    _step = ChatStep.destination;
  }

  void _resetFlow() {
    _resetFlowState();
    _addBot("Sure! Let's plan a new trip. Where are you headed?");
    notifyListeners();
  }

  @override
  void dispose() {
    itineraryNotifier.dispose();
    super.dispose();
  }
}
