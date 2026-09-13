import 'package:flutter_test/flutter_test.dart';
import 'package:travel_planner_frontend/main.dart';

void main() {
  testWidgets('TravelPlannerApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const TravelPlannerApp());
    expect(find.text('VoyageAI'), findsOneWidget);
  });
}
