import 'dart:ui' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:travel_planner_frontend/main.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travel_planner_frontend/widgets/lemon_bubble.dart';

void main() {
  testWidgets('Desktop dashboard has no layout exceptions', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const TravelPlannerApp());
    await tester.pumpAndSettle();
  });
  Widget launcher(VoidCallback onTap, {bool reduced = false}) => MaterialApp(
      home: MediaQuery(
          data: MediaQueryData(
              size: const Size(360, 800),
              disableAnimations: reduced,
              textScaler: const TextScaler.linear(1.5)),
          child: Scaffold(
              body: Align(
                  alignment: Alignment.bottomRight,
                  child: LemonBubble(onTap: onTap)))));

  testWidgets(
      'Hover reveals artwork and cycles invitations without opening chat',
      (tester) async {
    var opened = 0;
    await tester.pumpWidget(launcher(() => opened++));
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(find.byType(LemonBubble)));
    await tester.pumpAndSettle();
    expect(
        find.text('Turn your dream plan into an itinerary!'), findsOneWidget);
    expect(opened, 0);
    expect(tester.takeException(), isNull);
    await mouse.moveTo(Offset.zero);
    await tester.pumpAndSettle();
    await mouse.moveTo(tester.getCenter(find.byType(LemonBubble)));
    await tester.pumpAndSettle();
    expect(find.text('Your next adventure called. Shall we make a plan?'),
        findsOneWidget);
    await tester.tap(find.byType(LemonBubble));
    expect(opened, 1);
    await mouse.removePointer();
  });

  testWidgets('Keyboard focus reveals invitation and Enter opens chat',
      (tester) async {
    var opened = 0;
    await tester.pumpWidget(launcher(() => opened++, reduced: true));
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    expect(
        find.text('Turn your dream plan into an itinerary!'), findsOneWidget);
    expect(find.byType(AnimatedSize), findsNothing);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(opened, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Touch opens chat directly without requiring hover',
      (tester) async {
    var opened = 0;
    await tester.pumpWidget(launcher(() => opened++));
    await tester.tap(find.byType(LemonBubble));
    expect(opened, 1);
  });
}
