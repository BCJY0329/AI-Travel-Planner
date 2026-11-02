import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travel_planner_frontend/config/app_theme.dart';
import 'package:travel_planner_frontend/widgets/page_parts.dart';

/// The label style and resting elevation of the button showing [label].
(TextStyle, double) _look(WidgetTester tester, String label) {
  final style = DefaultTextStyle.of(tester.element(find.text(label))).style;
  final material = tester.widget<Material>(find
      .ancestor(of: find.text(label), matching: find.byType(Material))
      .first);
  return (style, material.elevation);
}

void main() {
  // DECISIONS 056: one button font everywhere, and filled buttons carry a
  // soft shadow at rest so none look flat. Both themes are checked because
  // the light theme (chat panel, app frame) has no body font of its own.
  for (final (name, theme) in [
    ('light', AppTheme.lightTheme),
    ('trip', AppTheme.tripTheme),
  ]) {
    testWidgets('Buttons share Outfit and look solid ($name theme)',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
          theme: theme,
          home: Scaffold(
              body: Column(children: [
            ElevatedButton(onPressed: () {}, child: const Text('Filled')),
            OutlinedButton(onPressed: () {}, child: const Text('Outlined')),
            TextButton(onPressed: () {}, child: const Text('Text')),
            ElevatedButton(
                onPressed: () {},
                style: planWithLemonStyle(),
                child: const Text('Plan')),
            const ElevatedButton(onPressed: null, child: Text('Off')),
          ]))));

      for (final label in ['Filled', 'Outlined', 'Text', 'Plan']) {
        final (style, _) = _look(tester, label);
        expect(style.fontFamily, AppTheme.buttonFont, reason: label);
      }
      expect(_look(tester, 'Filled').$1.fontWeight, FontWeight.w800);
      expect(_look(tester, 'Plan').$1.fontWeight, FontWeight.w800);
      expect(_look(tester, 'Outlined').$1.fontWeight, FontWeight.w700);
      expect(_look(tester, 'Filled').$2, greaterThan(0));
      expect(_look(tester, 'Plan').$2, greaterThan(0));
      expect(_look(tester, 'Outlined').$2, greaterThan(0));
      expect(_look(tester, 'Off').$2, 0, reason: 'disabled stays flat');
      expect(tester.getSize(find.byType(ElevatedButton).first).height,
          greaterThanOrEqualTo(48));
    });
  }
}
