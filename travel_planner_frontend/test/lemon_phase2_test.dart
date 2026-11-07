// Lemon.ai phase 2 (DECISIONS 069): popular spots and must-visits, pace,
// grounded stops, and editing one day with a preview. Fake services only;
// never a live backend.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travel_planner_frontend/chat/chat_message.dart';
import 'package:travel_planner_frontend/chat/lemon_chat_controller.dart';
import 'package:travel_planner_frontend/models/chat_models.dart';
import 'package:travel_planner_frontend/models/itinerary_models.dart';
import 'package:travel_planner_frontend/screens/views/itinerary_view.dart';
import 'package:travel_planner_frontend/services/chat_settings.dart';
import 'package:travel_planner_frontend/services/lemon_api_service.dart';
import 'package:travel_planner_frontend/widgets/lemon_chat_panel.dart';

class Phase2Api extends LemonApiService {
  final List<LemonChatResult> replies = [];
  final List<String?> summaries = [];
  final List<List<String>> spotInterests = [];
  SpotsResult spots = const SpotsResult(status: 'none', destination: '');
  TripRequest? planned;
  ItineraryResponse? plan;
  final List<PlanEdit> edits = [];
  PlanEditResult? editResult;

  @override
  Future<LemonChatResult> sendChatTurn(
      {required List<ChatTurn> messages,
      required String provider,
      String? planSummary,
      int? planDays}) async {
    summaries.add(planSummary);
    return replies.isEmpty
        ? LemonChatResult(reply: 'Tell me more!')
        : replies.removeAt(0);
  }

  @override
  Future<SpotsResult> getPopularSpots(String destination,
      {List<String> interests = const []}) async {
    spotInterests.add(List.of(interests));
    return spots;
  }

  @override
  Future<ItineraryResponse> planTrip(TripRequest value) async {
    planned = value;
    return plan ?? twoDays();
  }

  @override
  Future<PlanEditResult> editPlan(
      {required TripRequest trip,
      required List<ItineraryDay> days,
      required PlanEdit edit}) async {
    edits.add(edit);
    final result = editResult;
    if (result == null) throw LemonApiException('offline');
    return result;
  }
}

String iso(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
final start = DateUtils.dateOnly(DateTime.now()).add(const Duration(days: 20));
final startIso = iso(start), endIso = iso(start.add(const Duration(days: 1)));

const parisSpots = SpotsResult(
    status: 'ready',
    destination: 'Paris',
    spots: [
      PopularSpot(
          name: 'Eiffel Tower',
          placeId: 'eiffel',
          lat: 48.858,
          lon: 2.294,
          popularity: 191,
          kind: 'tower'),
      PopularSpot(
          name: 'Louvre Museum',
          placeId: 'louvre',
          lat: 48.86,
          lon: 2.33,
          popularity: 170,
          kind: 'museum'),
      PopularSpot(
          name: 'Notre-Dame de Paris',
          placeId: 'nd',
          popularity: 125,
          kind: 'worship'),
    ],
    picks: [
      'Eiffel Tower',
      'Louvre Museum'
    ]);

LemonChatResult paris(
        {List<MustVisitPlace> mustVisit = const [],
        String? pace,
        bool toLemon = false,
        bool ready = false,
        bool dates = true,
        int? travelers,
        String reply = 'Paris, lovely!',
        List<String> inferred = const []}) =>
    LemonChatResult(
        reply: reply,
        ready: ready,
        travelers: travelers,
        destination: 'Paris',
        destinationLabel: 'Paris, France',
        destinationStatus: 'verified',
        startDate: dates ? startIso : null,
        endDate: dates ? endIso : null,
        nextField: dates ? 'confirm' : 'dates',
        mustVisit: mustVisit,
        pace: pace,
        inferred: inferred,
        spotsToLemon: toLemon);

ItineraryResponse twoDays({String provider = 'groq'}) => ItineraryResponse(
        destination: 'Paris, France',
        providerUsed: provider,
        days: [
          ItineraryDay(day: 1, date: startIso, activities: [
            ItineraryActivity(
                time: '09:00',
                activity: 'Visit the Louvre',
                location: 'Louvre Museum',
                placeStatus: 'verified',
                placeId: 'louvre'),
            ItineraryActivity(
                time: '13:00',
                activity: 'Hidden bistro lunch',
                location: 'Le Bistro Imaginaire',
                placeStatus: 'unverified'),
            ItineraryActivity(time: '18:00', activity: 'Free evening'),
          ]),
          ItineraryDay(day: 2, date: endIso, activities: [
            ItineraryActivity(
                time: '10:00', activity: 'Eiffel Tower', location: 'Eiffel Tower'),
          ]),
        ]);

bool said(LemonChatController c, String text) =>
    c.messages.any((m) => m.text?.contains(text) == true);

LemonChatController free(Phase2Api api) {
  final c = LemonChatController(
      api: api, mode: ChatMode.free, settings: MemoryChatSettingsStore());
  c.startIfNeeded();
  return c;
}

Future<void> pumpPanel(WidgetTester tester, LemonChatController c,
    {double width = 800}) async {
  tester.view.physicalSize = Size(width, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  // A fresh panel for each controller.
  await tester.pumpWidget(const SizedBox());
  await tester.pumpWidget(MaterialApp(
      home: Scaffold(
          body: Center(
              child: SizedBox(
                  width: width < 500 ? width : 420,
                  height: 900,
                  child: LemonChatPanel(controller: c, onClose: () {}))))));
  await tester.pumpAndSettle();
}

/// Lets the panel's auto-scroll finish, then brings [finder] to the middle.
Future<void> reveal(WidgetTester tester, Finder finder) async {
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(finder, 120,
      scrollable: find.byType(Scrollable).first, maxScrolls: 60);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

Future<LemonChatController> planned(Phase2Api api) async {
  api.replies.add(paris());
  final c = free(api);
  await c.handleUserInput('2 days in Paris');
  await c.confirmTrip();
  return c;
}

void main() {
  group('Popular spots and must-visits', () {
    test('A verified destination loads spots and Lemon offers them once',
        () async {
      final api = Phase2Api()
        ..spots = parisSpots
        ..replies.addAll([paris(), paris()]);
      final c = free(api);
      addTearDown(c.dispose);
      await c.handleUserInput('2 days in Paris');
      await pumpEventQueue();
      expect(c.spotsStatus, 'ready');
      final offers =
          c.messages.where((m) => m.type == ChatMessageType.spots).toList();
      expect(offers, hasLength(1));
      expect(offers.single.spots.map((s) => s.name),
          ['Eiffel Tower', 'Louvre Museum', 'Notre-Dame de Paris']);
      expect(offers.single.text, contains('popular spots in Paris, France'));
      await c.handleUserInput('sounds fun');
      await pumpEventQueue();
      expect(c.messages.where((m) => m.type == ChatMessageType.spots),
          hasLength(1));
    });

    test('Tapping a spot adds it to the plan request; tapping again removes it',
        () async {
      final api = Phase2Api()
        ..spots = parisSpots
        ..replies.add(paris());
      final c = free(api);
      addTearDown(c.dispose);
      await c.handleUserInput('2 days in Paris');
      await pumpEventQueue();
      c.toggleSpot(parisSpots.spots[0]);
      c.toggleSpot(parisSpots.spots[1]);
      c.toggleSpot(parisSpots.spots[0]);
      expect(c.mustVisit.map((m) => m.name), ['Louvre Museum']);
      await c.confirmTrip();
      expect(api.planned!.mustVisit.single.toJson(), {
        'name': 'Louvre Museum',
        'place_id': 'louvre',
        'lat': 48.86,
        'lon': 2.33
      });
      expect(api.planned!.pace, 'balanced');
    });

    test('Typed must-visits join; unknown ones are named once; removed stay gone',
        () async {
      const louvre = MustVisitPlace(
          name: 'Louvre', status: 'verified', placeId: 'g1', lat: 48.86, lon: 2.33);
      const nowhere = MustVisitPlace(name: 'Nowhere Cafe', status: 'not_found');
      final api = Phase2Api()
        ..replies.addAll([
          paris(mustVisit: [louvre, nowhere]),
          paris(mustVisit: [louvre, nowhere]),
        ]);
      final c = free(api);
      addTearDown(c.dispose);
      await c.handleUserInput('Paris, we must see the Louvre and Nowhere Cafe');
      expect(c.mustVisit.map((m) => m.name), ['Louvre']);
      expect(said(c, "I couldn't find Nowhere Cafe near Paris, France"), isTrue);
      c.removeMustVisit(c.mustVisit.single);
      await c.handleUserInput('lovely');
      expect(c.mustVisit, isEmpty);
      expect(
          c.messages
              .where((m) => m.text?.contains("couldn't find Nowhere") == true),
          hasLength(1));
    });

    test('A new destination clears the old must-visits', () async {
      final api = Phase2Api()..spots = parisSpots;
      api.replies.addAll([
        paris(),
        LemonChatResult(
            reply: 'Rome!',
            destination: 'Rome',
            destinationLabel: 'Rome, Italy',
            destinationStatus: 'verified',
            startDate: startIso,
            endDate: endIso),
      ]);
      final c = free(api);
      addTearDown(c.dispose);
      await c.handleUserInput('Paris');
      await pumpEventQueue();
      c.toggleSpot(parisSpots.spots[0]);
      await c.handleUserInput('actually Rome');
      expect(c.mustVisit, isEmpty);
      expect(c.placeName, 'Rome, Italy');
    });

    test('"Surprise me" adds Lemon\'s picks and she stops recommending',
        () async {
      final api = Phase2Api()
        ..spots = parisSpots
        ..replies.addAll([paris(), paris(toLemon: true)]);
      final c = free(api);
      addTearDown(c.dispose);
      await c.handleUserInput('Paris');
      await pumpEventQueue();
      await c.handleUserInput('up to you Lemon');
      await pumpEventQueue();
      expect(c.mustVisit.map((m) => (m.name, m.byLemon)),
          [('Eiffel Tower', true), ('Louvre Museum', true)]);
      expect(c.spotsToLemon, isTrue);
      expect(said(c, 'I picked Eiffel Tower and Louvre Museum for you'), isTrue);
    });

    test('A whole country is too broad: Lemon asks for a city', () async {
      final api = Phase2Api()
        ..spots = const SpotsResult(status: 'too_broad', destination: 'Japan')
        ..replies.add(LemonChatResult(
            reply: 'Japan!',
            destination: 'Japan',
            destinationLabel: 'Japan',
            destinationStatus: 'verified'));
      final c = free(api);
      addTearDown(c.dispose);
      await c.handleUserInput('Japan');
      await pumpEventQueue();
      expect(said(c, 'Japan is a big place!'), isTrue);
      expect(said(c, 'specific city or area'), isTrue);
    });

    testWidgets('Spot pills toggle a must-visit chip on the brief',
        (tester) async {
      for (final width in [360.0, 800.0, 1440.0]) {
        final api = Phase2Api()
          ..spots = parisSpots
          ..replies.add(paris());
        final c = free(api);
        await pumpPanel(tester, c, width: width);
        await tester.enterText(find.byType(TextField), '2 days in Paris');
        await tester.testTextInput.receiveAction(TextInputAction.send);
        await tester.pumpAndSettle();
        await reveal(tester, find.text('Louvre Museum'));
        await tester.tap(find.text('Louvre Museum'));
        await tester.pumpAndSettle();
        expect(c.mustVisit.map((m) => m.name), ['Louvre Museum']);
        expect(find.byTooltip('Remove Louvre Museum'), findsOneWidget);
        expect(find.text('Must-visit'), findsOneWidget);
        expect(find.text('Pace'), findsOneWidget);
        expect(tester.takeException(), isNull, reason: 'width $width');
        c.dispose();
      }
    });
  });

  group('Pace', () {
    test('Pace from chat shows on the brief, and can be changed', () async {
      final api = Phase2Api()
        ..replies.add(paris(pace: 'relaxed', inferred: ['pace']));
      final c = free(api);
      addTearDown(c.dispose);
      await c.handleUserInput('a slow trip to Paris');
      expect(c.pace, 'relaxed');
      expect(c.inferredFields, contains('pace'));
      expect(c.isDefaulted('pace'), isFalse);
      c.editField('pace');
      expect(c.controlField, 'pace');
      c.setPace('packed');
      expect((c.pace, c.editingField), ('packed', null));
      await c.confirmTrip();
      expect(api.planned!.pace, 'packed');
    });

    test('Guided mode asks pace, then must-visit spots, then the brief',
        () async {
      final api = Phase2Api()
        ..spots = parisSpots
        ..replies.add(LemonChatResult(
            reply: 'ok', destination: 'Paris', destinationStatus: 'verified'));
      final c = LemonChatController(
          api: api, mode: ChatMode.guided, settings: MemoryChatSettingsStore());
      addTearDown(c.dispose);
      c.startIfNeeded();
      await c.handleUserInput('Paris');
      await pumpEventQueue();
      c.setDates(start, start.add(const Duration(days: 1)));
      c.setTravelers(2);
      c.setBudget('low');
      c.setInterests(['Food']);
      expect(c.nextField, 'pace');
      c.setPace('relaxed');
      expect(c.nextField, 'must_visit');
      expect(c.messages.last.type, ChatMessageType.spots);
      c.toggleSpot(parisSpots.spots[2]);
      c.confirmSpots();
      expect(c.nextField, 'confirm');
      await c.confirmTrip();
      expect(api.planned!.pace, 'relaxed');
      expect(api.planned!.mustVisit.single.name, 'Notre-Dame de Paris');
    });

    test('Guided "Surprise me" at the spot step picks and moves on', () async {
      final api = Phase2Api()
        ..spots = parisSpots
        ..replies.add(LemonChatResult(
            reply: 'ok', destination: 'Paris', destinationStatus: 'verified'));
      final c = LemonChatController(
          api: api, mode: ChatMode.guided, settings: MemoryChatSettingsStore());
      addTearDown(c.dispose);
      c.startIfNeeded();
      await c.handleUserInput('Paris');
      await pumpEventQueue();
      c.setDates(start, start.add(const Duration(days: 1)));
      c.setTravelers(1);
      c.setBudget('high');
      c.setInterests(['Nature']);
      c.setPace('balanced');
      await c.surpriseSpots();
      expect(c.nextField, 'confirm');
      expect(c.mustVisit.every((m) => m.byLemon), isTrue);
      expect(api.spotInterests.last, ['Nature']);
    });
  });

  group('Editing the plan', () {
    test('After a plan, the chat stays open and sends the plan along',
        () async {
      final api = Phase2Api();
      final c = await planned(api);
      addTearDown(c.dispose);
      expect(c.phase, ChatPhase.done);
      expect(c.showsChatBox, isTrue);
      api.replies.add(LemonChatResult(
          reply: LemonChatControllerTestText.question,
          intent: 'plan_question'));
      await c.handleUserInput('what should I wear on day 2?');
      expect(api.summaries.last, contains('Day 1 ($startIso):'));
      expect(api.summaries.last, contains('  1. 09:00 Visit the Louvre (Louvre Museum)'));
      expect(said(c, 'coming soon'), isTrue);
    });

    test('A chat edit shows a preview; "Use this" replaces only that day',
        () async {
      final api = Phase2Api();
      final c = await planned(api);
      addTearDown(c.dispose);
      final newDay = ItineraryDay(day: 2, date: endIso, activities: [
        ItineraryActivity(time: '10:00', activity: 'Slow morning in the Marais'),
      ]);
      api.editResult = PlanEditResult(day: newDay, providerUsed: 'groq');
      api.replies.add(LemonChatResult(
          reply: 'On it! 🍋 Let me rework day 2 for you.',
          intent: 'edit_plan',
          edit: const PlanEdit(
              action: 'adjust_day', day: 2, instruction: 'more relaxed')));
      await c.handleUserInput('make day 2 more relaxed');
      expect(api.edits.single.instruction, 'more relaxed');
      expect(c.pendingPreview, isNotNull);
      expect(c.messages.last.type, ChatMessageType.editPreview);
      final before = c.latestItinerary!;
      c.acceptEdit();
      expect(c.latestItinerary!.days[1].activities.single.activity,
          'Slow morning in the Marais');
      expect(c.latestItinerary!.days[0], same(before.days[0]));
      expect(c.itineraryNotifier.value, same(c.latestItinerary));
      expect(said(c, 'Day 2 is updated'), isTrue);
    });

    test('"Keep old" leaves the plan as it was', () async {
      final api = Phase2Api();
      final c = await planned(api);
      addTearDown(c.dispose);
      api.editResult = PlanEditResult(
          day: ItineraryDay(day: 1, date: startIso, activities: [
            ItineraryActivity(time: '09:00', activity: 'Something else'),
          ]),
          providerUsed: 'groq');
      final before = c.latestItinerary;
      await c.requestEdit(const PlanEdit(action: 'regenerate_day', day: 1),
          fromButton: true);
      expect(said(c, 'Regenerate day 1'), isTrue);
      c.keepOldDay();
      expect(c.latestItinerary, same(before));
      expect(c.pendingPreview, isNull);
    });

    test('A failed edit keeps the plan and can be retried or dismissed',
        () async {
      final api = Phase2Api();
      final c = await planned(api);
      addTearDown(c.dispose);
      await c.requestEdit(
          const PlanEdit(action: 'swap_activity', day: 1, stop: 2));
      expect(c.error, contains("couldn't change day 1"));
      expect(c.canRetryEdit, isTrue);
      api.editResult = PlanEditResult(
          day: ItineraryDay(day: 1, date: startIso, activities: []),
          providerUsed: 'groq');
      await c.retry();
      expect(api.edits, hasLength(2));
      expect(c.error, isNull);
      expect(c.pendingPreview, isNotNull);
    });

    test('A demo plan is never edited', () async {
      final api = Phase2Api()..plan = twoDays(provider: 'mock');
      final c = await planned(api);
      addTearDown(c.dispose);
      await c.requestEdit(const PlanEdit(action: 'regenerate_day', day: 1));
      expect(api.edits, isEmpty);
      expect(said(c, "This is a demo plan"), isTrue);
    });

    testWidgets('The preview card has Use this and Keep old', (tester) async {
      final api = Phase2Api();
      final c = await planned(api);
      api.editResult = PlanEditResult(
          day: ItineraryDay(day: 1, date: startIso, activities: [
            ItineraryActivity(time: '09:00', activity: 'Musée Rodin'),
          ]),
          providerUsed: 'groq');
      await pumpPanel(tester, c);
      await c.requestEdit(const PlanEdit(action: 'regenerate_day', day: 1));
      await tester.pumpAndSettle();
      expect(find.text('Musée Rodin'), findsOneWidget);
      await reveal(tester, find.text('Use this'));
      await tester.tap(find.text('Use this'));
      await tester.pumpAndSettle();
      expect(c.latestItinerary!.days[0].activities.single.activity, 'Musée Rodin');
      // Only the traveller's echoed 'Use this' bubble is left, not the button.
      expect(find.widgetWithText(ElevatedButton, 'Use this'), findsNothing);
      expect(find.text('Added to your itinerary'), findsOneWidget);
      expect(tester.takeException(), isNull);
      c.dispose();
    });
  });

  group('Must-visits that did not fit (DECISIONS 070)', () {
    ItineraryResponse missing(List<String> names) => ItineraryResponse(
        destination: 'Paris, France',
        providerUsed: 'groq',
        days: twoDays().days,
        missingMustVisits: names);

    Future<LemonChatController> withLouvre(Phase2Api api,
        {List<String> also = const []}) async {
      api
        ..spots = parisSpots
        ..replies.add(paris());
      final c = free(api);
      await c.handleUserInput('2 days in Paris');
      // Microtasks only: pumpEventQueue's timers never fire inside testWidgets.
      for (var i = 0; i < 5; i++) {
        await Future<void>.value();
      }
      c.toggleSpot(parisSpots.spots[1]);
      for (final name in also) {
        c.toggleSpot(parisSpots.spots.firstWhere((s) => s.name == name));
      }
      return c;
    }

    test('None fit: Lemon asks first; yes shows the plan already made',
        () async {
      final api = Phase2Api()..plan = missing(['Louvre Museum']);
      final c = await withLouvre(api);
      addTearDown(c.dispose);
      await c.confirmTrip();
      expect(c.latestItinerary, isNull);
      expect(c.heldPlan, isNotNull);
      expect(c.controlField, 'held_plan');
      expect(said(c, "I couldn't fit Louvre Museum into your plan"), isTrue);
      c.continueWithoutMissing();
      expect(c.latestItinerary, isNotNull);
      expect(c.itineraryNotifier.value, same(c.latestItinerary));
      expect(c.phase, ChatPhase.done);
      expect(c.heldPlan, isNull);
    });

    test('None fit: no stops there and keeps the brief', () async {
      final api = Phase2Api()..plan = missing(['Louvre Museum']);
      final c = await withLouvre(api);
      addTearDown(c.dispose);
      await c.confirmTrip();
      c.stopHere();
      expect(c.latestItinerary, isNull);
      expect(c.heldPlan, isNull);
      expect(c.phase, ChatPhase.chatting);
      expect(c.controlField, 'confirm');
      expect(c.mustVisit.map((m) => m.name), ['Louvre Museum']);
      expect(said(c, "I've stopped here"), isTrue);
    });

    test('Typed yes or no answers the question', () async {
      for (final (text, shown) in [('yes please', true), ('no thanks', false)]) {
        final api = Phase2Api()..plan = missing(['Louvre Museum']);
        final c = await withLouvre(api);
        await c.confirmTrip();
        await c.handleUserInput('hmm');
        expect(c.heldPlan, isNotNull, reason: 'unclear answers ask again');
        await c.handleUserInput(text);
        expect(c.latestItinerary != null, shown, reason: text);
        c.dispose();
      }
    });

    test('Some fit: the plan shows at once and names what is missing',
        () async {
      final api = Phase2Api()..plan = missing(['Eiffel Tower']);
      final c = await withLouvre(api, also: ['Eiffel Tower']);
      addTearDown(c.dispose);
      await c.confirmTrip();
      expect(c.heldPlan, isNull);
      expect(c.phase, ChatPhase.done);
      expect(said(c, "I couldn't fit Eiffel Tower in this time"), isTrue);
    });

    testWidgets('The yes and no buttons work at every width', (tester) async {
      for (final width in [360.0, 800.0, 1440.0]) {
        final api = Phase2Api()..plan = missing(['Louvre Museum']);
        final c = await withLouvre(api);
        await c.confirmTrip();
        await pumpPanel(tester, c, width: width);
        await reveal(tester, find.text('No, stop here'));
        expect(find.text('Yes, show my plan'), findsOneWidget);
        await tester.tap(find.text('Yes, show my plan'));
        await tester.pumpAndSettle();
        expect(c.phase, ChatPhase.done, reason: 'width $width');
        expect(tester.takeException(), isNull, reason: 'width $width');
        c.dispose();
      }
    });

    testWidgets('An edit that lost a must-visit says so in the preview',
        (tester) async {
      final api = Phase2Api();
      final c = await planned(api);
      api.editResult = PlanEditResult(
          day: ItineraryDay(day: 1, date: startIso, activities: [
            ItineraryActivity(time: '09:00', activity: 'Marais walk'),
          ]),
          providerUsed: 'groq',
          missingMustVisits: const ['Louvre Museum']);
      await pumpPanel(tester, c);
      await c.requestEdit(const PlanEdit(action: 'regenerate_day', day: 1));
      await tester.pumpAndSettle();
      expect(said(c, "I couldn't keep Louvre Museum on it"), isTrue);
      expect(find.text('Not on this day any more: Louvre Museum'), findsOneWidget);
      expect(c.pendingPreview, isNotNull);
      expect(tester.takeException(), isNull);
      c.dispose();
    });
  });

  group('Grounded stops on the itinerary', () {
    Future<void> show(WidgetTester tester, ItineraryResponse plan,
        {double width = 1440, ValueChanged<PlanEdit>? onEdit}) async {
      tester.view.physicalSize = Size(width, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: ItineraryView(
                  itinerary: plan, onOpenLemon: () {}, onEdit: onEdit))));
      await tester.pumpAndSettle();
    }

    testWidgets('Checked places get a pin; unmatched ones say Unverified',
        (tester) async {
      await show(tester, twoDays());
      expect(find.byTooltip('Checked on the map'), findsOneWidget);
      expect(find.text('Unverified'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Day and stop buttons ask for the right edit', (tester) async {
      for (final width in [360.0, 800.0, 1440.0]) {
        final asked = <PlanEdit>[];
        await show(tester, twoDays(), width: width, onEdit: asked.add);
        await tester.ensureVisible(find.text('Regenerate day').first);
        await tester.tap(find.text('Regenerate day').first);
        await tester.ensureVisible(find.text('Swap').at(1));
        await tester.tap(find.text('Swap').at(1));
        await tester.pumpAndSettle();
        expect(asked.map((e) => (e.action, e.day, e.stop)),
            [('regenerate_day', 1, null), ('swap_activity', 1, 2)],
            reason: 'width $width');
        await tester.ensureVisible(find.text('Adjust day').first);
        await tester.tap(find.text('Adjust day').first);
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), 'more food stops');
        await tester.tap(find.text('Ask Lemon'));
        await tester.pumpAndSettle();
        expect(asked.last.instruction, 'more food stops');
        expect(tester.takeException(), isNull, reason: 'width $width');
      }
    });

    testWidgets('A demo plan shows no edit buttons', (tester) async {
      await show(tester, twoDays(provider: 'mock'), onEdit: (_) {});
      expect(find.text('Regenerate day'), findsNothing);
      expect(find.text('Swap'), findsNothing);
    });
  });

  group('"Plan it" waits for questions and a changed brief (DECISIONS 071)',
      () {
    const nowhere = MustVisitPlace(name: 'Nowhere Cafe', status: 'not_found');
    const ghost = MustVisitPlace(name: 'Ghost Bar', status: 'not_found');
    const louvre = MustVisitPlace(
        name: 'Louvre', status: 'verified', placeId: 'g1', lat: 48.86, lon: 2.33);

    test('A changed trip with "plan it" shows the new brief and waits',
        () async {
      final api = Phase2Api()
        ..replies.addAll([
          paris(),
          paris(travelers: 2, ready: true, reply: "Let me plan it now!"),
          paris(travelers: 2, ready: true, reply: 'Planning!'),
        ]);
      final c = free(api);
      addTearDown(c.dispose);
      await c.handleUserInput('2 days in Paris');
      await c.handleUserInput('Two of us, plan it');
      expect(api.planned, isNull);
      expect(said(c, "I've updated your trip. 🎯 Here's the new brief"), isTrue);
      expect(said(c, 'Let me plan it now!'), isFalse);
      expect(c.controlField, 'confirm');
      await c.handleUserInput('go ahead');
      expect(api.planned?.travelers, 2);
    });

    test('The hold happens once: a second "go ahead" plans', () async {
      final api = Phase2Api()
        ..replies.addAll([
          paris(),
          paris(travelers: 2, ready: true),
          // The model re-reads a value differently; the traveller already saw
          // the brief, so this plans.
          paris(travelers: 3, ready: true),
        ]);
      final c = free(api);
      addTearDown(c.dispose);
      await c.handleUserInput('Paris');
      await c.handleUserInput('Two of us, plan it');
      expect(api.planned, isNull);
      await c.handleUserInput('go ahead');
      expect(api.planned, isNotNull);
    });

    test('An unchanged brief and "go ahead" still plans at once', () async {
      final api = Phase2Api()..replies.addAll([paris(), paris(ready: true)]);
      final c = free(api);
      addTearDown(c.dispose);
      await c.handleUserInput('Paris');
      await c.handleUserInput('go ahead');
      expect(api.planned, isNotNull);
    });

    test('A must-visit not found holds "plan it"; Continue shows the brief',
        () async {
      final api = Phase2Api()
        ..replies.addAll([
          paris(),
          paris(mustVisit: [louvre, nowhere], ready: true, reply: 'On it!'),
        ]);
      final c = free(api);
      addTearDown(c.dispose);
      await c.handleUserInput('Paris');
      await c.handleUserInput('We must see the Louvre and Nowhere Cafe, plan it');
      expect(api.planned, isNull);
      expect(said(c, 'On it!'), isFalse);
      expect(said(c, 'Sure thing! But before that, I have a question'), isTrue);
      expect(said(c, "I couldn't find Nowhere Cafe near Paris, France"), isTrue);
      expect(c.controlField, 'unfound');
      expect(c.mustVisit.map((m) => m.name), ['Louvre']);
      await c.confirmTrip(); // no Generate while she waits
      expect(api.planned, isNull);
      c.continueWithoutUnfound();
      expect(said(c, "I'll leave Nowhere Cafe out"), isTrue);
      expect(said(c, 'All set! 🎯'), isTrue);
      expect(said(c, "Here's your updated brief"), isTrue);
      expect(c.controlField, 'confirm');
      expect(api.planned, isNull);
    });

    test('A message that does not answer gets the question again', () async {
      final api = Phase2Api()
        ..replies.addAll([
          paris(mustVisit: [nowhere]),
          paris(mustVisit: [nowhere], travelers: 2, ready: true),
        ]);
      final c = free(api);
      addTearDown(c.dispose);
      await c.handleUserInput('Paris, we must see Nowhere Cafe');
      expect(said(c, 'Before we go on, I have a question'), isTrue);
      // The brief waits for the answer.
      expect(said(c, 'Tap any detail below'), isFalse);
      await c.handleUserInput('Two of us, go ahead and plan it');
      expect(api.planned, isNull);
      expect(c.travelers, 2);
      expect(said(c, 'I still need your answer about one place'), isTrue);
      expect(said(c, 'Would you like to swap Nowhere Cafe'), isTrue);
      await c.handleUserInput('skip it');
      expect(said(c, 'All set! 🎯'), isTrue);
      expect(said(c, 'Tap any detail below'), isTrue);
      expect(c.controlField, 'confirm');
      expect(api.planned, isNull);
    });

    test('Swap, then a spot tap replaces the place', () async {
      final api = Phase2Api()
        ..spots = parisSpots
        ..replies.add(paris(mustVisit: [nowhere]));
      final c = free(api);
      addTearDown(c.dispose);
      await c.handleUserInput('Paris, we must see Nowhere Cafe');
      await pumpEventQueue();
      // Spots wait while Lemon asks.
      expect(c.messages.where((m) => m.type == ChatMessageType.spots), isEmpty);
      c.swapUnfound();
      expect(c.swappingUnfound, isTrue);
      expect(said(c, 'Pick one of the popular spots below'), isTrue);
      c.toggleSpot(parisSpots.spots[1]);
      expect(c.mustVisit.map((m) => m.name), ['Louvre Museum']);
      expect(said(c, "I've added Louvre Museum instead of Nowhere Cafe"), isTrue);
      expect(c.controlField, 'confirm');
      // The swap buttons are for the swap; the list still comes once, after
      // the questions, just before the brief.
      final texts = [for (final m in c.messages) m.text ?? ''];
      final list =
          c.messages.indexWhere((m) => m.type == ChatMessageType.spots);
      expect(c.messages.where((m) => m.type == ChatMessageType.spots),
          hasLength(1));
      expect(list, greaterThan(texts.indexWhere((t) => t.contains('All set!'))));
      expect(list,
          lessThan(texts.indexWhere((t) => t.contains('Tap any detail below'))));
    });

    test('Spots wait for every question, then come right before the brief',
        () async {
      final api = Phase2Api()
        ..spots = parisSpots
        ..replies.add(paris(mustVisit: [
          nowhere,
          const MustVisitPlace(name: 'Ghost Bar', status: 'not_found'),
        ]));
      final c = free(api);
      addTearDown(c.dispose);
      await c.handleUserInput('Paris, we must see Nowhere Cafe and Ghost Bar');
      await pumpEventQueue();
      bool listed() =>
          c.messages.any((m) => m.type == ChatMessageType.spots);
      expect(listed(), isFalse);
      c.continueWithoutUnfound(); // Nowhere Cafe
      await pumpEventQueue();
      expect(said(c, 'Next one!'), isTrue);
      expect(listed(), isFalse); // still a question to go
      c.continueWithoutUnfound(); // Ghost Bar
      final texts = [for (final m in c.messages) m.text ?? ''];
      final list =
          c.messages.indexWhere((m) => m.type == ChatMessageType.spots);
      expect(list, greaterThan(texts.indexWhere((t) => t.contains('All set!'))));
      expect(list,
          lessThan(texts.indexWhere((t) => t.contains('Tap any detail below'))));
    });

    test('A first brief with spots ready: the list comes before the brief',
        () async {
      final api = Phase2Api()
        ..spots = parisSpots
        ..replies.addAll([paris(dates: false), paris()]);
      final c = free(api);
      addTearDown(c.dispose);
      await c.handleUserInput('Paris');
      await pumpEventQueue();
      expect(c.messages.any((m) => m.type == ChatMessageType.spots), isFalse);
      await c.handleUserInput('2 days from Dec 10');
      final texts = [for (final m in c.messages) m.text ?? ''];
      final list =
          c.messages.indexWhere((m) => m.type == ChatMessageType.spots);
      expect(list, greaterThanOrEqualTo(0));
      expect(list,
          lessThan(texts.indexWhere((t) => t.contains('Tap any detail below'))));
    });

    test('Swap, a typed name not found asks again; a found one is added',
        () async {
      final api = Phase2Api()
        ..replies.addAll([
          paris(mustVisit: [nowhere]),
          paris(mustVisit: [
            nowhere,
            const MustVisitPlace(name: 'Nowhere Caffe', status: 'not_found')
          ]),
          paris(mustVisit: [nowhere, louvre]),
        ]);
      final c = free(api);
      addTearDown(c.dispose);
      await c.handleUserInput('Paris, we must see Nowhere Cafe');
      await c.handleUserInput('swap it');
      expect(c.swappingUnfound, isTrue);
      await c.handleUserInput('Nowhere Caffe');
      expect(said(c, "I couldn't find Nowhere Caffe near Paris, France either"),
          isTrue);
      expect(c.controlField, 'unfound');
      await c.handleUserInput('Louvre');
      expect(said(c, "I've added Louvre instead of Nowhere Cafe"), isTrue);
      expect(c.mustVisit.map((m) => m.name), ['Louvre']);
      expect(c.controlField, 'confirm');
      expect(api.planned, isNull);
    });

    test('A place typed without tapping Swap counts as the answer', () async {
      final api = Phase2Api()
        ..replies.addAll([
          paris(mustVisit: [nowhere]),
          paris(mustVisit: [nowhere, louvre]),
        ]);
      final c = free(api);
      addTearDown(c.dispose);
      await c.handleUserInput('Paris, we must see Nowhere Cafe');
      await c.handleUserInput('the Louvre');
      expect(said(c, "I've added Louvre instead of Nowhere Cafe"), isTrue);
      expect(said(c, 'Would you like to swap Nowhere Cafe'), isFalse);
      expect(c.unfoundPlace, isNull);
      expect(c.controlField, 'confirm');
      expect(api.planned, isNull);
    });

    test('An unknown place typed without Swap: "either", every time',
        () async {
      const typo = MustVisitPlace(name: 'Hanamiya Tea House', status: 'not_found');
      final api = Phase2Api()
        ..spots = parisSpots
        ..replies.addAll([
          paris(mustVisit: [nowhere]),
          paris(mustVisit: [nowhere, typo]),
          paris(mustVisit: [nowhere, typo]),
        ]);
      final c = free(api);
      addTearDown(c.dispose);
      await c.handleUserInput('Paris, we must see Nowhere Cafe');
      await pumpEventQueue();
      await c.handleUserInput('Hanamiya Tea House');
      bool either() =>
          said(c, "I couldn't find Hanamiya Tea House near Paris, France either");
      expect(either(), isTrue);
      expect(c.swappingUnfound, isTrue); // the spot buttons show
      expect(c.unfoundPlace, 'Nowhere Cafe');
      await c.handleUserInput('Hanamiya Tea House');
      expect(
          c.messages.where((m) =>
              m.text?.contains("couldn't find Hanamiya Tea House") == true),
          hasLength(2));
      c.continueWithoutUnfound();
      // Not queued as a question of its own.
      expect(said(c, 'Next one!'), isFalse);
      expect(c.controlField, 'confirm');
    });

    test('A skipped place named again in a new message is asked again',
        () async {
      final api = Phase2Api()
        ..replies.addAll([
          paris(mustVisit: [nowhere]),
          paris(mustVisit: [nowhere]),
          paris(mustVisit: [nowhere]),
        ]);
      final c = free(api);
      addTearDown(c.dispose);
      await c.handleUserInput('Paris, we must see Nowhere Cafe');
      c.continueWithoutUnfound();
      await c.handleUserInput('sounds lovely');
      expect(c.unfoundPlace, isNull); // not named: stays skipped
      await c.handleUserInput('Paris again, we must see Nowhere Cafe');
      expect(c.unfoundPlace, 'Nowhere Cafe');
      expect(c.controlField, 'unfound');
    });

    test('Spots wait while Lemon asks for the dates', () async {
      final api = Phase2Api()
        ..spots = parisSpots
        ..replies.addAll([
          LemonChatResult(
              reply: 'When would you like to go?',
              destination: 'Paris',
              destinationLabel: 'Paris, France',
              destinationStatus: 'verified',
              nextField: 'dates'),
          paris(),
        ]);
      final c = free(api);
      addTearDown(c.dispose);
      await c.handleUserInput('Paris');
      await pumpEventQueue();
      expect(c.spotsStatus, 'ready');
      expect(c.messages.where((m) => m.type == ChatMessageType.spots), isEmpty);
      await c.handleUserInput('10 to 11 December');
      await pumpEventQueue();
      expect(c.messages.where((m) => m.type == ChatMessageType.spots),
          hasLength(1));
    });

    test('Two places not found are asked about in turn', () async {
      final api = Phase2Api()
        ..replies.add(paris(mustVisit: [nowhere, ghost], ready: true));
      final c = free(api);
      addTearDown(c.dispose);
      await c.handleUserInput('Paris with Nowhere Cafe and Ghost Bar, plan it');
      expect(said(c, 'I have some questions'), isTrue);
      expect(c.unfoundPlace, 'Nowhere Cafe');
      c.continueWithoutUnfound();
      expect(said(c, "Next one! I couldn't find Ghost Bar"), isTrue);
      expect(c.unfoundPlace, 'Ghost Bar');
      c.continueWithoutUnfound();
      expect(c.unfoundPlace, isNull);
      expect(c.controlField, 'confirm');
      expect(api.planned, isNull);
    });

    test('A first message with "plan it" shows the brief first', () async {
      final api =
          Phase2Api()..replies.add(paris(ready: true, reply: 'Planning now!'));
      final c = free(api);
      addTearDown(c.dispose);
      await c.handleUserInput('2 days in Paris, plan it');
      expect(api.planned, isNull);
      expect(said(c, 'Planning now!'), isFalse);
      expect(said(c, 'Let me show you your trip brief first'), isTrue);
    });

    test('Lemon writes dates in words', () async {
      expect(LemonChatController.prettyDate('2026-12-12'), '12 December');
      final api =
          Phase2Api()..replies.add(paris(inferred: const ['end_date']));
      final c = free(api);
      addTearDown(c.dispose);
      await c.handleUserInput('Paris for two days');
      expect(said(c, 'a trip until ${LemonChatController.prettyDate(endIso)}'),
          isTrue);
      expect(said(c, 'a trip until $endIso'), isFalse);
    });

    testWidgets('Swap it and Continue without it work at every width',
        (tester) async {
      for (final width in [360.0, 800.0, 1440.0]) {
        final api = Phase2Api()
          ..spots = parisSpots
          ..replies.add(paris(mustVisit: [nowhere]));
        final c = free(api);
        await c.handleUserInput('Paris, we must see Nowhere Cafe');
        await pumpPanel(tester, c, width: width);
        await reveal(tester, find.text('Continue without it'));
        expect(find.text('Swap it'), findsOneWidget);
        await tester.tap(find.text('Swap it'));
        await tester.pumpAndSettle();
        await reveal(tester, find.text('Or type the name of another place below.'));
        expect(find.text('Eiffel Tower'), findsWidgets);
        await reveal(tester, find.text('Continue without it'));
        await tester.tap(find.text('Continue without it'));
        await tester.pumpAndSettle();
        expect(c.controlField, 'confirm', reason: 'width $width');
        expect(tester.takeException(), isNull, reason: 'width $width');
        c.dispose();
      }
    });
  });

  group('Matched place names (DECISIONS 071)', () {
    ItineraryActivity stop(String location, String? matched,
            {String status = 'verified'}) =>
        ItineraryActivity(
            time: '10:00',
            activity: 'Tea',
            location: location,
            placeStatus: status,
            placeName: matched);

    test('Shown only when the map name is not the stop name', () {
      expect(matchedPlaceLabel(stop('Hanamiya Kissa', 'Kissa Gobo Gobo')),
          'Matched: Kissa Gobo Gobo');
      expect(matchedPlaceLabel(stop('Fushimi Inari', 'Fushimi Inari-taisha')),
          isNull);
      expect(matchedPlaceLabel(stop('Louvre Museum', 'louvre museum')), isNull);
      expect(matchedPlaceLabel(stop('Somewhere', null)), isNull);
      expect(
          matchedPlaceLabel(
              stop('Hanamiya Kissa', 'Kissa Gobo Gobo', status: 'unverified')),
          isNull);
    });

    test('JSON carries the matched names both ways', () {
      final a = ItineraryActivity.fromJson({
        'time': '10:00',
        'activity': 'Tea',
        'place_status': 'verified',
        'place_name': 'Kissa Gobo Gobo'
      });
      expect(a.placeName, 'Kissa Gobo Gobo');
      expect(a.toJson()['place_name'], 'Kissa Gobo Gobo');
      final m = MustVisitPlace.fromJson(
          {'name': 'Hanamiya Kissa', 'status': 'verified', 'matched_name': 'Kissa Gobo Gobo'});
      expect(m.toJson()['matched_name'], 'Kissa Gobo Gobo');
      expect(const MustVisitPlace(name: 'Louvre').toJson().containsKey('matched_name'),
          isFalse);
    });

    testWidgets('The itinerary shows what a stop was matched to',
        (tester) async {
      for (final width in [360.0, 800.0, 1440.0]) {
        tester.view.physicalSize = Size(width, 1600);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        await tester.pumpWidget(MaterialApp(
            home: Scaffold(
                body: ItineraryView(
                    itinerary: ItineraryResponse(
                        destination: 'Kyoto, Japan',
                        providerUsed: 'groq',
                        days: [
                          ItineraryDay(day: 1, date: startIso, activities: [
                            stop('Hanamiya Kissa', 'Kissa Gobo Gobo'),
                          ]),
                        ]),
                    onOpenLemon: () {}))));
        await tester.pumpAndSettle();
        expect(find.text('Matched: Kissa Gobo Gobo'), findsOneWidget,
            reason: 'width $width');
        expect(tester.takeException(), isNull, reason: 'width $width');
      }
    });
  });

  group('Contracts', () {
    test('Plan JSON carries grounding; edits time out per provider turn', () {
      final stop = ItineraryActivity.fromJson({
        'time': '09:00',
        'activity': 'Louvre',
        'place_id': 'g1',
        'lat': 48.86,
        'lon': 2.33,
        'place_status': 'verified'
      });
      expect((stop.placeId, stop.lat, stop.placeStatus), ('g1', 48.86, 'verified'));
      expect(
          ItineraryActivity.fromJson({'time': '9', 'activity': 'x', 'place_status': 'made up'})
              .placeStatus,
          isNull);
      expect(LemonApiService.editTimeoutFor('auto'), const Duration(seconds: 250));
      expect(LemonApiService.editTimeoutFor('groq'), const Duration(seconds: 100));
      final json = TripRequest(
              destination: 'Paris',
              startDate: startIso,
              endDate: endIso,
              travelers: 1,
              budgetLevel: 'low',
              interests: const [],
              provider: 'auto',
              pace: 'packed',
              mustVisit: const [MustVisitPlace(name: 'Louvre')])
          .toJson();
      expect(json['pace'], 'packed');
      expect(json['must_visit'], [
        {'name': 'Louvre'}
      ]);
      final chat = LemonChatResult.fromJson({
        'reply': 'ok',
        'pace': 'nope',
        'must_visit': [
          {'name': 'Louvre', 'status': 'verified', 'place_id': 'g1'}
        ],
        'spots_to_lemon': true,
        'edit': {'action': 'swap_activity', 'day': 2, 'stop': 1},
      });
      expect(chat.pace, isNull);
      expect(chat.mustVisit.single.placeId, 'g1');
      expect(chat.spotsToLemon, isTrue);
      expect((chat.edit!.action, chat.edit!.day, chat.edit!.stop),
          ('swap_activity', 2, 1));
    });
  });
}

/// The backend's fixed reply for trip questions (chat_parser.PLAN_QUESTION_REPLY).
class LemonChatControllerTestText {
  static const question =
      "Ooh, great question! 🍋 I don't have that feature just yet, but it's coming soon! ✨ "
      'For now I can tweak your plan for you: regenerate a day, swap an activity or adjust a day. '
      'Just say the word! 🗺️';
}
