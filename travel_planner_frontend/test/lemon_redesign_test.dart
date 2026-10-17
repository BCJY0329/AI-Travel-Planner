import 'dart:async';
import 'package:travel_planner_frontend/widgets/lemon_bubble.dart';
import 'dart:ui' show PointerDeviceKind;
import 'package:flutter/services.dart';
import 'package:travel_planner_frontend/widgets/hover_lift.dart';
import 'package:travel_planner_frontend/widgets/gentle_reveal.dart';
import 'package:travel_planner_frontend/widgets/trip_date_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travel_planner_frontend/chat/lemon_chat_controller.dart';

import 'package:travel_planner_frontend/config/app_theme.dart';
import 'package:travel_planner_frontend/models/chat_models.dart';
import 'package:travel_planner_frontend/models/itinerary_models.dart';
import 'package:travel_planner_frontend/services/lemon_api_service.dart';
import 'package:travel_planner_frontend/widgets/lemon_chat_panel.dart';
import 'package:travel_planner_frontend/screens/views/itinerary_view.dart';
import 'package:travel_planner_frontend/main.dart';

class FakeLemonApi extends LemonApiService {
  int chats = 0, plans = 0;
  bool failChat = false, failPlan = false;
  Completer<LemonChatResult>? pending;
  TripRequest? request;
  List<ChatTurn> lastHistory = [];
  @override
  Future<LemonChatResult> sendChatTurn(
      {required List<ChatTurn> messages, required String provider}) async {
    chats++;
    lastHistory = List.of(messages);
    if (failChat) throw Exception('offline');
    if (pending != null) return await pending!.future;
    return LemonChatResult(reply: 'Ready', destination: 'Kyoto', ready: true);
  }

  @override
  Future<ItineraryResponse> planTrip(TripRequest value) async {
    plans++;
    request = value;
    if (failPlan) throw Exception('offline');
    return trip(2);
  }
}

ItineraryResponse trip(int count) => ItineraryResponse(
    destination: 'Kyoto',
    providerUsed: 'groq',
    days: List.generate(
        count,
        (i) => ItineraryDay(day: i + 1, date: '2026-11-01', activities: [
              ItineraryActivity(time: '09:00', activity: 'Activity ${i + 1}')
            ])));
Future<void> fill(LemonChatController c) async {
  c.startIfNeeded();
  await c.handleUserInput('Kyoto');
  final start =
      DateUtils.dateOnly(DateTime.now()).add(const Duration(days: 14));
  c.setDates(start, start.add(const Duration(days: 4)));
  c.setTravelers(2);
  c.setBudget('medium');
  c.setInterests(['Food', 'Gentle walks']);
}

void main() {
  test('Greetings rotate and noise preserves the current step and trip',
      () async {
    final api = FakeLemonApi();
    final c = LemonChatController(api: api);
    addTearDown(c.dispose);
    for (final greeting in ['hi', 'hello!', 'good morning']) {
      await c.handleUserInput(greeting);
    }
    expect(api.chats, 0);
    for (final reply in LemonChatController.greetings) {
      expect(c.messages.any((message) => message.text?.contains(reply) == true),
          isTrue);
    }
    await c.handleUserInput('asdfghjkl');
    expect(api.chats, 0);
    expect(c.nextField, 'destination');
    expect(c.error, isNull);
    await c.handleUserInput('Kyoto');
    expect(c.destination, 'Kyoto');
    await c.handleUserInput('!!!!!');
    expect(c.nextField, 'dates');
    expect(c.destination, 'Kyoto');
    expect(c.error, isNull);
    await c.handleUserInput('hi');
    expect(c.nextField, 'dates');
    expect(api.chats, 1);
  });

  testWidgets('Physical Enter sends once and busy Enter preserves draft',
      (tester) async {
    final api = FakeLemonApi()..pending = Completer<LemonChatResult>();
    final c = LemonChatController(api: api);
    addTearDown(c.dispose);
    c.startIfNeeded();
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: LemonChatPanel(controller: c, onClose: () {}))));
    await tester.enterText(find.byType(TextField), 'Kyoto');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(api.chats, 1);
    await tester.enterText(find.byType(TextField), 'Keep me');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(api.chats, 1);
    expect(c.draft, 'Keep me');
    api.pending!.complete(LemonChatResult(reply: 'Where?', ready: false));
    await tester.pumpAndSettle();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();
    expect(api.chats, 1);
  });
  testWidgets('Desktop chat expands without losing its draft', (tester) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const TravelPlannerApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byType(LemonBubble));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'My draft');
    final before = tester.getSize(find.byType(LemonChatPanel)).width;
    await tester.tap(find.byTooltip('Enlarge chat'));
    await tester.pumpAndSettle();
    expect(
        tester.getSize(find.byType(LemonChatPanel)).width, greaterThan(before));
    expect(find.text('My draft'), findsOneWidget);
    await tester.tap(find.byTooltip('Shrink chat'));
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(LemonChatPanel)).width, before);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Hover scales an option and reduced motion disables scale',
      (tester) async {
    Widget view(bool reduced) => MaterialApp(
        home: MediaQuery(
            data: MediaQueryData(disableAnimations: reduced),
            child: const Center(
                child: HoverLift(child: SizedBox(width: 100, height: 60)))));
    await tester.pumpWidget(view(false));
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(find.byType(HoverLift)));
    await tester.pumpAndSettle();
    expect(tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale,
        greaterThan(1));
    await tester.pumpWidget(view(true));
    await tester.pumpAndSettle();
    expect(tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale, 1);
    await mouse.removePointer();
  });

  testWidgets('Reduced motion skips entrance animation', (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: MediaQuery(
            data: MediaQueryData(disableAnimations: true),
            child: GentleReveal(child: Text('Still')))));
    expect(find.byType(TweenAnimationBuilder<double>), findsNothing);
    expect(find.text('Still'), findsOneWidget);
  });
  testWidgets('Activities with and without tips fill the same width',
      (tester) async {
    final value =
        ItineraryResponse(destination: 'Kyoto', providerUsed: 'groq', days: [
      ItineraryDay(day: 1, activities: [
        ItineraryActivity(time: '09:00', activity: 'Short'),
        ItineraryActivity(
            time: '10:00', activity: 'Longer stop', notes: 'Enjoy the gardens'),
      ])
    ]);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: ItineraryView(itinerary: value, onOpenLemon: () {}))));
    final short = find
        .ancestor(of: find.text('Short'), matching: find.byType(Container))
        .first;
    final long = find
        .ancestor(
            of: find.text('Longer stop'), matching: find.byType(Container))
        .first;
    expect(tester.getSize(short).width, tester.getSize(long).width);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'Traveler entry rejects invalid values and accepts a whole number',
      (tester) async {
    final c = LemonChatController(api: FakeLemonApi())..nextField = 'travelers';
    addTearDown(c.dispose);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: LemonChatPanel(controller: c, onClose: () {}))));
    for (final value in ['', '0', '21', '1.5', 'abc']) {
      await tester.enterText(find.byType(TextField), value);
      await tester.tap(find.text('Continue'));
      await tester.pump();
      expect(c.travelers, isNull);
      expect(find.text('Enter a whole number from 1 to 20.'), findsOneWidget);
    }
    await tester.enterText(find.byType(TextField), '4');
    await tester.tap(find.text('Continue'));
    await tester.pump();
    expect(c.travelers, 4);
  });
  testWidgets(
      'Calendar end edits preserve start and explicit start change resets end',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: TripDateDialog(today: DateTime(2026, 11, 1)))));
    void select(int day) => tester
        .widget<CalendarDatePicker>(find.byType(CalendarDatePicker))
        .onDateChanged(DateTime(2026, 11, day));
    select(2);
    await tester.pump();
    select(5);
    await tester.pump();
    select(7);
    await tester.pump();
    expect(find.textContaining('6 days, including'), findsOneWidget);
    select(1);
    await tester.pump();
    expect(find.textContaining('Choose an end on or after'), findsOneWidget);
    expect(find.textContaining('6 days, including'), findsOneWidget);
    await tester.tap(find.text('Change start'));
    await tester.pump();
    select(4);
    await tester.pump();
    expect(find.text('End: Choose date'), findsOneWidget);
    await tester.tap(find.text('Just this day'));
    await tester.pump();
    expect(find.textContaining('1 days, including'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('Guided choices reach plan unchanged and require explicit confirmation',
      () async {
    final api = FakeLemonApi();
    final c = LemonChatController(api: api);
    addTearDown(c.dispose);
    await fill(c);
    expect(c.nextField, 'confirm');
    expect(api.plans, 0);
    expect(api.chats, 1);
    await c.confirmTrip();
    expect(api.request!.interests, ['Food', 'Gentle walks']);
    expect(api.request!.travelers, 2);
    expect(api.request!.budgetLevel, 'medium');
    expect(c.phase, ChatPhase.done);
  });
  test('Chat retry preserves the failed user turn without duplication',
      () async {
    final api = FakeLemonApi()..failChat = true;
    final c = LemonChatController(api: api);
    addTearDown(c.dispose);
    c.startIfNeeded();
    await c.handleUserInput('Kyoto');
    expect(c.error, isNotNull);
    api.failChat = false;
    await c.retry();
    expect(api.lastHistory.where((m) => m.role == 'user').length, 1);
    expect(c.destination, 'Kyoto');
    expect(c.nextField, 'dates');
  });
  test('Generation retry preserves fields and repeats only the plan call',
      () async {
    final api = FakeLemonApi()..failPlan = true;
    final c = LemonChatController(api: api);
    addTearDown(c.dispose);
    await fill(c);
    await c.confirmTrip();
    expect(c.error, isNotNull);
    expect(c.destination, 'Kyoto');
    expect(c.interests, ['Food', 'Gentle walks']);
    api.failPlan = false;
    await c.retry();
    expect(api.chats, 1);
    expect(api.plans, 2);
    expect(c.error, isNull);
  });
  test('Invalid structured fields cannot advance or generate', () async {
    final api = FakeLemonApi();
    final c = LemonChatController(api: api);
    addTearDown(c.dispose);
    await c.handleUserInput('Kyoto');
    final start =
        DateUtils.dateOnly(DateTime.now()).add(const Duration(days: 2));
    c.setDates(start, start.subtract(const Duration(days: 1)));
    expect(c.startDate, isNull);
    c.setTravelers(0);
    c.setBudget('anything');
    expect(c.travelers, isNull);
    expect(c.budgetLevel, isNull);
    await c.confirmTrip();
    expect(api.plans, 0);
  });
  testWidgets('Busy Enter retains draft and panel closure preserves it',
      (tester) async {
    final api = FakeLemonApi()..pending = Completer<LemonChatResult>();
    final c = LemonChatController(api: api);
    addTearDown(c.dispose);
    c.startIfNeeded();
    Widget panel() => MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
            body: SizedBox(
                width: 420,
                child: LemonChatPanel(controller: c, onClose: () {}))));
    await tester.pumpWidget(panel());
    await tester.enterText(find.byType(TextField), 'Kyoto');
    await tester.tap(find.byTooltip('Send message'));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'Keep this draft');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(c.draft, 'Keep this draft');
    expect(api.chats, 1);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(panel());
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Keep this draft');
    api.pending!.complete(LemonChatResult(reply: 'Where?', ready: false));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  testWidgets('Interests support multiple chips, Other and explicit continue',
      (tester) async {
    final c = LemonChatController(api: FakeLemonApi());
    addTearDown(c.dispose);
    c.nextField = 'interests';
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: LemonChatPanel(controller: c, onClose: () {}))));
    await tester.tap(find.text('Food'));
    await tester.tap(find.text('Nature'));
    await tester.enterText(find.byType(TextField), 'Gentle walks');
    await tester.pump();
    expect(c.interests, isEmpty);
    await tester.tap(find.text('Continue with these interests'));
    await tester.pumpAndSettle();
    expect(c.interests, ['Food', 'Nature', 'Gentle walks']);
    expect(tester.takeException(), isNull);
  });
  testWidgets('New shorter itinerary resets old day filter', (tester) async {
    Widget screen(ItineraryResponse value) => MaterialApp(
        home: Scaffold(
            body: ItineraryView(itinerary: value, onOpenLemon: () {})));
    await tester.pumpWidget(screen(trip(5)));
    await tester.tap(find.text('Day 5').first);
    await tester.pump();
    await tester.pumpWidget(screen(trip(1)));
    await tester.pumpAndSettle();
    expect(find.text('Activity 1'), findsOneWidget);
    expect(find.text('All days'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  for (final width in [360.0, 1440.0]) {
    testWidgets('Itinerary cards adapt and reveal tips at $width',
        (tester) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final value = ItineraryResponse(
          destination: 'Kyoto',
          providerUsed: 'groq',
          days: List.generate(
              2,
              (i) => ItineraryDay(day: i + 1, activities: [
                    ItineraryActivity(
                        time: '09:00',
                        activity: 'Explore the gardens',
                        location: 'Garden entrance',
                        notes: 'Bring comfortable shoes'),
                  ])));
      await tester.pumpWidget(MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
              body: ItineraryView(itinerary: value, onOpenLemon: () {}))));
      await tester.pumpAndSettle();
      final first = tester.getTopLeft(find.text('Explore the gardens').first);
      final second = tester.getTopLeft(find.text('Explore the gardens').last);
      if (width > 1050) {
        expect(first.dy, second.dy);
        expect(second.dx, greaterThan(first.dx));
      } else {
        expect(second.dy, greaterThan(first.dy));
      }
      await tester.tap(find.text("A little tip from Lemon").first);
      await tester.pumpAndSettle();
      expect(find.text('Bring comfortable shoes'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  for (final width in [360.0, 800.0, 1440.0]) {
    testWidgets('Dashboard and assistant fit width $width', (tester) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const TravelPlannerApp());
      await tester.pumpAndSettle();
      expect(find.text('LemonTrip'), findsOneWidget);
      expect(tester.takeException(), isNull);
      if (width < 1050) {
        await tester.tap(find.byTooltip('Navigation'));
        await tester.pumpAndSettle();
        expect(find.text('My itinerary'), findsOneWidget);
        await tester.tap(find.text('My itinerary'));
        await tester.pumpAndSettle();
      }
      await tester.tap(find.byType(LemonBubble));
      await tester.pumpAndSettle();
      expect(find.text('Lemon.ai'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
