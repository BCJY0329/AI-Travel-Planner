import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travel_planner_frontend/chat/lemon_chat_controller.dart';
import 'package:travel_planner_frontend/config/app_theme.dart';
import 'package:travel_planner_frontend/models/chat_models.dart';
import 'package:travel_planner_frontend/models/itinerary_models.dart';
import 'package:travel_planner_frontend/screens/views/attractions_view.dart';
import 'package:travel_planner_frontend/screens/views/discover_view.dart';
import 'package:travel_planner_frontend/widgets/chat_parts.dart';
import 'package:travel_planner_frontend/widgets/lemon_chat_panel.dart';
import 'package:travel_planner_frontend/widgets/page_parts.dart';

import 'lemon_redesign_test.dart' show FakeLemonApi, trip;
import 'page_redesign_test.dart' show FakeTravelApi, pumpAt;

/// Holds the plan request open so the planning card stays on screen.
class _SlowPlanApi extends FakeLemonApi {
  final plan = Completer<ItineraryResponse>();
  @override
  Future<ItineraryResponse> planTrip(TripRequest value) => plan.future;
}

// DECISIONS 057: the chat panel polish mocked on the canvas.
void main() {
  Future<LemonChatController> panel(WidgetTester tester,
      {FakeLemonApi? api, String? field, bool reduced = false}) async {
    final c = LemonChatController(mode: ChatMode.guided, api: api ?? FakeLemonApi());
    addTearDown(c.dispose);
    c.startIfNeeded();
    if (field != null) c.nextField = field;
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: MediaQuery(
            data: MediaQueryData(
                size: const Size(420, 900), disableAnimations: reduced),
            child: Scaffold(
                body: SizedBox(
                    width: 420,
                    child: LemonChatPanel(controller: c, onClose: () {}))))));
    await tester.pumpAndSettle();
    return c;
  }

  testWidgets('Pill chat box holds the field and the send arrow',
      (tester) async {
    await panel(tester);
    expect(find.text('Try Kyoto, or a beach trip in Bali'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_upward_rounded), findsOneWidget);
    // The send button sits inside the pill, to the right of the field.
    final field = tester.getRect(find.byType(TextField));
    final send = tester.getRect(find.byTooltip('Send message'));
    expect(send.left, greaterThan(field.right - 1));
    expect((send.center.dy - field.center.dy).abs(), lessThan(4));
    expect(tester.takeException(), isNull);
  });

  testWidgets('New messages rise in; earlier ones are already there',
      (tester) async {
    final c = await panel(tester);
    final greeting = tester.widget<RiseIn>(find.byType(RiseIn).first);
    expect(greeting.play, isFalse, reason: 'shown when the panel opened');
    await tester.enterText(find.byType(TextField), 'Kyoto');
    await tester.tap(find.byTooltip('Send message'));
    await tester.pump();
    final rises = tester.widgetList<RiseIn>(find.byType(RiseIn)).toList();
    expect(rises.where((r) => r.play).length, greaterThanOrEqualTo(1));
    await tester.pumpAndSettle();
    expect(c.messages.length, greaterThan(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Typing dots show while Lemon reads the destination',
      (tester) async {
    final api = FakeLemonApi()..pending = Completer<LemonChatResult>();
    await panel(tester, api: api);
    await tester.enterText(find.byType(TextField), 'Kyoto');
    await tester.tap(find.byTooltip('Send message'));
    await tester.pump();
    expect(find.byType(TypingDots), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    api.pending!.complete(LemonChatResult(reply: 'Lovely', ready: false));
    await tester.pumpAndSettle();
    expect(find.byType(TypingDots), findsNothing);
  });

  testWidgets('Planning card replaces the spinner while the plan builds',
      (tester) async {
    final api = _SlowPlanApi();
    final c = await panel(tester, api: api);
    c
      ..destination = 'Kyoto'
      ..startDate = '2026-11-14'
      ..endDate = '2026-11-16'
      ..travelers = 2
      ..budgetLevel = 'medium'
      ..setInterests(['Food'])
      ..setPace('balanced')
      ..confirmSpots();
    unawaited(c.confirmTrip());
    await tester.pumpAndSettle();
    expect(find.byType(PlanningCard), findsOneWidget);
    expect(find.text('Lemon is planning your trip'), findsOneWidget);
    expect(find.text(PlanningCard.lines.first), findsOneWidget);
    expect(find.textContaining('keep browsing'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    api.plan.complete(trip(2));
    await tester.pumpAndSettle();
    expect(find.byType(PlanningCard), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Budget choices are option pills with hints', (tester) async {
    final c = await panel(tester, field: 'budget_level');
    expect(find.byType(OptionPill), findsNWidgets(3));
    for (final hint in [
      'Simple stays, local food, free sights',
      'Mid-range stays and a few treats',
      'Top hotels and special experiences',
    ]) {
      expect(find.text(hint), findsOneWidget);
    }
    expect(tester.widget<Text>(find.text('Comfortable')).style?.fontFamily,
        AppTheme.buttonFont);
    await tester.tap(find.text('Comfortable'));
    await tester.pumpAndSettle();
    expect(c.budgetLevel, 'medium');
    expect(tester.takeException(), isNull);
  });

  testWidgets('Picked interests fill sky blue and show a tick', (tester) async {
    await panel(tester, field: 'interests');
    expect(find.byType(InterestPill), findsNWidgets(8));
    expect(
        find.descendant(
            of: find.byType(InterestPill),
            matching: find.byIcon(Icons.check_rounded)),
        findsNothing);
    await tester.tap(find.text('Food'));
    await tester.pumpAndSettle();
    final food =
        find.ancestor(of: find.text('Food'), matching: find.byType(Material));
    expect(tester.widget<Material>(food.first).color, AppTheme.cta);
    expect(
        find.descendant(
            of: find.byType(InterestPill),
            matching: find.byIcon(Icons.check_rounded)),
        findsOneWidget);
    expect(find.text('1 picked · tap again to remove'), findsOneWidget);
    await tester.tap(find.text('Food'));
    await tester.pumpAndSettle();
    expect(
        find.descendant(
            of: find.byType(InterestPill),
            matching: find.byIcon(Icons.check_rounded)),
        findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Chat polish holds with no motion', (tester) async {
    for (final field in ['destination', 'budget_level', 'interests']) {
      await panel(tester, field: field, reduced: true);
      expect(tester.takeException(), isNull, reason: field);
    }
  });

  testWidgets('Search cards sit centred on wide screens', (tester) async {
    await pumpAt(tester, 1440, AttractionsView(apiService: FakeTravelApi()));
    final card = tester.getRect(find
        .descendant(
            of: find.byType(SearchCard), matching: find.byType(Container))
        .first);
    final page = tester.getRect(find.byType(SearchCard));
    expect((card.center.dx - page.center.dx).abs(), lessThan(1));
    expect(card.width, lessThan(page.width));
  });

  testWidgets('Explore places is filled with its outline colour',
      (tester) async {
    await pumpAt(
        tester, 1440, DiscoverView(onOpenLemon: () {}, onSelectTab: (_) {}));
    final button = tester.widget<OutlinedButton>(find.ancestor(
        of: find.text('Explore places'),
        matching: find.byType(OutlinedButton)));
    expect(button.style?.backgroundColor?.resolve({}), AppTheme.ctaEdge);
    expect(button.style?.elevation?.resolve({}), greaterThan(0));
  });
}
