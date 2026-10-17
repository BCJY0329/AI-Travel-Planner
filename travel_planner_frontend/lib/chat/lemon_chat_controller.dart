import 'package:flutter/foundation.dart';
import '../models/chat_models.dart';
import '../models/itinerary_models.dart';
import '../services/lemon_api_service.dart';
import 'chat_message.dart';

enum ChatPhase { chatting, generating, done }

class LemonChatController extends ChangeNotifier {
  LemonChatController({LemonApiService? api}) : _api = api ?? LemonApiService();
  final LemonApiService _api;
  final List<ChatMessage> messages = [];
  final List<ChatTurn> _history = [];
  final String provider = 'auto';
  ChatPhase phase = ChatPhase.chatting;
  bool _busy = false;
  bool _disposed = false;
  bool _greeted = false;
  int _greetingIndex = 0;
  bool _interestsAnswered = false;
  bool _retryPlan = false;
  String? error;
  String draft = '';
  String otherInterests = '';
  final Set<String> selectedInterests = {};
  static const interestOptions = [
    'Food',
    'Culture & history',
    'Nature',
    'Beaches',
    'Shopping',
    'Adventure',
    'Nightlife',
    'Relaxation'
  ];
  bool get canRetryPlan => _retryPlan;
  bool get isBusy => _busy;
  String? destination, startDate, endDate, budgetLevel;
  int? travelers;
  List<String> interests = [];
  String? nextField = 'destination';
  ItineraryResponse? latestItinerary;
  final itineraryNotifier = ValueNotifier<ItineraryResponse?>(null);

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  void _bot(String text) {
    messages.add(ChatMessage.text(ChatSender.bot, text));
    _history.add(ChatTurn(role: 'assistant', content: text));
    _changed();
  }

  void _user(String text) {
    messages.add(ChatMessage.text(ChatSender.user, text));
    _history.add(ChatTurn(role: 'user', content: text));
  }

  void startIfNeeded() {
    if (_greeted) return;
    _greeted = true;
    _bot(
        "Hi, I'm Lemon! 👋 Think of me as your travel buddy with a very enthusiastic planning habit. Where are we dreaming of going?");
  }

  String _next() {
    if (destination == null) return 'destination';
    if (startDate == null || endDate == null) return 'dates';
    if (travelers == null) return 'travelers';
    if (budgetLevel == null) return 'budget_level';
    if (!_interestsAnswered) return 'interests';
    return 'confirm';
  }

  void _advance() {
    nextField = _next();
    const prompts = {
      'destination': 'Which city or region would you like to visit?',
      'dates':
          'Time to put this adventure on the calendar! Pick your arrival and departure dates below.',
      'travelers':
          'Solo adventure or bringing your favorite people? How many travelers should I plan for?',
      'budget_level':
          'Let us find out your kind of treat for this adventure! '
          'How high of a budget are we looking at? Budget-friendly journey, a little more for comfort, or a crazyyy splurge?',
      'interests':
          'Now for the fun part: what makes a trip feel like you? Pick your favorites, add your own, or let me surprise you!',
      'confirm':
          'Your adventure is taking shape! Give this trip brief a quick look, then I can turn it into a day-by-day plan.',
    };
    _bot(prompts[nextField]!);
  }

  static const greetings = [
    "Greetings! I'm Lemon! We can start whenever you're ready!",
    "Hello! Lemon here! And I'm super excited to help you start planning your travels!",
    "Hey! My imaginary suitcase is ready. Let's make room for your next adventure!",
  ];
  String get _stepReminder => switch (nextField) {
        'dates' => 'Your trip is saved. Choose your travel dates below.',
        'travelers' =>
          'Your trip is saved. Enter the number of travelers below.',
        'budget_level' => 'Choose your spending style below.',
        'interests' => 'Choose a few interests below, or add your own.',
        'confirm' => 'Your trip brief is ready to review below.',
        null => 'Your itinerary is ready to explore.',
        _ => 'Which city or region would you like to visit?',
      };
  bool _greeting(String text) => RegExp(
          r'^(hi|hello|hey|hiya|howdy|greetings|good morning|good afternoon|good evening)( there| lemon| lemon\.ai)?[!.? ]*$',
          caseSensitive: false)
      .hasMatch(text);
  bool _obviousNoise(String text) {
    final value = text.toLowerCase().trim();
    return !RegExp(r'\p{L}', unicode: true).hasMatch(value) ||
        RegExp(r'^(.)\1{4,}$', unicode: true).hasMatch(value) ||
        RegExp(r'^(asdf|qwer|zxcv|hjkl)[a-z]*$').hasMatch(value) ||
        RegExp(r'\b(write (me )?(code|an essay)|solve (this|my) (math|equation)|ignore (all|previous) instructions)\b')
            .hasMatch(value);
  }

  void _recoverInput() {
    _bot(
        "Oops, I lost the trail there! Let's try that again - your trip details are still here. $_stepReminder");
  }

  Future<void> handleUserInput(String raw) async {
    final text = raw.trim();
    if (_busy || text.isEmpty || error != null) return;
    if (text.length > 600) {
      _bot('Please keep your message under 600 characters. $_stepReminder');
      return;
    }
    if (_greeting(text)) {
      messages.add(ChatMessage.text(ChatSender.user, text));
      draft = '';
      _bot('${greetings[_greetingIndex++ % greetings.length]} $_stepReminder');
      return;
    }
    if (_obviousNoise(text) || nextField != 'destination') {
      messages.add(ChatMessage.text(ChatSender.user, text));
      draft = '';
      _recoverInput();
      return;
    }
    _user(text);
    draft = '';
    await _sendToLemon();
  }

  Future<void> _sendToLemon() async {
    _busy = true;
    error = null;
    _retryPlan = false;
    _changed();
    try {
      final result = await _api.sendChatTurn(
          messages: List.of(_history), provider: provider);
      if (_disposed) return;
      final place = result.destination?.trim();
      if (place == null || place.isEmpty || place.length > 120) {
        // Do not let rejected messages influence the next extraction attempt.
        if (_history.isNotEmpty && _history.last.role == 'user') {
          _history.removeLast();
        }
        _recoverInput();
      } else {
        destination = place;
        _bot('Ooh, $destination! Let us make this one your kind of adventure.');
        _advance();
      }
    } catch (_) {
      if (!_disposed) {
        error =
            'I couldn’t connect just now. Your message is kept. Try again when you’re ready.';
      }
    } finally {
      _busy = false;
      _changed();
    }
  }

  void setDates(DateTime start, DateTime end) {
    if (_busy) return;
    final today = DateTime.now();
    final floor = DateTime(today.year, today.month, today.day);
    if (start.isBefore(floor) ||
        end.isBefore(start) ||
        end.difference(start).inDays >= 30) {
      return;
    }
    String iso(DateTime d) =>
        '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    startDate = iso(start);
    endDate = iso(end);
    error = null;
    _user('$startDate to $endDate');
    _advance();
  }

  void setTravelers(int count) {
    if (_busy || count < 1 || count > 20) return;
    travelers = count;
    error = null;
    _user('$count traveler${count == 1 ? '' : 's'}');
    _advance();
  }

  void setBudget(String value) {
    if (_busy || !['low', 'medium', 'high'].contains(value)) return;
    budgetLevel = value;
    error = null;
    _user('Budget: $value');
    _advance();
  }

  void setInterests(List<String> values) {
    if (_busy) return;
    final clean =
        values.map((v) => v.trim()).where((v) => v.isNotEmpty).toSet().toList();
    if (clean.length > 12 || clean.any((v) => v.length > 120)) return;
    interests = clean;
    _interestsAnswered = true;
    error = null;
    selectedInterests.clear();
    otherInterests = '';
    _user(clean.isEmpty ? 'Surprise me' : clean.join(', '));
    _advance();
  }

  void editField(String field) {
    if (_busy) return;
    error = null;
    phase = ChatPhase.chatting;
    nextField = field;
    if (field == 'destination') {
      destination = null;
      _history.clear();
      _bot('Which city or region would you like to visit?');
    }
    if (field == 'interests') {
      selectedInterests
        ..clear()
        ..addAll(interests.where(interestOptions.contains));
      otherInterests = interests
          .where((value) => !interestOptions.contains(value))
          .join(', ');
    }
    _changed();
  }

  Future<void> confirmTrip() async {
    if (_busy || _next() != 'confirm') return;
    _user('Generate my itinerary');
    await _generateItinerary();
  }

  Future<void> _generateItinerary() async {
    _busy = true;
    _retryPlan = true;
    error = null;
    phase = ChatPhase.generating;
    _changed();
    try {
      final result = await _api.planTrip(TripRequest(
          destination: destination!,
          startDate: startDate!,
          endDate: endDate!,
          travelers: travelers!,
          budgetLevel: budgetLevel!,
          interests: List.of(interests),
          provider: provider));
      if (_disposed) return;
      latestItinerary = result;
      itineraryNotifier.value = result;
      phase = ChatPhase.done;
      nextField = null;
      _bot(result.providerUsed == 'mock'
          ? 'A demo itinerary is available. It is a sample, not your personalized trip. You can retry generation.'
          : 'Your adventure has a plan! Take a peek at each day - and look out for my little tips along the way. Want a different direction? You can edit your trip brief.');
    } catch (_) {
      if (!_disposed) {
        error =
            'I couldn’t finish your itinerary. Your trip details are safe here; retry without starting over.';
        phase = ChatPhase.chatting;
      }
    } finally {
      _busy = false;
      _changed();
    }
  }

  Future<void> retry() async {
    if (_busy) return;
    if (_retryPlan) {
      await _generateItinerary();
    } else {
      await _sendToLemon();
    }
  }

  void handleQuickReply(String value) {
    if (_busy) return;
    if (value == 'Plan another trip') {
      startOver();
    } else {
      handleUserInput(value);
    }
  }

  void startOver() {
    if (_busy) return;
    destination = startDate = endDate = budgetLevel = null;
    travelers = null;
    interests = [];
    _interestsAnswered = false;
    error = null;
    draft = '';
    otherInterests = '';
    selectedInterests.clear();
    messages.clear();
    _history.clear();
    phase = ChatPhase.chatting;
    nextField = 'destination';
    _bot(
        'A fresh adventure - my favorite kind of blank page! Where shall we go this time?');
  }

  @override
  void dispose() {
    _disposed = true;
    itineraryNotifier.dispose();
    super.dispose();
  }
}
