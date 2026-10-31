import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:travel_planner_frontend/models/travel_models.dart';
import 'package:travel_planner_frontend/screens/views/attractions_view.dart';
import 'package:travel_planner_frontend/screens/views/flights_view.dart';
import 'package:travel_planner_frontend/screens/views/hotels_view.dart';
import 'package:travel_planner_frontend/services/travel_api_service.dart';

/// Records every request and answers each endpoint from [airports].
class Recorder {
  Recorder({this.airports = const ['ITM', 'KIX']});
  List<String> airports;
  final requests = <Uri>[];
  late final api = TravelApiService(
      client: MockClient((request) async {
        requests.add(request.url);
        final body = switch (request.url.path) {
          '/airports/search' => '{"airports":[${airports.map((code) => '{"iata_code":"$code","name":"$code Airport"}').join(',')}]}',
          '/flights/search' => '{"offers":[]}',
          '/places/attractions' => '{"attractions":[]}',
          _ => '{}',
        };
        return http.Response(body, 200);
      }),
      hotelClient: MockClient((request) async {
        requests.add(request.url);
        return http.Response('{"hotels":[]}', 200);
      }));
  List<Map<String, String>> searches(String path) => [
        for (final uri in requests)
          if (uri.path == path) uri.queryParameters
      ];
}

final kyoto = TripContext(
    destination: 'Kyoto', startDate: DateTime(2026, 11, 20), travelers: 2);

Future<void> show(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(1400, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Hotels and attractions start on the trip and follow a new one',
      (tester) async {
    for (final hotels in [true, false]) {
      final path = hotels ? '/hotels/search' : '/places/attractions';
      final rec = Recorder();
      Widget view(TripContext? trip) => hotels
          ? HotelsView(apiService: rec.api, trip: trip)
          : AttractionsView(apiService: rec.api, trip: trip);
      await show(tester, view(kyoto));
      expect(rec.searches(path).single['city'], 'Kyoto');

      // The user's own search stands until the next plan arrives.
      await tester.enterText(find.byType(TextField).first, 'Rome');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      await show(tester, view(kyoto));
      expect(rec.searches(path).last['city'], 'Rome');

      await show(
          tester,
          view(TripContext(
              destination: 'Osaka',
              startDate: DateTime(2026, 12, 1),
              travelers: 1)));
      expect(rec.searches(path).last['city'], 'Osaka');
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets('Without a trip the search tabs keep their defaults',
      (tester) async {
    final rec = Recorder();
    await show(tester, HotelsView(apiService: rec.api));
    expect(rec.searches('/hotels/search').single['city'], 'Paris');
  });

  testWidgets('Flights use the trip date, party and nearest airport',
      (tester) async {
    final rec = Recorder();
    await show(
        tester,
        FlightsView(
            apiService: rec.api,
            now: () => DateTime(2026, 10, 24),
            trip: kyoto));
    expect(rec.searches('/airports/search').single['place'], 'Kyoto');
    final search = rec.searches('/flights/search').single;
    expect(search['destination'], 'ITM');
    expect(search['origin'], 'KUL'); // the user's own origin is kept
    expect(search['departure_date'], '2026-11-20');
    expect(search['adults'], '2');
    expect(find.text('Airports for Kyoto:'), findsOneWidget);

    await tester.tap(find.text('KIX · KIX Airport'));
    await tester.pumpAndSettle();
    expect(rec.searches('/flights/search').last['destination'], 'KIX');
    expect(tester.takeException(), isNull);
  });

  testWidgets('Flights ask for an airport when none is known',
      (tester) async {
    final rec = Recorder(airports: []);
    await show(
        tester,
        FlightsView(
            apiService: rec.api,
            now: () => DateTime(2026, 10, 24),
            trip: TripContext(
                destination: 'Atlantis',
                startDate: DateTime(2026, 11, 20),
                travelers: 9)));
    expect(rec.searches('/flights/search'), isEmpty);
    expect(find.text('Enter the airport code for Atlantis to search flights.'),
        findsOneWidget);
    expect(find.text('Searching for 6 of your 9 travelers.'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}
