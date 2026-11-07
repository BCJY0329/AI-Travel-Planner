import 'package:flutter_test/flutter_test.dart';
import 'package:travel_planner_frontend/models/itinerary_models.dart';
import 'package:travel_planner_frontend/services/lemon_api_service.dart';

TripRequest trip(String start, String end, {String provider = 'auto'}) =>
    TripRequest(
      destination: 'Kyoto',
      startDate: start,
      endDate: end,
      travelers: 1,
      budgetLevel: 'medium',
      interests: const [],
      provider: provider,
    );

void main() {
  test('auto plan timeout gives each of the three providers a full budget', () {
    // Backend: 75 s per wave of up to three 3-day windows (itinerary_builder.py),
    // and with auto a failed provider restarts the whole plan with a fresh
    // budget (DECISIONS 060): 25 s + 3 x 75 s x waves.
    final cases = {
      ('2026-11-01', '2026-11-01'): 250, // 1 day, 1 wave
      ('2026-11-01', '2026-11-09'): 250, // 9 days, 1 wave
      ('2026-11-01', '2026-11-10'): 475, // 10 days, 2 waves
      ('2026-11-01', '2026-11-18'): 475, // 18 days, 2 waves
      ('2026-11-01', '2026-11-19'): 700, // 19 days, 3 waves
      ('2026-11-01', '2026-11-30'): 925, // 30 days (maximum), 4 waves
    };
    cases.forEach((range, seconds) {
      expect(LemonApiService.planTimeoutFor(trip(range.$1, range.$2)),
          Duration(seconds: seconds),
          reason: '${range.$1}..${range.$2}');
    });
  });

  test('a single named provider gets one budget', () {
    expect(
        LemonApiService.planTimeoutFor(
            trip('2026-11-01', '2026-11-09', provider: 'groq')),
        const Duration(seconds: 100));
    expect(
        LemonApiService.planTimeoutFor(
            trip('2026-11-01', '2026-11-30', provider: 'gemini')),
        const Duration(seconds: 325));
  });

  test('plan timeout counts calendar days across a daylight-saving change', () {
    // 10 days spanning the late-October European clock change: still 2 waves.
    expect(LemonApiService.planTimeoutFor(trip('2026-10-20', '2026-10-29')),
        const Duration(seconds: 475));
  });

  test('malformed dates fall back to a single wave', () {
    expect(LemonApiService.planTimeoutFor(trip('soon', 'later')),
        const Duration(seconds: 250));
  });
}
