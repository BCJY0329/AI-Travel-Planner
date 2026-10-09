import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:travel_planner_frontend/services/travel_api_service.dart';
import 'package:travel_planner_frontend/screens/views/flights_view.dart';
import 'package:travel_planner_frontend/screens/views/attractions_view.dart';

void main() {
  for (final flights in [true, false]) {
    final name = flights ? 'flights' : 'attractions';
    final key = flights ? 'offers' : 'attractions';
    Future<List<dynamic>> search(TravelApiService api) => flights
        ? api.searchFlights(origin: ' kul ', destination: 'nrt', departureDate: '2026-11-01')
        : api.getAttractions(city: 'Paris & Versailles');
    test('$name preserve empty responses and propagate failures', () async {
      final empty = TravelApiService(client: MockClient((request) async {
        if (flights) {
          expect(request.url.queryParameters['origin'], 'KUL');
        } else {
          expect(request.url.queryParameters['city'], 'Paris & Versailles');
        }
        return http.Response('{"$key":[]}', 200);
      }));
      expect(await search(empty), isEmpty);
      for (final response in [http.Response('', 503), http.Response('{}', 200), http.Response('invalid', 200)]) {
        await expectLater(search(TravelApiService(client: MockClient((_) async => response))), throwsA(anything));
      }
      for (final error in [http.ClientException('offline'), TimeoutException('timeout')]) {
        await expectLater(search(TravelApiService(client: MockClient((_) async => throw error))), throwsA(anything));
      }
    });
    testWidgets('$name failure offers retry and recovers to empty', (tester) async {
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var calls = 0;
      final api = TravelApiService(client: MockClient((_) async {
        calls++;
        return calls == 1 ? http.Response('', 500) : http.Response('{"$key":[]}', 200);
      }));
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: flights
          ? FlightsView(apiService: api) : AttractionsView(apiService: api))));
      await tester.pumpAndSettle();
      expect(find.text('Unable to load $name. Please try again.'), findsOneWidget);
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(calls, 2);
      expect(find.text('Unable to load $name. Please try again.'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
