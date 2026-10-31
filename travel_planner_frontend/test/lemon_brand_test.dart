import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travel_planner_frontend/widgets/lemon_brand.dart';

Widget _brand({bool reduced = false}) => MaterialApp(
    home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduced),
        child: const Scaffold(body: Center(child: LemonBrand()))));

void main() {
  testWidgets('Wordmark reads as LemonTrip and its wave plays once',
      (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_brand());
    expect(find.bySemanticsLabel('LemonTrip'), findsOneWidget);
    // The colour wave is running, then finishes on its own (no loop).
    await tester.pump(const Duration(milliseconds: 600));
    expect(tester.binding.hasScheduledFrame, isTrue);
    await tester.pumpAndSettle();
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('Reduced motion shows the still wordmark', (tester) async {
    await tester.pumpWidget(_brand(reduced: true));
    await tester.pump();
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(find.byType(CustomPaint), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
