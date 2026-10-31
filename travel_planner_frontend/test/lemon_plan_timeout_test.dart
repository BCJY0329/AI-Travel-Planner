import 'package:flutter_test/flutter_test.dart';
import 'package:travel_planner_frontend/models/itinerary_models.dart';
import 'package:travel_planner_frontend/services/lemon_api_service.dart';

TripRequest trip(String start, String end) => TripRequest(
      destination: 'Kyoto',
      startDate: start,
      endDate: end,
      travelers: 1,
      budgetLevel: 'medium',
      interests: const [],
      provider: 'auto',
    );

void main() {
  test('plan timeout scales with waves and matches the backend budget plus 25 s', () {
    // Backend: 75 s per wave of up to three 3-day windows (itinerary_builder.py).
    final cases = {
      ('2026-11-01', '2026-11-01'): 100, // 1 day, 1 wave (the old flat value)
      ('2026-11-01', '2026-11-09'): 100, // 9 days, 1 wave
      ('2026-11-01', '2026-11-10'): 175, // 10 days, 2 waves
      ('2026-11-01', '2026-11-18'): 175, // 18 days, 2 waves
      ('2026-11-01', '2026-11-19'): 250, // 19 days, 3 waves
      ('2026-11-01', '2026-11-30'): 325, // 30 days (maximum), 4 waves
    };
    cases.forEach((range, seconds) {
      expect(LemonApiService.planTimeoutFor(trip(range.$1, range.$2)),
          Duration(seconds: seconds),
          reason: '${range.$1}..${range.$2}');
    });
  });

  test('plan timeout counts calendar days across a daylight-saving change', () {
    // 10 days spanning the late-October European clock change: still 2 waves.
    expect(LemonApiService.planTimeoutFor(trip('2026-10-20', '2026-10-29')),
        const Duration(seconds: 175));
  });

  test('malformed dates fall back to a single wave', () {
    expect(LemonApiService.planTimeoutFor(trip('soon', 'later')),
        const Duration(seconds: 100));
  });
}
