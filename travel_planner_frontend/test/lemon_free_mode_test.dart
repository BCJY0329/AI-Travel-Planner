// Free-text mode, the ask-first fallback and the mode setting (DECISIONS 059).
// Fake services only; never a live backend.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travel_planner_frontend/chat/lemon_chat_controller.dart';
import 'package:travel_planner_frontend/models/chat_models.dart';
import 'package:travel_planner_frontend/models/itinerary_models.dart';
import 'package:travel_planner_frontend/services/chat_settings.dart';
import 'package:travel_planner_frontend/services/lemon_api_service.dart';
import 'package:travel_planner_frontend/widgets/lemon_chat_panel.dart';

class QueueLemonApi extends LemonApiService {
  // Phase 2 calls (DECISIONS 069), offline.
  SpotsResult spots = const SpotsResult(status: 'none', destination: '');
  final List<PlanEdit> edits = [];
  PlanEditResult? editResult;
  @override
  Future<SpotsResult> getPopularSpots(String destination,
          {List<String> interests = const []}) async =>
      spots;

  @override
  Future<PlanEditResult> editPlan(
      {required TripRequest trip,
      required List<ItineraryDay> days,
      required PlanEdit edit}) async {
    edits.add(edit);
    final result = editResult;
    if (result == null) throw Exception('offline');
    return result;
  }
  final List<LemonChatResult> replies = [];
  final List<List<ChatTurn>> histories = [];
  TripRequest? planned;
  int get chats => histories.length;

  @override
  Future<LemonChatResult> sendChatTurn(
      {required List<ChatTurn> messages,
      required String provider,
      String? planSummary,
      int? planDays}) async {
    histories.add(List.of(messages));
    return replies.isEmpty
        ? LemonChatResult(reply: 'Tell me more!')
        : replies.removeAt(0);
  }

  @override
  Future<ItineraryResponse> planTrip(TripRequest value) async {
    planned = value;
    return ItineraryResponse(
        destination: value.destination,
        providerUsed: 'groq',
        days: [
          ItineraryDay(
              day: 1,
              date: value.startDate,
              activities: [ItineraryActivity(time: '09:00', activity: 'Walk')])
        ]);
  }
}

String iso(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
final start = DateUtils.dateOnly(DateTime.now()).add(const Duration(days: 20));
final startIso = iso(start), endIso = iso(start.add(const Duration(days: 3)));

LemonChatResult tokyo(
        {int? travelers,
        String? budget,
        List<String> interests = const [],
        List<String> inferred = const [],
        bool ready = false,
        bool fallback = false,
        String intent = 'trip'}) =>
    LemonChatResult(
        reply: 'Tokyo in December, lovely!',
        destination: 'Tokyo',
        startDate: startIso,
        endDate: endIso,
        travelers: travelers,
        budgetLevel: budget,
        interests: interests,
        inferred: inferred,
        destinationStatus: 'verified',
        ready: ready,
        fallbackUsed: fallback,
        intent: intent,
        nextField: 'confirm');

bool said(LemonChatController c, String text) =>
    c.messages.any((m) => m.text?.contains(text) == true);

LemonChatController free(QueueLemonApi api, [MemoryChatSettingsStore? store]) {
  final c = LemonChatController(
      api: api,
      mode: ChatMode.free,
      settings: store ?? MemoryChatSettingsStore());
  c.startIfNeeded();
  return c;
}

Future<void> pumpPanel(WidgetTester tester, LemonChatController c,
    {double width = 800}) async {
  tester.view.physicalSize = Size(width, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(MaterialApp(
      home: Scaffold(
          body: Center(
              child: SizedBox(
                  width: width < 500 ? width : 420,
                  height: 900,
                  child: LemonChatPanel(controller: c, onClose: () {}))))));
  await tester.pumpAndSettle();
}

void main() {
  test('Free text is the default mode and greets with an example', () {
    final c = LemonChatController(
        api: QueueLemonApi(), settings: MemoryChatSettingsStore());
    addTearDown(c.dispose);
    c.startIfNeeded();
    expect(c.mode, ChatMode.free);
    expect(said(c, 'in your own words'), isTrue);
    expect(c.showsChatBox, isTrue);
  });

  test('A saved mode is restored before the traveller speaks', () async {
    final c = LemonChatController(
        api: QueueLemonApi(),
        settings: MemoryChatSettingsStore(ChatMode.guided));
    addTearDown(c.dispose);
    c.startIfNeeded();
    await Future<void>.delayed(Duration.zero);
    expect(c.mode, ChatMode.guided);
    expect(c.messages, hasLength(1));
    expect(said(c, 'Where are we thinking of going'), isTrue);
  });

  test('One message fills the brief; left-out details get defaults', () async {
    final api = QueueLemonApi()..replies.add(tokyo(interests: ['Food']));
    final c = free(api);
    addTearDown(c.dispose);
    await c.handleUserInput('4 days in Tokyo from Dec 3, we love ramen');
    expect(
        (c.destination, c.startDate, c.endDate), ('Tokyo', startIso, endIso));
    expect(c.nextField, 'confirm');
    expect(c.isDefaulted('travelers'), isTrue);
    expect(c.isDefaulted('budget_level'), isTrue);
    expect(c.isDefaulted('interests'), isFalse);
    expect(
        said(c,
            "You didn't mention how many are travelling, a budget and a pace, so I'll go with 1 traveler, a Comfortable budget and a Balanced pace."),
        isTrue);
    await c.confirmTrip();
    expect(api.planned!.travelers, 1);
    expect(api.planned!.budgetLevel, 'medium');
    expect(api.planned!.interests, ['Food']);
    expect(c.phase, ChatPhase.done);
  });

  test('Later turns merge; a value the model drops is kept', () async {
    final api = QueueLemonApi()
      ..replies.addAll([
        tokyo(travelers: 2, inferred: ['travelers']),
        LemonChatResult(
            reply: 'Mid budget, noted!',
            budgetLevel: 'medium',
            nextField: 'confirm'),
      ]);
    final c = free(api);
    addTearDown(c.dispose);
    await c.handleUserInput('Tokyo with my wife');
    expect(c.inferredFields, contains('travelers'));
    expect(said(c, 'I assumed 2 travelers'), isTrue);
    await c.handleUserInput('mid budget please');
    expect((c.destination, c.travelers, c.budgetLevel), ('Tokyo', 2, 'medium'));
  });

  test('A typed yes after the brief plans the trip', () async {
    final api = QueueLemonApi()..replies.addAll([tokyo(), tokyo(ready: true)]);
    final c = free(api);
    addTearDown(c.dispose);
    await c.handleUserInput('Tokyo next month');
    expect(api.planned, isNull);
    await c.handleUserInput('yes, plan it');
    expect(api.planned?.destination, 'Tokyo');
  });

  test('Rejected messages leave the trip and the history alone', () async {
    final api = QueueLemonApi()
      ..replies.addAll([
        tokyo(),
        LemonChatResult(
            reply: 'I only help with trips!',
            intent: 'off_topic',
            destination: 'Python'),
      ]);
    final c = free(api);
    addTearDown(c.dispose);
    await c.handleUserInput('Tokyo');
    await c.handleUserInput('write a program in Python');
    expect(c.destination, 'Tokyo');
    expect(said(c, 'I only help with trips!'), isTrue);
    await c.handleUserInput('ok');
    expect(
        api.histories.last.where((t) => t.content.contains('Python')), isEmpty);
    // Local noise never reaches the backend.
    final before = api.chats;
    await c.handleUserInput('!!!!!');
    expect(api.chats, before);
  });

  test('Plain words switch modes without a model call and keep details',
      () async {
    final store = MemoryChatSettingsStore();
    final api = QueueLemonApi()..replies.add(tokyo());
    final c = free(api, store);
    addTearDown(c.dispose);
    await c.handleUserInput('Tokyo');
    await c.handleUserInput('can we switch to guided mode?');
    expect(api.chats, 1);
    expect(c.mode, ChatMode.guided);
    expect(store.saved, ChatMode.guided);
    expect(c.destination, 'Tokyo');
    expect(c.nextField, 'travelers');
    expect(said(c, 'I kept everything you told me'), isTrue);
  });

  test('The model can also flag a switch request', () async {
    final api = QueueLemonApi()
      ..replies.add(LemonChatResult(
          reply: 'Sure!',
          intent: 'switch_to_guided',
          nextField: 'destination'));
    final c = free(api);
    addTearDown(c.dispose);
    await c.handleUserInput('I would rather click through it');
    expect(c.mode, ChatMode.guided);
  });

  test('Offline reading: Lemon asks first, and Keep typing stops asking',
      () async {
    final api = QueueLemonApi()
      ..replies.addAll([tokyo(fallback: true), tokyo(fallback: true)]);
    final c = free(api);
    addTearDown(c.dispose);
    await c.handleUserInput('Tokyo');
    expect(c.mode, ChatMode.free);
    expect(c.switchOffer, SwitchReason.offline);
    expect(said(c, 'offline right now'), isTrue);
    c.declineSwitch();
    expect(c.switchOffer, isNull);
    await c.handleUserInput('2 people');
    expect(c.switchOffer, isNull);
    expect(c.mode, ChatMode.free);
  });

  test('Unhappy or stuck twice: Lemon offers the guided controls', () async {
    final api = QueueLemonApi()
      ..replies.addAll([
        LemonChatResult(reply: 'Sorry! What should I fix?', intent: 'unhappy'),
        LemonChatResult(reply: 'Where to?', nextField: 'destination'),
        LemonChatResult(reply: 'Where to?', nextField: 'destination'),
      ]);
    final c = free(api);
    addTearDown(c.dispose);
    await c.handleUserInput("that's wrong");
    expect(c.switchOffer, SwitchReason.unhappy);
    c.declineSwitch();
    await c.handleUserInput('somewhere nice');
    expect(c.switchOffer, isNull);
    await c.handleUserInput('somewhere warm');
    expect(c.switchOffer, SwitchReason.stuck);
    c.acceptSwitch();
    expect(c.mode, ChatMode.guided);
    expect(c.nextField, 'destination');
  });

  test('An ambiguous place offers choices; picking one needs no call',
      () async {
    final api = QueueLemonApi()
      ..replies.add(LemonChatResult(
          reply: "There's more than one Paris! Which one do you mean?",
          startDate: startIso,
          endDate: endIso,
          destinationStatus: 'ambiguous',
          destinationOptions: ['Paris, France', 'Paris, Texas, United States'],
          nextField: 'destination'));
    final c = free(api);
    addTearDown(c.dispose);
    await c.handleUserInput('Paris for 4 days');
    expect(c.destination, isNull);
    expect(c.destinationOptions, hasLength(2));
    c.pickDestination('Paris, France');
    expect(api.chats, 1);
    expect(c.destination, 'Paris, France');
    expect(c.destinationOptions, isEmpty);
    expect(c.nextField, 'confirm');
  });

  test('Guided mode also offers choices for an ambiguous place', () async {
    final api = QueueLemonApi()
      ..replies.add(LemonChatResult(
          reply: 'Which Georgia?',
          destinationStatus: 'ambiguous',
          destinationOptions: ['Georgia', 'Georgia, United States']));
    final c = LemonChatController(
        api: api, mode: ChatMode.guided, settings: MemoryChatSettingsStore());
    addTearDown(c.dispose);
    await c.handleUserInput('Georgia');
    expect(c.destinationOptions, hasLength(2));
    c.pickDestination('Georgia, United States');
    expect(c.destination, 'Georgia, United States');
    expect(c.nextField, 'dates');
  });

  testWidgets('Gear menu switches the mode and saves it', (tester) async {
    final store = MemoryChatSettingsStore();
    final c = free(QueueLemonApi(), store);
    addTearDown(c.dispose);
    await pumpPanel(tester, c);
    await tester.tap(find.byTooltip('Chat settings'));
    await tester.pumpAndSettle();
    expect(find.text('CHAT MODE'), findsOneWidget);
    await tester
        .tap(find.widgetWithText(CheckedPopupMenuItem<ChatMode>, 'Guided'));
    await tester.pumpAndSettle();
    expect(c.mode, ChatMode.guided);
    expect(store.saved, ChatMode.guided);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'Brief tags defaults and assumptions; editing one opens its control',
      (tester) async {
    final api = QueueLemonApi()
      ..replies.add(tokyo(travelers: 2, inferred: ['travelers']));
    final c = free(api);
    addTearDown(c.dispose);
    await pumpPanel(tester, c);
    await tester.enterText(find.byType(TextField), 'Tokyo with my wife');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pumpAndSettle();
    expect(find.text('Assumed'), findsOneWidget);
    // Travelers, budget, pace and must-visit (DECISIONS 069).
    expect(find.text('Default'), findsNWidgets(4));
    // The brief is taller now (pace, must-visit): centre the row first.
    await tester.ensureVisible(find.byTooltip('Edit travelers'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).first, const Offset(0, -60));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byTooltip('Edit travelers'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Edit travelers'));
    await tester.pumpAndSettle();
    expect(c.editingField, 'travelers');
    expect(find.text('Keep it as is'), findsOneWidget);
    await tester.enterText(
        find.widgetWithText(TextField, 'Number of travelers'), '3');
    await tester.ensureVisible(find.text('Continue'));
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect((c.travelers, c.editingField, c.nextField), (3, null, 'confirm'));
    expect(find.text('Assumed'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final width in [360.0, 800.0, 1440.0]) {
    testWidgets('Free mode offer and choices fit at $width', (tester) async {
      final api = QueueLemonApi()
        ..replies.add(LemonChatResult(
            reply: 'Which one?',
            destinationStatus: 'ambiguous',
            destinationOptions: [
              'Portland, Oregon, United States',
              'Portland, Maine, United States'
            ],
            fallbackUsed: true,
            nextField: 'destination'));
      final c = free(api);
      addTearDown(c.dispose);
      await pumpPanel(tester, c, width: width);
      await tester.enterText(find.byType(TextField), 'Portland');
      await tester.testTextInput.receiveAction(TextInputAction.send);
      await tester.pumpAndSettle();
      expect(find.text('Portland, Maine, United States'), findsOneWidget);
      expect(find.text('Switch to guided'), findsOneWidget);
      expect(find.text('Keep typing'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
