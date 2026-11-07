// The exact place on the brief and "Not this one?" (DECISIONS 068).
// Fake services only; never a live backend.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travel_planner_frontend/chat/lemon_chat_controller.dart';
import 'package:travel_planner_frontend/models/chat_models.dart';
import 'package:travel_planner_frontend/services/chat_settings.dart';

import 'lemon_free_mode_test.dart'
    show QueueLemonApi, free, pumpPanel, startIso, endIso;

LemonChatResult paris({List<String> alternatives = const []}) =>
    LemonChatResult(
        reply: 'Paris, lovely!',
        destination: 'Paris',
        destinationLabel: 'Paris, France',
        destinationAlternatives: alternatives,
        startDate: startIso,
        endDate: endIso,
        destinationStatus: 'verified',
        nextField: 'confirm');

void main() {
  test('Reads the label and alternatives from JSON', () {
    final r = LemonChatResult.fromJson({
      'reply': 'ok',
      'destination': 'Rome',
      'destination_status': 'verified',
      'destination_label': ' Rome, Italy ',
      'destination_alternatives': ['Rome, Georgia, United States'],
    });
    expect(r.destinationLabel, 'Rome, Italy');
    expect(r.destinationAlternatives, ['Rome, Georgia, United States']);
    expect(LemonChatResult.fromJson({'reply': 'x', 'destination_label': ' '})
        .destinationLabel, isNull);
  });

  test('The plan and search tabs use the exact place', () async {
    final api = QueueLemonApi()..replies.add(paris());
    final c = free(api);
    addTearDown(c.dispose);
    await c.handleUserInput('Paris for 4 days');
    expect((c.destination, c.placeName), ('Paris', 'Paris, France'));
    await c.confirmTrip();
    expect(api.planned!.destination, 'Paris, France');
    expect(c.latestTrip!.destination, 'Paris, France');
  });

  test('Without a label the plan uses the name as typed', () async {
    final api = QueueLemonApi()
      ..replies.add(LemonChatResult(
          reply: 'ok',
          destination: 'Kyoto',
          destinationStatus: 'unverified',
          startDate: startIso,
          endDate: endIso,
          nextField: 'confirm'));
    final c = free(api);
    addTearDown(c.dispose);
    await c.handleUserInput('Kyoto');
    await c.confirmTrip();
    expect(api.planned!.destination, 'Kyoto');
  });

  test('Picking an alternative replaces the place without a call', () async {
    final api = QueueLemonApi()
      ..replies.add(paris(alternatives: ['Paris, Texas, United States']));
    final c = free(api);
    addTearDown(c.dispose);
    await c.handleUserInput('Paris');
    c.pickDestination('Paris, Texas, United States');
    expect(api.chats, 1);
    expect(c.placeName, 'Paris, Texas, United States');
    expect(c.destinationAlternatives, isEmpty);
    expect(c.nextField, 'confirm');
    c.pickDestination('Paris, Ontario'); // not offered: ignored
    expect(c.placeName, 'Paris, Texas, United States');
  });

  test('Editing the destination or starting over clears the label', () async {
    final api = QueueLemonApi()
      ..replies.add(paris(alternatives: ['Paris, Texas, United States']));
    final c = free(api);
    addTearDown(c.dispose);
    await c.handleUserInput('Paris');
    c.editField('destination');
    expect(c.placeName, isNull);
    expect(c.destinationAlternatives, isEmpty);
    expect(c.nextField, 'destination');

    final again = QueueLemonApi()
      ..replies.add(paris(alternatives: ['Paris, Texas, United States']));
    final d = free(again);
    addTearDown(d.dispose);
    await d.handleUserInput('Paris');
    d.startOver();
    expect(d.placeName, isNull);
    expect(d.destinationAlternatives, isEmpty);
  });

  test('Guided mode keeps the label too', () async {
    final api = QueueLemonApi()..replies.add(paris());
    final c = LemonChatController(
        api: api, mode: ChatMode.guided, settings: MemoryChatSettingsStore());
    addTearDown(c.dispose);
    await c.handleUserInput('Paris');
    expect(c.placeName, 'Paris, France');
    expect(c.nextField, 'dates');
  });

  testWidgets('No "Not this one?" when no other place shares the name',
      (tester) async {
    final api = QueueLemonApi()..replies.add(paris());
    final c = free(api);
    addTearDown(c.dispose);
    await pumpPanel(tester, c);
    await tester.enterText(find.byType(TextField), 'Paris');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pumpAndSettle();
    expect(find.text('Paris, France'), findsOneWidget);
    expect(find.text('Not this one?'), findsNothing);
  });

  for (final width in [360.0, 800.0, 1440.0]) {
    testWidgets('"Not this one?" pop-up picks another place at $width',
        (tester) async {
      final api = QueueLemonApi()
        ..replies.add(paris(alternatives: [
          'Paris, Texas, United States',
          'Paris, Tennessee, United States'
        ]));
      final c = free(api);
      addTearDown(c.dispose);
      await pumpPanel(tester, c, width: width);
      await tester.enterText(find.byType(TextField), 'Paris');
      await tester.testTextInput.receiveAction(TextInputAction.send);
      await tester.pumpAndSettle();
      expect(find.text('Paris, France'), findsOneWidget);
      await tester.ensureVisible(find.text('Not this one?'));
      await tester.tap(find.text('Not this one?'));
      await tester.pumpAndSettle();
      expect(find.text('Which Paris, France did you mean?'), findsOneWidget);
      expect(find.text('Somewhere else…'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Paris, Texas, United States'));
      await tester.pumpAndSettle();
      expect(c.placeName, 'Paris, Texas, United States');
      expect(find.text('Not this one?'), findsNothing);
      expect(api.chats, 1);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('"Somewhere else…" asks for a new place', (tester) async {
    final api = QueueLemonApi()
      ..replies.add(paris(alternatives: ['Paris, Texas, United States']));
    final c = free(api);
    addTearDown(c.dispose);
    await pumpPanel(tester, c);
    await tester.enterText(find.byType(TextField), 'Paris');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Not this one?'));
    await tester.tap(find.text('Not this one?'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Somewhere else…'));
    await tester.pumpAndSettle();
    expect((c.placeName, c.nextField), (null, 'destination'));
    expect(find.textContaining('Where would you like to go instead?'),
        findsOneWidget);
  });
}
