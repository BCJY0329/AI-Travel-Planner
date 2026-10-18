import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travel_planner_frontend/config/app_theme.dart';
import 'package:travel_planner_frontend/config/discover_content.dart';
import 'package:travel_planner_frontend/models/itinerary_models.dart';
import 'package:travel_planner_frontend/models/travel_models.dart';
import 'package:travel_planner_frontend/screens/views/attractions_view.dart';
import 'package:travel_planner_frontend/screens/views/flights_view.dart';
import 'package:travel_planner_frontend/screens/views/hotels_view.dart';
import 'package:travel_planner_frontend/screens/views/itinerary_view.dart';
import 'package:travel_planner_frontend/widgets/page_parts.dart';
import 'package:travel_planner_frontend/services/travel_api_service.dart';

class FakeTravelApi extends TravelApiService {
  @override
  Future<List<FlightOffer>> searchFlights(
          {required String origin,
          required String destination,
          required String departureDate,
          int adults = 1}) async =>
      [
        for (final price in ['918.60', '842.10', '1034.00'])
          FlightOffer(
              price: price,
              currency: 'USD',
              duration: 'PT6H10M',
              stops: price == '1034.00' ? 1 : 0,
              departure: 'KUL',
              departureTime: '2026-11-20T09:15:00',
              arrival: 'NRT',
              arrivalTime: '2026-11-20T16:25:00',
              carrier: 'ZZ'),
      ];

  @override
  Future<List<HotelItem>> searchHotels(
          {required String city, int radiusKm = 5}) async =>
      [
        HotelItem(
            name: 'Zazie Hôtel',
            address: '3 Rue Chaligny, 75012 Paris, France',
            lat: 48.8,
            lon: 2.3),
        HotelItem(name: 'Acacia', address: 'Avenue Parmentier'),
      ];

  @override
  Future<List<AttractionItem>> getAttractions(
          {required String city, int radiusKm = 5}) async =>
      [
        AttractionItem(name: 'Musée Carnavalet', category: 'Culture & Heritage'),
        AttractionItem(name: 'Jardin anglais', category: 'Sightseeing'),
        AttractionItem(name: 'Tour Saint-Jacques', category: 'Sightseeing'),
      ];
}

Future<void> pumpAt(WidgetTester tester, double width, Widget page) async {
  tester.view.physicalSize = Size(width, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme, home: Scaffold(body: page)));
  await tester.pumpAndSettle();
}

void main() {
  for (final width in [360.0, 800.0, 1440.0]) {
    testWidgets('Flights page shows banner, tip and offers at $width',
        (tester) async {
      var opened = 0;
      await pumpAt(
          tester,
          width,
          FlightsView(
              apiService: FakeTravelApi(),
              now: () => DateTime(2026, 11, 6),
              onOpenLemon: () => opened++));
      expect(find.text('Find your flight'), findsOneWidget);
      expect(find.text("Lemon's tip"), findsOneWidget);
      expect(find.text('KUL → NRT'), findsOneWidget);
      expect(find.text('Lowest price'), findsOneWidget);
      expect(find.text('Offers from Duffel (test mode)'), findsOneWidget);
      await tester.ensureVisible(find.text('Plan with Lemon'));
      await tester.tap(find.text('Plan with Lemon'));
      expect(opened, 1);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Hotels and attractions fit width $width', (tester) async {
      await pumpAt(tester, width, HotelsView(apiService: FakeTravelApi()));
      expect(find.text('2 stays in Paris'), findsOneWidget);
      expect(find.text('Address unavailable'), findsNothing);
      expect(tester.takeException(), isNull);

      await pumpAt(tester, width, AttractionsView(apiService: FakeTravelApi()));
      expect(find.text('3 attractions in Paris'), findsOneWidget);
      await tester.ensureVisible(find.byType(ChoiceChip).at(3));
      await tester.tap(find.byType(ChoiceChip).at(3));
      await tester.pumpAndSettle();
      expect(find.text('1 attraction in Paris'), findsOneWidget);
      expect(find.text('Jardin anglais'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Each itinerary day has its own colour and tips read clearly',
      (tester) async {
    final trip = ItineraryResponse(
        destination: 'Tokyo',
        providerUsed: 'groq',
        summary: 'Three easy days.',
        days: [
          for (var d = 1; d <= 4; d++)
            ItineraryDay(day: d, date: '2026-11-1$d', activities: [
              ItineraryActivity(
                  time: '09:00',
                  activity: 'Stop on day $d',
                  notes: 'Tip for day $d'),
            ])
        ]);
    await pumpAt(
        tester, 1440, ItineraryView(itinerary: trip, onOpenLemon: () {}));
    expect(find.text('Tokyo itinerary'), findsOneWidget);
    expect(find.text('Planned by Lemon'), findsOneWidget);
    Color header(int day) => (tester
            .widget<Container>(find
                .ancestor(
                    of: find.text('Day $day').last,
                    matching: find.byType(Container))
                .first)
            .color)!;
    expect({for (var d = 1; d <= 4; d++) header(d)}.length, 4);
    final label = tester.widget<Text>(find.text('A little tip from Lemon').first);
    expect(label.style!.fontSize, greaterThanOrEqualTo(15));
    await tester.tap(find.text('A little tip from Lemon').first);
    await tester.pumpAndSettle();
    expect(find.text('Tip for day 1'), findsOneWidget);
    expect(find.text('Hide Lemon’s tip'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Lemon takes the colour of what she sits on', (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: LemonCircle(size: 64, background: AppTheme.sky)));
    final circle = tester.widget<Container>(find.byType(Container).first);
    expect((circle.decoration! as BoxDecoration).color, AppTheme.sky);
  });

  test('Only matching places get a photo', () {
    expect(DiscoverContent.photoForPlace('Paris & Versailles'),
        isNot(isNull));
    expect(DiscoverContent.photoForPlace('Kyoto, Japan'), DiscoverContent.sights);
    expect(DiscoverContent.photoForPlace('London'), isNull);
    expect(DiscoverContent.photoForPlace(''), isNull);
  });
}
