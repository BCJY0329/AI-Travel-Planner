import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travel_planner_frontend/models/travel_models.dart';
import 'package:travel_planner_frontend/screens/views/flights_view.dart';
import 'package:travel_planner_frontend/services/travel_api_service.dart';

class RecordingTravelApi extends TravelApiService {
  final dates = <String>[];

  @override
  Future<List<FlightOffer>> searchFlights({
    required String origin,
    required String destination,
    required String departureDate,
    int adults = 1,
  }) async {
    dates.add(departureDate);
    return [];
  }
}

void main() {
  for (final scenario in [
    (DateTime(2026, 10, 8, 23, 59), '2026-10-22'),
    (DateTime(2026, 12, 25), '2027-01-08'),
    (DateTime(2028, 2, 20), '2028-03-05'),
  ]) {
    testWidgets('Initial search and picker from ${scenario.$1}', (tester) async {
      final api = RecordingTravelApi();
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: FlightsView(apiService: api, now: () => scenario.$1)),
      ));
      await tester.pumpAndSettle();
      expect(api.dates, [scenario.$2]);
      await tester.tap(find.text(scenario.$2));
      await tester.pumpAndSettle();
      final picker = tester.widget<DatePickerDialog>(find.byType(DatePickerDialog));
      expect(picker.initialDate, DateTime.parse(scenario.$2));
      expect(picker.firstDate, DateUtils.dateOnly(scenario.$1));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Stale selection stays within picker and search bounds', (tester) async {
    var now = DateTime(2026, 10, 8);
    final api = RecordingTravelApi();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: FlightsView(apiService: api, now: () => now)),
    ));
    await tester.pumpAndSettle();
    now = DateTime(2026, 10, 23);
    await tester.tap(find.text('2026-10-22'));
    await tester.pumpAndSettle();
    var picker = tester.widget<DatePickerDialog>(find.byType(DatePickerDialog));
    expect(picker.initialDate, now);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Find Flights'));
    await tester.pumpAndSettle();
    expect(api.dates.last, '2026-10-23');
    expect(find.text('2026-10-23'), findsOneWidget);

    // A backward clock change must also keep initialDate below lastDate.
    now = DateTime(2024, 1, 1);
    await tester.tap(find.text('2026-10-23'));
    await tester.pumpAndSettle();
    picker = tester.widget<DatePickerDialog>(find.byType(DatePickerDialog));
    expect(picker.initialDate, picker.lastDate);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(api.dates.last, '2024-12-31');
    expect(tester.takeException(), isNull);
  });
}
