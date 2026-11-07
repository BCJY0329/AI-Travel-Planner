import 'package:flutter/foundation.dart';
import '../models/chat_models.dart';
import '../models/itinerary_models.dart';
import '../models/travel_models.dart';
import '../services/chat_settings.dart';
import '../services/lemon_api_service.dart';
import 'chat_message.dart';

export '../services/chat_settings.dart' show ChatMode;

enum ChatPhase { chatting, generating, done }

/// Why Lemon is offering the guided controls. Lemon always asks first and
/// switches only on a yes (DECISIONS 059).
enum SwitchReason { offline, stuck, unhappy }

/// Lemon's conversation. Two modes (DECISIONS 059):
/// - [ChatMode.free] (default): the traveller writes freely, `/lemon/chat`
///   reads every detail it can, and the brief shows defaults for anything
///   optional that was left out.
/// - [ChatMode.guided]: `/lemon/chat` reads only the destination; the rest is
///   picked with step-by-step controls.
class LemonChatController extends ChangeNotifier {
  LemonChatController(
      {LemonApiService? api, ChatMode? mode, ChatSettingsStore? settings})
      : _api = api ?? LemonApiService(),
        _settings = settings ?? ChatSettingsStore(),
        mode = mode ?? ChatMode.free {
    nextField = 'destination';
    if (mode == null) _loadSavedMode();
  }
  final LemonApiService _api;
  final ChatSettingsStore _settings;
  final List<ChatMessage> messages = [];
  final List<ChatTurn> _history = [];
  final String provider = 'auto';
  ChatMode mode;
  ChatPhase phase = ChatPhase.chatting;
  bool _busy = false;
  bool _disposed = false;
  bool _greeted = false;
  bool _userSpoke = false;
  int _greetingIndex = 0;
  bool _interestsAnswered = false;
  bool _retryPlan = false;
  bool _confirmTyped = false;
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
  bool get canRetryEdit => _retryEdit != null;
  bool get isBusy => _busy;

  /// What Lemon is doing while busy, when it isn't reading the chat
  /// ("Lemon is reworking day 2…").
  String? busyLabel;

  // --- Phase 2 (DECISIONS 069): pace, must-visits, popular spots, edits ---

  /// 'relaxed', 'balanced' or 'packed'; null shows "Balanced" as a default.
  String? pace;
  static const maxMustVisit = 10;
  final List<MustVisitPlace> mustVisit = [];
  // Names the traveller removed, so a re-read transcript doesn't add them back.
  final Set<String> _removedMustVisit = {};
  final Set<String> _reportedNotFound = {};

  // --- Must-visits the map couldn't find (DECISIONS 071) ---

  /// The not-found must-visit Lemon is asking about: swap it or continue
  /// without it. Nothing is planned while she waits.
  String? unfoundPlace;

  /// True once the traveller chose to swap it: spot buttons and a typed name.
  bool swappingUnfound = false;
  final List<String> _unfoundQueue = [];
  bool _unfoundAnswered = false; // one answered this round: "Next one!"
  bool _briefPending = false; // the first brief waits for the answers
  (String, String)? _pendingSwap; // (old name, typed name) sent to the chat
  bool _heldForChange = false; // a "plan it" was held once for a changed brief

  /// Lemon's popular spots for [placeName], most popular first.
  List<PopularSpot> spots = [];

  /// 'idle', 'loading', 'ready', 'none', 'too_broad' or 'unavailable'.
  String spotsStatus = 'idle';
  int _spotsToken = 0;
  bool _spotsOffered = false;
  bool _spotsAnswered = false;

  /// The traveller left the spots to Lemon ("surprise me"): she stops
  /// recommending and picks on her own, also for a new destination.
  bool spotsToLemon = false;

  /// True while the spots for the current place are still loading and Lemon
  /// has said she would show them.
  bool get findingSpots =>
      spotsStatus == 'loading' &&
      phase == ChatPhase.chatting &&
      (isFree ? !_spotsOffered && !spotsToLemon : nextField == 'must_visit');

  /// The trip behind [latestItinerary], for day edits.
  TripRequest? _lastRequest;
  PlanEdit? _retryEdit;
  PlanEdit? _chatEdit;

  /// The changed day waiting for "Use this" / "Keep old".
  EditPreview? pendingPreview;

  /// A plan with none of the must-visits in it, waiting for the traveller to
  /// say whether to see it anyway (DECISIONS 070).
  ItineraryResponse? heldPlan;
  TripRequest? _heldRequest;
  bool get isFree => mode == ChatMode.free;
  String? destination, startDate, endDate, budgetLevel;
  int? travelers;
  List<String> interests = [];
  String? nextField;

  /// Free mode: the field whose guided control is open because the traveller
  /// tapped it on the brief.
  String? editingField;

  /// Places to choose from when a name matches several ("Paris").
  List<String> destinationOptions = [];

  /// The exact place the backend resolved, e.g. 'Paris, France' (DECISIONS
  /// 068). The brief shows it, and the plan and search tabs use it.
  String? destinationLabel;

  /// Other places with the same name when Lemon picked the famous one; the
  /// brief offers them under "Not this one?".
  List<String> destinationAlternatives = [];

  /// What the brief shows and the plan uses: the exact place when known.
  String? get placeName => destinationLabel ?? destination;

  void _setPlace(String place, LemonChatResult? result, {String? label}) {
    final beforeLabel = destinationLabel, beforeName = destination;
    destination = place;
    destinationLabel = label ?? result?.destinationLabel;
    destinationAlternatives = List.of(result?.destinationAlternatives ?? []);
    destinationOptions = [];
    // A turn whose place check was unavailable has no label: that is the same
    // place, not a new one, so its must-visits stay.
    final same = beforeLabel != null && destinationLabel != null
        ? beforeLabel.toLowerCase() == destinationLabel!.toLowerCase()
        : (beforeName ?? '').toLowerCase() == place.toLowerCase();
    if (!same) _placeChanged();
  }

  void _clearPlace() {
    destination = destinationLabel = null;
    destinationAlternatives = [];
    _placeChanged(load: false);
  }

  /// A new destination: its must-visits and spots start over.
  void _placeChanged({bool load = true}) {
    mustVisit.clear();
    _removedMustVisit.clear();
    _reportedNotFound.clear();
    _clearUnfound();
    spots = [];
    spotsStatus = 'idle';
    _spotsOffered = false;
    _spotsAnswered = false;
    _spotsToken++;
    if (load && placeName != null) _loadSpots();
  }

  Future<void> _loadSpots() async {
    final place = placeName;
    if (place == null) return;
    final token = ++_spotsToken;
    spotsStatus = 'loading';
    _changed();
    final result = await _api.getPopularSpots(place, interests: interests);
    if (_disposed || token != _spotsToken) return;
    spots = result.spots;
    spotsStatus = result.status == 'ready' && result.spots.isEmpty
        ? 'none'
        : result.status;
    if (spotsToLemon && spotsStatus == 'ready' && phase == ChatPhase.chatting) {
      _usePicks(result);
    } else {
      _offerSpots();
    }
    _changed();
  }

  static const _spotsHint =
      'Tap any you\'d love to visit and I\'ll add them to your trip brief, '
      'or say “surprise me” and I\'ll pick for you! ✨';

  /// Lemon recommends spots once per destination (free mode), or at the
  /// must-visit step (guided), until the traveller leaves them to her.
  /// [beforeBrief]: called right before the brief appears, also mid-turn, so
  /// the list comes just ahead of it (DECISIONS 071).
  void _offerSpots({bool beforeBrief = false}) {
    if (phase != ChatPhase.chatting || _spotsOffered || spotsToLemon) return;
    if (!isFree && nextField != 'must_visit') return;
    // Never in the middle of a turn, a question or a plan about to start
    // (DECISIONS 071): spots that arrive late wait until the turn is done.
    if ((_busy && !beforeBrief) || unfoundPlace != null || _confirmTyped) return;
    if (_unfoundQueue.isNotEmpty) return;
    // Free text: the list waits while Lemon still asks for the destination
    // or dates; "too broad" is itself the question, so it goes at once.
    if (isFree && nextField != 'confirm' && spotsStatus != 'too_broad') return;
    if (spotsStatus == 'loading' || spotsStatus == 'idle') return;
    _spotsOffered = true;
    final place = placeName ?? 'there';
    switch (spotsStatus) {
      case 'ready':
        final text = 'Here are some popular spots in $place! 📍 $_spotsHint';
        messages.add(ChatMessage.spotList(text, spots));
        _history.add(ChatTurn(role: 'assistant', content: text));
        _changed();
      case 'too_broad':
        _bot('$place is a big place! 🌍 It\'s a bit too broad for me to find '
            'popular spots. Could you tell me a specific city or area there '
            'you\'d like to visit? ✨');
      case 'none':
        _bot("I couldn't find popular spots for $place just now. 🗺️ "
            "If there's somewhere you'd love to visit, just tell me!");
      default:
        _bot("I couldn't load popular spots right now. 🧭 "
            "If there's somewhere you'd love to visit, just type it!");
    }
  }

  /// Tap a spot button: add it to the must-visits, or take it off again.
  void toggleSpot(PopularSpot spot) {
    if (_busy || phase != ChatPhase.chatting) return;
    final index = mustVisit.indexWhere((m) => m.sameAs(spot.name, spot.placeId));
    if (index >= 0) {
      _removedMustVisit.add(mustVisit.removeAt(index).name.toLowerCase());
    } else if (mustVisit.length >= maxMustVisit) {
      _bot('I can keep up to $maxMustVisit must-visit spots. ✨ '
          'Remove one from your trip brief to add another.');
      return;
    } else {
      mustVisit.add(MustVisitPlace.fromSpot(spot));
      _removedMustVisit.remove(spot.name.toLowerCase());
      if (unfoundPlace != null && swappingUnfound) {
        _echo(spot.name);
        _bot("Got it! I've added ${spot.name} instead of $unfoundPlace. ✨");
        _resolveUnfound();
        return;
      }
    }
    _changed();
  }

  bool isMustVisit(PopularSpot spot) =>
      mustVisit.any((m) => m.sameAs(spot.name, spot.placeId));

  /// The × on a brief chip.
  void removeMustVisit(MustVisitPlace place) {
    if (_busy) return;
    if (mustVisit.remove(place)) {
      _removedMustVisit.add(place.name.toLowerCase());
      _changed();
    }
  }

  /// "Surprise me" for spots: Lemon picks, and stops recommending.
  Future<void> surpriseSpots() async {
    if (_busy || phase != ChatPhase.chatting) return;
    _echo('Surprise me');
    await _surprise();
    if (!isFree && nextField == 'must_visit') {
      _spotsAnswered = true;
      _advance();
    }
  }

  Future<void> _surprise() async {
    spotsToLemon = true;
    final place = placeName;
    if (place == null) {
      _changed();
      return;
    }
    if (spotsStatus == 'too_broad') {
      _bot('$place is a big place! 🌍 Tell me a city or area there, '
          'and I\'ll pick some spots for you. ✨');
      return;
    }
    if (spotsStatus == 'loading') {
      _bot("Leave it to me! 🍋 I'll pick a few spots as soon as I've found them.");
      return;
    }
    final result = await _api.getPopularSpots(place, interests: interests);
    if (_disposed || place != placeName) return;
    if (result.status == 'ready' && result.spots.isNotEmpty) spots = result.spots;
    _usePicks(result);
  }

  void _usePicks(SpotsResult result) {
    final picked = [
      for (final name in result.picks)
        ...result.spots.where((s) => s.name == name).take(1)
    ];
    if (picked.isEmpty) {
      _bot("I couldn't find spots to pick just now, so I'll let your itinerary "
          'choose freely. ✨');
      return;
    }
    mustVisit.removeWhere((m) => m.byLemon);
    final added = <String>[];
    for (final spot in picked) {
      if (mustVisit.length >= maxMustVisit) break;
      if (mustVisit.any((m) => m.sameAs(spot.name, spot.placeId))) continue;
      mustVisit.add(MustVisitPlace.fromSpot(spot, byLemon: true));
      added.add(spot.name);
    }
    _spotsOffered = true;
    _bot(added.isEmpty
        ? 'Those spots are already on your trip brief! 🍋'
        : 'Leave it to me! 🍋 I picked ${_join(added)} for you. You\'ll find '
            'them on your trip brief, and you can remove any you don\'t fancy. ✨');
  }

  static String _join(List<String> items) => items.length < 2
      ? items.join()
      : '${items.sublist(0, items.length - 1).join(', ')} and ${items.last}';

  /// Guided must-visit step: go on with the spots picked so far (or none).
  void confirmSpots() {
    if (_busy || nextField != 'must_visit') return;
    _spotsAnswered = true;
    _user(mustVisit.isEmpty
        ? 'No must-visit spots'
        : 'Must-visit: ${mustVisit.map((m) => m.name).join(', ')}');
    _advance();
  }

  void setPace(String value) {
    if (_busy || !const ['relaxed', 'balanced', 'packed'].contains(value)) {
      return;
    }
    pace = value;
    inferredFields.remove('pace');
    error = null;
    _user('Pace: ${paceName(value)}');
    _advance();
  }

  static String paceName(String? value) => switch (value) {
        'relaxed' => 'Relaxed',
        'packed' => 'Packed',
        _ => 'Balanced',
      };

  /// Set while Lemon is asking whether to switch to the guided controls.
  SwitchReason? switchOffer;
  final Set<SwitchReason> _declined = {};
  int _misses = 0;

  /// Fields Lemon guessed from wording ("me and my wife" -> travelers).
  final Set<String> inferredFields = {};

  ItineraryResponse? latestItinerary;

  /// The trip behind [latestItinerary], for the search tabs to follow.
  TripContext? latestTrip;
  final itineraryNotifier = ValueNotifier<ItineraryResponse?>(null);

  /// Which control the panel shows under the messages. Guided: the current
  /// step. Free: an opened brief item, the brief itself, or nothing ('chat').
  String? get controlField {
    if (heldPlan != null) return 'held_plan';
    if (unfoundPlace != null && phase == ChatPhase.chatting) return 'unfound';
    if (!isFree) return nextField;
    if (editingField != null) return editingField;
    if (nextField == 'confirm' || nextField == null) return nextField;
    return 'chat';
  }

  /// Free mode types the whole time; guided only types the destination.
  /// Once a plan exists, both type, to ask Lemon for changes (DECISIONS 069).
  bool get showsChatBox => phase == ChatPhase.chatting
      ? (isFree || nextField == 'destination')
      : phase == ChatPhase.done;

  /// Optional details the traveller left out; the brief shows defaults.
  bool isDefaulted(String field) =>
      isFree &&
      switch (field) {
        'travelers' => travelers == null,
        'budget_level' => budgetLevel == null,
        'interests' => interests.isEmpty && !_interestsAnswered,
        'pace' => pace == null,
        'must_visit' => mustVisit.isEmpty,
        _ => false,
      };

  /// Steps the progress bar shows as done.
  Set<String> get doneSteps {
    const all = {
      'destination',
      'dates',
      'travelers',
      'budget_level',
      'interests'
    };
    if (!isFree) {
      const order = [
        'destination',
        'dates',
        'travelers',
        'budget_level',
        'interests',
        'pace',
        'must_visit'
      ];
      final index = order.indexOf(nextField ?? '');
      return index < 0 ? all : order.take(index).toSet();
    }
    if (nextField == 'confirm' || nextField == null) return all;
    return {
      if (destination != null) 'destination',
      if (startDate != null && endDate != null) 'dates',
      if (travelers != null) 'travelers',
      if (budgetLevel != null) 'budget_level',
      if (interests.isNotEmpty) 'interests',
    };
  }

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  void _bot(String text) {
    messages.add(ChatMessage.text(ChatSender.bot, text));
    _history.add(ChatTurn(role: 'assistant', content: text));
    _changed();
  }

  /// A model reply: blank-line paragraphs show as separate bubbles.
  void _botReply(String text) {
    final parts = text
        .split(RegExp(r'\n\s*\n'))
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty);
    for (final part in parts) {
      messages.add(ChatMessage.text(ChatSender.bot, part));
    }
    _history.add(ChatTurn(role: 'assistant', content: text));
    _changed();
  }

  void _user(String text) {
    _userSpoke = true;
    messages.add(ChatMessage.text(ChatSender.user, text));
    _history.add(ChatTurn(role: 'user', content: text));
  }

  /// Shows the traveller's words without sending them to the model.
  void _echo(String text) {
    _userSpoke = true;
    messages.add(ChatMessage.text(ChatSender.user, text));
    draft = '';
  }

  static const _freeGreeting =
      "Hi, I'm Lemon! 🍋 Your helpful travel planning assistant! "
      'Tell me about your trip in your own words, and I will fill in the details. '
      'For example: “5 days in Kyoto from Dec 3, two of us, we love food.” ✈️';

  void startIfNeeded() {
    if (_greeted) return;
    _greeted = true;
    if (isFree) {
      _bot(_freeGreeting);
    } else {
      _bot("Hi, I'm Lemon! 🍋 Your helpful travel planning assistant! "
          "Together, we will put together the greatest adventure plan! "
          "Now tell me: Where are we thinking of going today? The sky's the limit! ✈️");
    }
  }

  Future<void> _loadSavedMode() async {
    final saved = await _settings.loadMode();
    if (_disposed || saved == null || saved == mode || _userSpoke) return;
    _applyMode(saved);
  }

  /// Before the traveller has said anything, a mode change just restarts the
  /// greeting in the new mode.
  void _applyMode(ChatMode value) {
    mode = value;
    nextField = isFree ? _freeNext() : _next();
    if (_greeted && !_userSpoke) {
      messages.clear();
      _history.clear();
      _greeted = false;
      startIfNeeded();
    }
    _changed();
  }

  /// The gear menu and plain-words requests ("switch to guided") land here.
  /// Everything collected so far is kept.
  void setMode(ChatMode value) {
    if (_busy) return;
    _switchMode(value);
  }

  void _switchMode(ChatMode value) {
    if (value == mode) return;
    _settings.saveMode(value);
    switchOffer = null;
    editingField = null;
    _clearUnfound();
    error = null;
    if (!_userSpoke) {
      _applyMode(value);
      return;
    }
    mode = value;
    if (phase != ChatPhase.chatting) {
      _changed();
      return;
    }
    if (value == ChatMode.guided) {
      _interestsAnswered = _interestsAnswered || interests.isNotEmpty;
      _bot(
          'Switched to step-by-step options! 🧭 I kept everything you told me.');
      _advance();
    } else {
      _bot(
          'Switched to free text! ✨ Tell me anything about the trip in your own words, '
          'and I will update the details.');
      nextField = _freeNext();
      if (nextField == 'confirm') _announceBrief();
      _changed();
    }
  }

  String _next() {
    if (destination == null) return 'destination';
    if (startDate == null || endDate == null) return 'dates';
    if (travelers == null) return 'travelers';
    if (budgetLevel == null) return 'budget_level';
    if (!_interestsAnswered) return 'interests';
    if (pace == null) return 'pace';
    if (!_spotsAnswered) return 'must_visit';
    return 'confirm';
  }

  String _freeNext() {
    if (destination == null) return 'destination';
    if (startDate == null || endDate == null) return 'dates';
    return 'confirm';
  }

  static const _freeAsks = {
    'destination': 'Where would you like to go? 🌍',
    'dates':
        'When are you going? 🗓️ Tell me the dates, like “Dec 3 to Dec 7” or “Dec 3 for 5 days”.',
  };

  void _advance() {
    if (isFree) {
      editingField = null;
      final before = nextField;
      nextField = _freeNext();
      if (nextField == 'confirm') {
        _bot(before == 'confirm'
            ? 'Got it! 🎯 Your trip brief is updated below.'
            : 'Got it! 🎯');
        _offerSpots(beforeBrief: true); // waited for the dates
        if (before != 'confirm') _announceBrief();
      } else {
        _bot(_freeAsks[nextField]!);
      }
      _changed();
      return;
    }
    nextField = _next();
    final prompts = {
      'destination': 'Which city or region would you like to visit? 🌍',
      'dates':
          'Time to put this adventure on the calendar! Pick your arrival and departure dates below. 🗓️',
      'travelers':
          'Solo adventure or bringing your favorite people? How many travelers should I plan for? 🎒',
      'budget_level':
          'How much are we looking to spend for this adventure? Budget-friendly? A little more for comfort? or a crazyyy splurge? 💛',
      'interests':
          'Now for the fun part: what makes a trip feel like you? Pick your favorites, add your own, or let me surprise you! ✨',
      'pace':
          'How full should each day be? Take it slow, keep it balanced, or pack in as much as we can! 🧭',
      'must_visit': spotsStatus == 'loading'
          ? 'Any places you simply have to see? 📍 Let me find some popular spots for you…'
          : 'Any places you simply have to see? 📍',
      'confirm':
          'Your adventure plan is coming together well! Give this trip brief a quick look, then I can turn it into a day-by-day plan! 🎯',
    };
    _bot(prompts[nextField]!);
    if (nextField == 'must_visit') {
      if (spotsStatus == 'idle') _loadSpots();
      _offerSpots();
    }
  }

  /// Free mode reaching the brief: say which optional details were left out
  /// and what Lemon will use, so the traveller can change them first.
  void _announceBrief() {
    final left = <(String, String)>[
      if (travelers == null) ('how many are travelling', '1 traveler'),
      if (budgetLevel == null) ('a budget', 'a Comfortable budget'),
      if (interests.isEmpty && !_interestsAnswered)
        ('interests', 'surprise-me interests'),
      if (pace == null) ('a pace', 'a Balanced pace'),
    ];
    const join = _join;
    final guessed = [
      if (inferredFields.contains('travelers') && travelers != null)
        '$travelers traveler${travelers == 1 ? '' : 's'}',
      if (inferredFields.contains('end_date') && endDate != null)
        'a trip until ${prettyDate(endDate!)}',
    ];
    final buffer = StringBuffer();
    if (guessed.isNotEmpty) {
      buffer.write('I assumed ${join(guessed)} from what you said. ');
    }
    if (left.isEmpty) {
      buffer.write('Here is your trip brief! 🎯 ');
    } else {
      buffer.write("You didn't mention ${join([for (final l in left) l.$1])}, "
          "so I'll go with ${join([for (final l in left) l.$2])}. 🎯 ");
    }
    buffer.write('Tap any detail below to change it, or just tell me. '
        'When it looks right, generate your itinerary!');
    _bot(buffer.toString());
  }

  static const _months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December'
  ];

  /// "2026-12-12" -> "12 December" for Lemon's sentences (DECISIONS 071).
  static String prettyDate(String iso) {
    final d = DateTime.tryParse(iso);
    return d == null ? iso : '${d.day} ${_months[d.month - 1]}';
  }

  static const greetings = [
    "Greetings! I'm Lemon! 🍋 We can start whenever you're ready!",
    "Hello! Lemon here! 🍋 And I'm super excited to help you start planning your travels!",
    "Hey! My imaginary suitcase is ready. Let's make room for your next adventure! 🧳",
  ];
  String get _stepReminder => isFree
      ? switch (nextField) {
          'confirm' => 'Your trip brief is ready to review below.',
          'dates' => 'When are you going? Tell me your travel dates.',
          null => 'Your itinerary is ready to explore.',
          _ => 'Tell me about your trip in your own words.',
        }
      : switch (nextField) {
          'dates' => 'Your trip is saved. Choose your travel dates below.',
          'travelers' =>
            'Your trip is saved. Enter the number of travelers below.',
          'budget_level' => 'Choose your spending style below.',
          'interests' => 'Choose a few interests below, or add your own.',
          'pace' => 'Choose how full each day should be below.',
          'must_visit' => 'Pick any must-visit spots below, or skip.',
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
    // Digits pass: "2" and "2026-12-01" are real answers in free text.
    return !RegExp(r'[\p{L}\p{N}]', unicode: true).hasMatch(value) ||
        RegExp(r'^(.)\1{4,}$', unicode: true).hasMatch(value) ||
        RegExp(r'^(asdf|qwer|zxcv|hjkl)[a-z]*$').hasMatch(value) ||
        RegExp(r'\b(write (me )?(code|an essay)|solve (this|my) (math|equation)|ignore (all|previous) instructions)\b')
            .hasMatch(value);
  }

  // Kept in step with SWITCH_TO_GUIDED_RE / SWITCH_TO_FREE_RE in
  // travel_backend/services/chat_parser.py. Checked here first, so a switch
  // costs no model call.
  static const _switchVerb =
      r'(switch|change|go|move|take me)\s+(back\s+)?to\s+(the\s+)?';
  static final wantsGuided = RegExp(
      '\\b($_switchVerb(guided|step[- ]by[- ]step|buttons|controls|options)'
      r'|guided (mode|controls|options)|step[- ]by[- ]step (mode|controls|options)'
      r'|use (the )?(guided|buttons|controls|options))\b',
      caseSensitive: false);
  static final wantsFree = RegExp(
      '\\b($_switchVerb(free[- ]?text|free mode|typing|chat(ting)?)'
      r'|free[- ]?text mode|free mode|let me (just )?type)\b',
      caseSensitive: false);

  void _recoverInput() {
    _bot(
        "Oops, I lost the trail there! 🧳 Let's try that again - your trip details are still here. $_stepReminder");
  }

  Future<void> handleUserInput(String raw) async {
    final text = raw.trim();
    if (_busy || text.isEmpty || error != null) return;
    if (text.length > 600) {
      _bot('Please keep your message under 600 characters. $_stepReminder');
      return;
    }
    if (isFree && wantsGuided.hasMatch(text)) {
      _echo(text);
      setMode(ChatMode.guided);
      return;
    }
    if (!isFree && wantsFree.hasMatch(text)) {
      _echo(text);
      setMode(ChatMode.free);
      return;
    }
    if (_greeting(text)) {
      _echo(text);
      _bot('${greetings[_greetingIndex++ % greetings.length]} $_stepReminder');
      return;
    }
    if (heldPlan != null) {
      _echo(text);
      if (_yes.hasMatch(text)) {
        _showHeldPlan();
      } else if (_no.hasMatch(text)) {
        _stopHere();
      } else {
        _bot('Shall I show the plan without them? Just say yes or no. 🍋');
      }
      return;
    }
    if (unfoundPlace != null && phase == ChatPhase.chatting && isFree) {
      // Lemon asked about a must-visit she couldn't find (DECISIONS 071).
      if (_continueWords.hasMatch(text)) {
        _echo(text);
        _continueWithout();
        return;
      }
      if (!swappingUnfound && _swapWords.hasMatch(text)) {
        _echo(text);
        _openSwap();
        return;
      }
      if (swappingUnfound && !_obviousNoise(text)) {
        // The typed name is checked on the map like any must-visit.
        _userSpoke = true;
        messages.add(ChatMessage.text(ChatSender.user, text));
        _history.add(ChatTurn(
            role: 'user',
            content: 'Instead of $unfoundPlace, we must visit $text.'));
        draft = '';
        _pendingSwap = (unfoundPlace!, text);
        await _sendToLemon();
        return;
      }
      // Anything else is an ordinary message; Lemon asks again after it.
    }
    if (phase == ChatPhase.done) {
      // Lemon helps with the plan: edits and questions (DECISIONS 069).
      if (_obviousNoise(text)) {
        _echo(text);
        _bot("Oops, I didn't catch that! 🍋 $_stepReminder");
        return;
      }
      _user(text);
      draft = '';
      await _sendToLemon();
      return;
    }
    if (isFree) {
      switchOffer = null;
      if (_obviousNoise(text)) {
        _echo(text);
        _bot("Oops, I didn't catch that! 🍋 $_stepReminder");
        return;
      }
      _user(text);
      draft = '';
      await _sendToLemon();
      return;
    }
    if (_obviousNoise(text) || nextField != 'destination') {
      _echo(text);
      _recoverInput();
      return;
    }
    _user(text);
    draft = '';
    await _sendToLemon();
  }

  void _dropLastUserTurn() {
    // Rejected messages must not influence the next extraction attempt. A
    // spots message may have arrived after it, so it isn't always last.
    final index = _history.lastIndexWhere((t) => t.role == 'user');
    if (index >= 0) _history.removeAt(index);
  }

  Future<void> _sendToLemon() async {
    _busy = true;
    error = null;
    _retryPlan = false;
    _changed();
    try {
      final plan = phase == ChatPhase.done ? latestItinerary : null;
      final result = await _api.sendChatTurn(
          messages: List.of(_history),
          provider: provider,
          planSummary: plan == null ? null : planSummary(plan),
          planDays: plan?.days.length);
      if (_disposed) return;
      if (plan != null) {
        _applyAfterPlan(result);
      } else if (isFree) {
        _applyFree(result);
      } else {
        _applyGuided(result);
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
    if (!_confirmTyped && !_disposed && phase == ChatPhase.chatting) {
      _offerSpots(); // spots that arrived during the turn
    }
    if (_confirmTyped && !_disposed) {
      _confirmTyped = false;
      await _startPlan();
    }
    final edit = _chatEdit;
    if (edit != null && !_disposed) {
      _chatEdit = null;
      await requestEdit(edit);
    }
  }

  static final _yes = RegExp(
      r'^\W*(yes|yeah|yep|yup|sure|ok(ay)?|go ahead|continue|show( me)?( it| the plan)?|please do)\b',
      caseSensitive: false);
  static final _no = RegExp(
      r'^\W*(no|nope|nah|stop|cancel|don.?t|never ?mind)\b',
      caseSensitive: false);

  /// "Yes, show my plan": the plan already written, without the must-visits.
  void continueWithoutMissing() {
    if (_busy || heldPlan == null) return;
    _echo('Yes, show my plan');
    _showHeldPlan();
  }

  /// "No, stop here": Lemon stops; the brief stays for another go.
  void stopHere() {
    if (_busy || heldPlan == null) return;
    _echo('No, stop here');
    _stopHere();
  }

  void _showHeldPlan() {
    final plan = heldPlan!, request = _heldRequest!;
    heldPlan = _heldRequest = null;
    _showPlan(plan, request);
  }

  void _stopHere() {
    heldPlan = _heldRequest = null;
    _bot("Okay, I've stopped here. 😊 Your trip brief is still below, so you can "
        'change your must-visits or try again whenever you like.');
  }

  static const _afterPlanTrip =
      'If you\'d like to change the trip itself, tap “Edit trip details” below '
      'and I\'ll plan it again. I can also regenerate a day, swap an activity '
      'or adjust a day for you, just tell me! ✨';

  void _applyAfterPlan(LemonChatResult result) {
    switch (result.intent) {
      case 'edit_plan':
        _botReply(result.reply);
        _chatEdit = result.edit;
      case 'gibberish' || 'unsafe' || 'off_topic':
        _dropLastUserTurn();
        _botReply(result.reply);
      case 'trip':
        _bot(_afterPlanTrip);
      case 'switch_to_guided':
        _switchMode(ChatMode.guided);
      case 'switch_to_free':
        _switchMode(ChatMode.free);
      default:
        _botReply(result.reply);
    }
  }

  /// The plan as numbered lines, so Lemon can read "swap stop 2 on day 3".
  static String planSummary(ItineraryResponse plan) {
    final buffer = StringBuffer();
    for (final day in plan.days) {
      buffer.writeln('Day ${day.day}${day.date == null ? '' : ' (${day.date})'}:');
      for (final (i, a) in day.activities.indexed) {
        buffer.writeln('  ${i + 1}. ${a.time} ${a.activity}'
            '${a.location == null ? '' : ' (${a.location})'}');
      }
    }
    final text = buffer.toString().trim();
    return text.length > 7900 ? text.substring(0, 7900) : text;
  }

  static String describeEdit(PlanEdit edit) => switch (edit.action) {
        'swap_activity' => 'Swap stop ${edit.stop} on day ${edit.day}',
        'adjust_day' => 'Day ${edit.day}: ${edit.instruction ?? ''}'.trim(),
        _ => 'Regenerate day ${edit.day}',
      };

  /// Change one day (DECISIONS 069): from Lemon reading the chat, or from the
  /// buttons on the itinerary ([fromButton] shows what was asked). The new day
  /// is previewed; the plan only changes on "Use this".
  Future<void> requestEdit(PlanEdit edit, {bool fromButton = false}) async {
    final plan = latestItinerary, trip = _lastRequest;
    if (_busy || plan == null || trip == null) return;
    final old = plan.days.where((d) => d.day == edit.day).firstOrNull;
    if (old == null) return;
    if (fromButton) _user(describeEdit(edit));
    if (plan.providerUsed == 'mock') {
      _bot("This is a demo plan, so I can't edit its days. 🍋 Retry personalized "
          'generation first, then I can tweak any day!');
      return;
    }
    if (pendingPreview != null) {
      pendingPreview!.state = 'kept';
      pendingPreview = null;
    }
    _busy = true;
    error = null;
    _retryEdit = edit;
    busyLabel = edit.action == 'swap_activity'
        ? 'Lemon is finding a new stop ${edit.stop} for day ${edit.day}…'
        : 'Lemon is reworking day ${edit.day}…';
    _changed();
    try {
      final result =
          await _api.editPlan(trip: trip, days: plan.days, edit: edit);
      if (_disposed) return;
      _retryEdit = null;
      final preview = EditPreview(
          edit: edit,
          oldDay: old,
          newDay: result.day,
          providerUsed: result.providerUsed,
          missingMustVisits: result.missingMustVisits);
      pendingPreview = preview;
      final lost = result.missingMustVisits;
      final text = edit.action == 'swap_activity'
          ? "Here's a new stop ${edit.stop} for day ${edit.day}! ✨ Shall I use it?"
          : lost.isEmpty
              ? "Here's my new take on day ${edit.day}! ✨ Shall I use it?"
              : "Here's my new take on day ${edit.day}, but I couldn't keep "
                  '${_join(lost)} on it. 🍋 Shall I use it anyway?';
      messages.add(ChatMessage.editPreview(text, preview));
      _history.add(ChatTurn(role: 'assistant', content: text));
    } catch (_) {
      if (!_disposed) {
        error = "I couldn't change day ${edit.day} right now. 🍋 Your plan is "
            'unchanged. Try again when you\'re ready.';
      }
    } finally {
      _busy = false;
      busyLabel = null;
      _changed();
    }
  }

  /// "Use this" on an edit preview: the new day replaces the old one.
  void acceptEdit() {
    final preview = pendingPreview, plan = latestItinerary;
    if (_busy || preview == null || plan == null) return;
    preview.state = 'accepted';
    pendingPreview = null;
    final updated = plan.withDay(preview.newDay);
    latestItinerary = updated;
    itineraryNotifier.value = updated;
    _echo('Use this');
    _bot('Done! ✨ Day ${preview.edit.day} is updated in your itinerary.');
  }

  /// "Keep old" on an edit preview.
  void keepOldDay() {
    final preview = pendingPreview;
    if (_busy || preview == null) return;
    preview.state = 'kept';
    pendingPreview = null;
    _echo('Keep old');
    _bot('No problem! 😊 I kept day ${preview.edit.day} just as it was.');
  }

  /// "Keep my plan" after a failed edit.
  void dismissError() {
    if (_busy) return;
    error = null;
    _retryEdit = null;
    _changed();
  }

  void _applyGuided(LemonChatResult result) {
    final place = result.destination?.trim();
    if (result.destinationStatus == 'ambiguous' &&
        result.destinationOptions.isNotEmpty) {
      _dropLastUserTurn();
      destinationOptions = List.of(result.destinationOptions);
      _bot(result.reply);
    } else if (result.destinationStatus == 'not_found') {
      _dropLastUserTurn();
      _bot(result.reply);
    } else if (place == null || place.isEmpty || place.length > 120) {
      _dropLastUserTurn();
      _recoverInput();
    } else {
      _setPlace(place, result);
      _bot('Ooh, $placeName! Let us make this one your kind of adventure. ✨');
      _advance();
    }
  }

  static bool _validRange(String? start, String? end) {
    final s = DateTime.tryParse(start ?? ''), e = DateTime.tryParse(end ?? '');
    if (s == null || e == null) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return !s.isBefore(today) && !e.isBefore(s) && e.difference(s).inDays < 30;
  }

  void _applyFree(LemonChatResult result) {
    final before = nextField;
    final swap = _pendingSwap;
    _pendingSwap = null;
    switch (result.intent) {
      case 'switch_to_guided':
        _switchMode(ChatMode.guided);
        return;
      case 'gibberish' || 'unsafe' || 'off_topic':
        _dropLastUserTurn();
        _botReply(result.reply);
        return;
    }
    // The backend re-reads the whole transcript each turn; a value it now
    // leaves out keeps what the app already has.
    final briefBefore = _briefKey();
    final namesBefore = {for (final m in mustVisit) m.name.toLowerCase()};
    final status = result.destinationStatus;
    final place = result.destination?.trim();
    if (status == 'ambiguous' && result.destinationOptions.isNotEmpty) {
      destinationOptions = List.of(result.destinationOptions);
    } else if (place != null &&
        place.isNotEmpty &&
        place.length <= 120 &&
        status != 'not_found') {
      _setPlace(place, result);
    }
    if (result.startDate != null) {
      if (result.endDate == null) {
        startDate = result.startDate;
        endDate = null;
      } else if (_validRange(result.startDate, result.endDate)) {
        startDate = result.startDate;
        endDate = result.endDate;
      }
    }
    void mark(String field, bool provided) {
      if (!provided) return;
      if (result.inferred.contains(field)) {
        inferredFields.add(field);
      } else {
        inferredFields.remove(field);
      }
    }

    final count = result.travelers;
    if (count != null && count >= 1 && count <= 20) travelers = count;
    mark('travelers', count != null);
    if (const ['low', 'medium', 'high'].contains(result.budgetLevel)) {
      budgetLevel = result.budgetLevel;
    }
    final picked = result.interests
        .map((v) => v.trim())
        .where((v) => v.isNotEmpty && v.length <= 120)
        .toSet()
        .take(12)
        .toList();
    if (picked.isNotEmpty) interests = picked;
    mark('interests', picked.isNotEmpty);
    mark('end_date', result.endDate != null);
    if (result.pace != null) pace = result.pace;
    mark('pace', result.pace != null);
    final notFound = _mergeMustVisits(result.mustVisit);
    final added = [
      for (final m in mustVisit)
        if (!namesBefore.contains(m.name.toLowerCase())) m.name
    ];
    nextField = _freeNext();
    final firstBrief = nextField == 'confirm' && before != 'confirm';

    if (swap != null && unfoundPlace == swap.$1) {
      _afterSwap(swap.$1, added, notFound, firstBrief);
      return;
    }

    if (swap == null && unfoundPlace != null && added.isEmpty &&
        notFound.isNotEmpty) {
      // A place typed in answer that the map doesn't know either: say so, and
      // open the swap so the spot buttons show.
      swappingUnfound = true;
      _bot("I couldn't find ${_join(notFound)} near ${placeName ?? 'there'} "
          'either. 🗺️ Try another name, tap a spot, or continue without it.');
      return;
    }
    if (swap == null && unfoundPlace != null && added.isNotEmpty) {
      // A place typed in answer without tapping Swap counts as the swap.
      _unfoundQueue.addAll(notFound);
      if (firstBrief) _briefPending = true;
      _heldForChange = false;
      _bot("Got it! I've added ${_join(added)} instead of $unfoundPlace. ✨");
      _resolveUnfound();
      if (result.spotsToLemon) _surprise();
      return;
    }

    // DECISIONS 071: "plan it" starts the plan only when the brief was
    // showing, the message changed nothing, and nothing is waiting to be
    // asked. Otherwise Lemon asks, or shows the brief, and waits. While she
    // holds the plan, her own words replace the model's "let me plan it".
    _unfoundQueue.addAll(notFound);
    if (unfoundPlace != null || _unfoundQueue.isNotEmpty) {
      if (firstBrief) _briefPending = true;
      _heldForChange = false;
      final asking = unfoundPlace != null;
      final some = _unfoundQueue.length + (asking ? 1 : 0) > 1
          ? 'some questions'
          : 'a question';
      if (asking) {
        _bot(result.ready
            ? 'Sure thing! But before that, I still need your answer about '
                'one place. 🍋'
            : briefBefore != _briefKey()
                ? "Got it, I've updated your trip! ✨ One thing first:"
                : 'Before we go on, I still need your answer about one place. 🍋');
        _askUnfound();
      } else {
        _bot(result.ready
            ? 'Sure thing! But before that, I have $some: 🍋'
            : 'Got it! ✨ Before we go on, I have $some:');
        _askNextUnfound();
      }
      if (result.spotsToLemon) _surprise();
      return;
    }

    if (result.ready && before == 'confirm' && nextField == 'confirm') {
      if (briefBefore != _briefKey() && !_heldForChange) {
        // Only once: a second "go ahead" plans even if the model re-reads a
        // value differently.
        _heldForChange = true;
        _bot("Sure thing! I've updated your trip. 🎯 Here's the new brief. "
            'Have a look first, then tap Generate or say go ahead.');
        if (result.spotsToLemon) _surprise();
        return;
      }
      _heldForChange = false;
      _botReply(result.reply);
      if (result.spotsToLemon) _surprise();
      _confirmTyped = true;
      return;
    }
    _heldForChange = false;
    if (result.ready && firstBrief) {
      _bot('Sure thing! Let me show you your trip brief first. 🎯');
    } else {
      _botReply(result.reply);
    }
    if (result.spotsToLemon) _surprise();
    if (firstBrief) {
      _offerSpots(beforeBrief: true);
      _announceBrief();
    }
    // Ask first, never switch on our own.
    _misses =
        result.intent == 'trip' && nextField != 'confirm' && nextField == before
            ? _misses + 1
            : 0;
    if (result.fallbackUsed) {
      _offerSwitch(SwitchReason.offline);
    } else if (result.intent == 'unhappy') {
      _offerSwitch(SwitchReason.unhappy);
    } else if (_misses >= 2) {
      _offerSwitch(SwitchReason.stuck);
    }
  }

  /// Typed must-visits join the brief; ones the map didn't know are named
  /// once. Removed ones stay removed (the transcript is re-read each turn).
  String _latestUserText() =>
      (_history.lastWhere((t) => t.role == 'user',
                  orElse: () => ChatTurn(role: 'user', content: ''))
              .content)
          .toLowerCase();

  List<String> _mergeMustVisits(List<MustVisitPlace> found) {
    final notFound = <String>[];
    var full = false;
    for (final place in found) {
      final key = place.name.toLowerCase();
      if (mustVisit.any((m) => m.sameAs(place.name, place.placeId)) ||
          _removedMustVisit.contains(key)) {
        continue;
      }
      if (place.status == 'not_found') {
        // Named once, then again only when the latest message names it
        // (DECISIONS 071): a skipped place typed anew is asked about again.
        final waiting = unfoundPlace?.toLowerCase() == key ||
            _unfoundQueue.any((n) => n.toLowerCase() == key);
        if (_reportedNotFound.add(key) ||
            (!waiting && _latestUserText().contains(key))) {
          if (!notFound.any((n) => n.toLowerCase() == key)) {
            notFound.add(place.name);
          }
        }
        continue;
      }
      if (mustVisit.length >= maxMustVisit) {
        full = true;
        continue;
      }
      mustVisit.add(place);
    }
    if (full) {
      _bot('I can keep up to $maxMustVisit must-visit spots. ✨ '
          'Remove one from your trip brief to add another.');
    }
    return notFound;
  }

  /// The brief's values, to tell whether a message changed the trip.
  String _briefKey() => [
        placeName,
        startDate,
        endDate,
        travelers,
        budgetLevel,
        pace,
        (interests.map((i) => i.toLowerCase()).toList()..sort()).join(','),
        (mustVisit.map((m) => m.name.toLowerCase()).toList()..sort()).join(','),
      ].join('|');

  static final _continueWords = RegExp(
      r'\b(skip( it)?|continue without|without (it|them)|leave (it|that) out|'
      r'drop it|forget (about )?it|never ?mind)\b|^\W*(no|nope|nah|continue)\W*$',
      caseSensitive: false);
  static final _swapWords = RegExp(
      r'^\W*(yes,? )?(swap|replace|change)( it)?( please)?\W*$',
      caseSensitive: false);

  void _clearUnfound() {
    unfoundPlace = null;
    _pendingSwap = null;
    swappingUnfound = _unfoundAnswered = _briefPending = false;
    _unfoundQueue.clear();
  }

  void _askNextUnfound() {
    unfoundPlace = _unfoundQueue.removeAt(0);
    swappingUnfound = false;
    _bot("${_unfoundAnswered ? 'Next one! ' : ''}I couldn't find $unfoundPlace "
        'near ${placeName ?? 'there'} on the map. 🗺️ Would you like to swap it '
        'for another place, or continue without it?');
  }

  /// The question again, after a message that didn't answer it.
  void _askUnfound() => _bot(swappingUnfound
      ? 'Which place would you like instead of $unfoundPlace? 📍 Tap a spot, '
          'type a name, or continue without it.'
      : 'Would you like to swap $unfoundPlace for another place, or continue '
          'without it? 🗺️');

  /// "Swap it": the city's spots as buttons, or a typed name.
  void swapUnfound() {
    if (_busy || unfoundPlace == null || swappingUnfound) return;
    _echo('Swap it');
    _openSwap();
  }

  void _openSwap() {
    swappingUnfound = true;
    // The buttons here are for the swap; the full list still comes once,
    // right before the brief, after every question is answered.
    final ready = spotsStatus == 'ready' && spots.isNotEmpty;
    _bot(ready
        ? 'Sure! 📍 Pick one of the popular spots below, or type the name of '
            'another place.'
        : "Sure! 📍 Type the name of the place you'd like instead.");
  }

  /// "Continue without it".
  void continueWithoutUnfound() {
    if (_busy || unfoundPlace == null) return;
    _echo('Continue without it');
    _continueWithout();
  }

  void _continueWithout() {
    _bot("No problem! I'll leave $unfoundPlace out. ✨");
    _resolveUnfound();
  }

  void _afterSwap(String old, List<String> added, List<String> notFound,
      bool firstBrief) {
    if (firstBrief) _briefPending = true;
    if (added.isNotEmpty) {
      _bot("Got it! I've added ${_join(added)} instead of $old. ✨");
      _resolveUnfound();
    } else if (notFound.isNotEmpty) {
      _bot("I couldn't find ${_join(notFound)} near ${placeName ?? 'there'} "
          'either. 🗺️ Try another name, tap a spot, or continue without it.');
    } else {
      _bot("Hmm, I couldn't catch a place name there. 🍋 Type the place you'd "
          'like instead of $old, or continue without it.');
    }
  }

  /// One question answered: the next one, or the brief to confirm. Never a
  /// plan on its own (DECISIONS 071).
  void _resolveUnfound() {
    unfoundPlace = null;
    swappingUnfound = false;
    _unfoundAnswered = true;
    if (_unfoundQueue.isNotEmpty) {
      _askNextUnfound();
      return;
    }
    _unfoundAnswered = false;
    nextField = _freeNext();
    if (nextField != 'confirm') {
      _bot(_freeAsks[nextField]!);
    } else {
      // Every place is cleared up: the spot list, then the brief.
      _bot('All set! 🎯');
      _offerSpots(beforeBrief: true);
      if (_briefPending) {
        _announceBrief();
      } else {
        _bot("Here's your updated brief. Have a look, then tap Generate or "
            'say go ahead.');
      }
    }
    _briefPending = false;
    _changed();
  }

  void _offerSwitch(SwitchReason reason) {
    if (!isFree || _declined.contains(reason)) return;
    switchOffer = reason;
    _bot(switch (reason) {
      SwitchReason.offline =>
        'My smart reading is offline right now, so I might miss some details. 🧭 '
            'Want to switch to step-by-step options instead?',
      SwitchReason.stuck =>
        "I'm having trouble with that one. 🧭 Want to switch to step-by-step options instead?",
      SwitchReason.unhappy =>
        'Want to switch to step-by-step options instead? 🧭 You can pick each detail yourself.',
    });
  }

  /// "Switch to guided" on Lemon's offer.
  void acceptSwitch() {
    if (_busy || switchOffer == null) return;
    _echo('Switch to guided');
    setMode(ChatMode.guided);
  }

  /// "Keep typing" on Lemon's offer: no more offers for the same reason.
  void declineSwitch() {
    if (_busy || switchOffer == null) return;
    _declined.add(switchOffer!);
    switchOffer = null;
    _misses = 0;
    _echo('Keep typing');
    _bot('Sure, keep typing! ✨ $_stepReminder');
  }

  /// One of the places offered for an ambiguous name, or one of the
  /// "Not this one?" alternatives on the brief (DECISIONS 068).
  void pickDestination(String label) {
    if (_busy ||
        !(destinationOptions.contains(label) ||
            destinationAlternatives.contains(label))) {
      return;
    }
    _setPlace(label, null, label: label);
    error = null;
    _user(label);
    if (isFree) {
      final before = nextField;
      nextField = _freeNext();
      if (nextField == 'confirm') {
        _bot('$label it is! ✨');
        if (before != 'confirm') _announceBrief();
      } else {
        _bot('$label it is! ✨ ${_freeAsks[nextField]}');
      }
      _changed();
    } else {
      _bot('Ooh, $destination! Let us make this one your kind of adventure. ✨');
      _advance();
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
    inferredFields.remove('end_date');
    error = null;
    _user('$startDate to $endDate');
    _advance();
  }

  void setTravelers(int count) {
    if (_busy || count < 1 || count > 20) return;
    travelers = count;
    inferredFields.remove('travelers');
    error = null;
    _user('$count traveler${count == 1 ? '' : 's'}');
    _advance();
  }

  void setBudget(String value) {
    if (_busy || !['low', 'medium', 'high'].contains(value)) return;
    budgetLevel = value;
    error = null;
    final display = switch (value) {
      'low' => 'Budget-friendly',
      'medium' => 'Comfortable',
      'high' => 'Premium',
      _ => value,
    };
    _user('Budget: $display');
    _advance();
  }

  void setInterests(List<String> values) {
    if (_busy) return;
    final clean =
        values.map((v) => v.trim()).where((v) => v.isNotEmpty).toSet().toList();
    if (clean.length > 12 || clean.any((v) => v.length > 120)) return;
    interests = clean;
    _interestsAnswered = true;
    inferredFields.remove('interests');
    error = null;
    selectedInterests.clear();
    otherInterests = '';
    _user(clean.isEmpty ? 'Surprise me' : clean.join(', '));
    _advance();
  }

  /// Free mode: close an opened brief item without changing it.
  void cancelEdit() {
    if (_busy || editingField == null) return;
    editingField = null;
    _changed();
  }

  void _prepareInterests() {
    selectedInterests
      ..clear()
      ..addAll(interests.where(interestOptions.contains));
    otherInterests =
        interests.where((value) => !interestOptions.contains(value)).join(', ');
  }

  void editField(String field) {
    if (_busy) return;
    error = null;
    heldPlan = _heldRequest = null; // changing the brief answers "no"
    phase = ChatPhase.chatting;
    switchOffer = null;
    if (isFree) {
      editingField = null;
      if (field == 'destination') {
        _clearPlace();
        nextField = 'destination';
        _bot('Where would you like to go instead? 🌍');
      } else if (field == 'confirm') {
        nextField = _freeNext();
      } else {
        editingField = field;
        if (field == 'interests') _prepareInterests();
      }
      _changed();
      return;
    }
    nextField = field;
    if (field == 'destination') {
      _clearPlace();
      _history.clear();
      _bot('Which city or region would you like to visit?');
    }
    if (field == 'interests') _prepareInterests();
    _changed();
  }

  Future<void> confirmTrip() async {
    if (_busy || unfoundPlace != null) return;
    if (isFree ? _freeNext() != 'confirm' : _next() != 'confirm') return;
    _user('Generate my itinerary');
    await _startPlan();
  }

  Future<void> _startPlan() async {
    if (isFree) {
      // The defaults the brief showed become the plan's values.
      travelers ??= 1;
      budgetLevel ??= 'medium';
      pace ??= 'balanced';
      _interestsAnswered = true;
      editingField = null;
    }
    switchOffer = null;
    _heldForChange = false;
    await _generateItinerary();
  }

  Future<void> _generateItinerary() async {
    _busy = true;
    _retryPlan = true;
    error = null;
    phase = ChatPhase.generating;
    _changed();
    try {
      final request = TripRequest(
          // The exact place, so the plan never geocodes the wrong Paris.
          destination: placeName!,
          startDate: startDate!,
          endDate: endDate!,
          travelers: travelers!,
          budgetLevel: budgetLevel!,
          interests: List.of(interests),
          pace: pace ?? 'balanced',
          mustVisit: List.of(mustVisit),
          provider: provider);
      final result = await _api.planTrip(request);
      if (_disposed) return;
      final missing = result.missingMustVisits.map((n) => n.toLowerCase());
      final noneFit = request.mustVisit.isNotEmpty &&
          result.providerUsed != 'mock' &&
          request.mustVisit.every((m) => missing.contains(m.name.toLowerCase()));
      if (noneFit) {
        // Ask first (DECISIONS 070): the plan is ready, but without any of
        // the places the traveller asked for.
        heldPlan = result;
        _heldRequest = request;
        _retryPlan = false;
        final names = result.missingMustVisits;
        _bot("I couldn't fit ${_join(names)} into your plan, even after trying "
            'all my planners. 🍋 Would you like to see the plan without '
            '${names.length == 1 ? 'it' : 'them'}?');
        phase = ChatPhase.chatting;
        return;
      }
      _showPlan(result, request);
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

  void _showPlan(ItineraryResponse result, TripRequest request) {
    latestItinerary = result;
    _lastRequest = request;
    pendingPreview = null;
    latestTrip = TripContext(
        destination: request.destination,
        startDate: DateTime.parse(request.startDate),
        travelers: request.travelers);
    itineraryNotifier.value = result;
    phase = ChatPhase.done;
    nextField = null;
    final missing = result.missingMustVisits;
    _bot(result.providerUsed == 'mock'
        ? 'A demo itinerary is available. It is a sample, not your personalized trip. You can retry generation.'
        : 'Your adventure has a plan! 🎉 Take a peek at each day - and look out for my little tips along the way. '
            '${missing.isEmpty ? '' : "I couldn't fit ${_join(missing)} in this time. "}'
            'Want to change something? Just tell me, like “make day 2 more relaxed”, or use the buttons on each day.');
    _changed();
  }

  Future<void> retry() async {
    if (_busy) return;
    final edit = _retryEdit;
    if (edit != null) {
      await requestEdit(edit);
      return;
    }
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
    _clearPlace();
    travelers = null;
    interests = [];
    _interestsAnswered = false;
    error = null;
    draft = '';
    otherInterests = '';
    selectedInterests.clear();
    inferredFields.clear();
    destinationOptions = [];
    pace = null;
    spotsToLemon = false;
    heldPlan = _heldRequest = null;
    _clearUnfound();
    _heldForChange = false;
    _retryEdit = _chatEdit = null;
    pendingPreview = null;
    switchOffer = null;
    editingField = null;
    _misses = 0;
    messages.clear();
    _history.clear();
    phase = ChatPhase.chatting;
    nextField = 'destination';
    _bot(isFree
        ? 'A fresh adventure - my favorite kind of blank page! 🍋 Tell me about the next trip in your own words.'
        : 'A fresh adventure - my favorite kind of blank page! 🍋 Where shall we go this time?');
  }

  @override
  void dispose() {
    _disposed = true;
    itineraryNotifier.dispose();
    super.dispose();
  }
}
