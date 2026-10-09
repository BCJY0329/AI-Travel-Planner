import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:travel_planner_frontend/services/travel_api_service.dart';
import 'package:travel_planner_frontend/screens/views/hotels_view.dart';

void main() {
  TravelApiService api(http.Response response) => TravelApiService(
    hotelClient: MockClient((_) async => response),
  );

  test('Empty listings stay empty; failures never become fictional hotels', () async {
    expect(await api(http.Response('{"hotels":[]}', 200)).searchHotels(city: 'Paris'), isEmpty);
    for (final response in [http.Response('', 503), http.Response('{}', 200), http.Response('invalid', 200)]) {
      await expectLater(api(response).searchHotels(city: 'Paris'), throwsA(anything));
    }
    for (final error in [http.ClientException('offline'), TimeoutException('timeout')]) {
      final service = TravelApiService(hotelClient: MockClient((_) async => throw error));
      await expectLater(service.searchHotels(city: 'Paris'), throwsA(anything));
    }
  });

  testWidgets('Listings display supplied details without invented offers', (tester) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: HotelsView(
      apiService: api(http.Response('{"hotels":[{"name":"Sample Hotel","address":null,"lat":48.8,"lon":2.3}]}', 200)),
    ))));
    await tester.pumpAndSettle();
    expect(find.text('Sample Hotel'), findsOneWidget);
    expect(find.text('Address unavailable'), findsOneWidget);
    expect(find.text('Prices, ratings and amenities unavailable.'), findsOneWidget);
    expect(find.text('Listings from Geoapify'), findsOneWidget);
    expect(find.text('View Deal'), findsNothing);
    expect(find.byIcon(Icons.star_rounded), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Failed search can retry into an empty result', (tester) async {
    var calls = 0;
    final service = TravelApiService(hotelClient: MockClient((_) async {
      calls++;
      return calls == 1 ? http.Response('', 500) : http.Response('{"hotels":[]}', 200);
    }));
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: HotelsView(apiService: service))));
    await tester.pumpAndSettle();
    expect(find.text('Unable to load hotels. Please try again.'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('No hotels found for this city. Try expanding the radius or searching another city.'), findsOneWidget);
    expect(find.text('Unable to load hotels. Please try again.'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
