import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:travel_planner_frontend/models/itinerary_models.dart';
import 'package:travel_planner_frontend/models/travel_models.dart';
import 'package:travel_planner_frontend/screens/views/discover_view.dart';
import 'package:travel_planner_frontend/screens/views/flights_view.dart';
import 'package:travel_planner_frontend/screens/views/hotels_view.dart';
import 'package:travel_planner_frontend/screens/views/itinerary_view.dart';
import 'package:travel_planner_frontend/services/place_photos.dart';
import 'package:travel_planner_frontend/services/travel_api_service.dart';

/// Records photo lookups; never touches the network.
class FakePhotoApi extends TravelApiService {
  FakePhotoApi({this.fail = false});
  final bool fail;
  final asked = <String>[];
  int featuredCalls = 0;

  PlacePhoto photo(String by) => PlacePhoto(
      imageUrl: 'http://127.0.0.1:8000/photos/image/1',
      pageUrl: 'https://pixabay.com/photos/1/',
      photographer: by,
      photographerUrl: 'https://pixabay.com/users/$by-1/');

  @override
  Future<List<PlacePhoto>> placePhotos(String place) async {
    asked.add(place);
    if (fail) throw Exception('rate limited');
    return [photo('snapper')];
  }

  @override
  Future<List<PlacePhoto>> featuredPhotos() async {
    featuredCalls++;
    if (fail) throw Exception('rate limited');
    return [photo('wanderer')];
  }

  @override
  Future<List<HotelItem>> searchHotels(
          {required String city, int radiusKm = 5}) async =>
      [HotelItem(name: 'Lakeside Inn', address: 'Lake road')];

  @override
  Future<List<FlightOffer>> searchFlights(
          {required String origin,
          required String destination,
          required String departureDate,
          int adults = 1}) async =>
      [
        FlightOffer(
            price: '300.00',
            currency: 'USD',
            duration: 'PT2H',
            stops: 0,
            departure: origin,
            departureTime: '2026-11-20T09:00:00',
            arrival: destination,
            arrivalTime: '2026-11-20T11:00:00',
            carrier: 'ZZ',
            arrivalCity: 'Hakone'),
      ];
}

ItineraryResponse trip(String destination) => ItineraryResponse.fromJson({
      'destination': destination,
      'provider_used': 'groq',
      'days': [
        {
          'day': 1,
          'date': '2026-11-20',
          'activities': [
            {'time': '09:00', 'activity': 'Old town walk'}
          ]
        }
      ],
    });

Future<void> show(WidgetTester tester, Widget view) async {
  tester.view.physicalSize = const Size(1440, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
      home: MediaQuery(
          data: const MediaQueryData(
              size: Size(1440, 1000), disableAnimations: true),
          child: Scaffold(body: view))));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  testWidgets('Itinerary without a bundled photo gets a credited country photo',
      (tester) async {
    final api = FakePhotoApi();
    await show(
        tester,
        ItineraryView(
            itinerary: trip('Hakone'),
            onOpenLemon: () {},
            photos: PlacePhotoSource(api)));
    expect(api.asked, ['Hakone']);
    expect(find.text('Photos (Pixabay): snapper'), findsOneWidget);
  });

  testWidgets('Bundled city photos win and a failed lookup stays plain',
      (tester) async {
    final api = FakePhotoApi();
    await show(
        tester,
        ItineraryView(
            itinerary: trip('Paris'),
            onOpenLemon: () {},
            photos: PlacePhotoSource(api)));
    expect(api.asked, isEmpty);

    await show(
        tester,
        ItineraryView(
            itinerary: trip('Hakone'),
            onOpenLemon: () {},
            photos: PlacePhotoSource(FakePhotoApi(fail: true))));
    expect(find.textContaining('Pixabay'), findsNothing);
    expect(find.text('Hakone itinerary'), findsOneWidget);
  });

  testWidgets('Hotel results for an unbundled city credit a country photo',
      (tester) async {
    final api = FakePhotoApi();
    await show(
        tester, HotelsView(apiService: api, photos: PlacePhotoSource(api)));
    await tester.enterText(find.byType(TextField).first, 'Hakone');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(api.asked, contains('Hakone'));
    expect(find.textContaining('Photos (Pixabay): snapper'), findsOneWidget);
  });

  testWidgets('Flight results use the arrival city for the banner photo',
      (tester) async {
    final api = FakePhotoApi();
    await show(
        tester,
        FlightsView(
            apiService: api,
            photos: PlacePhotoSource(api),
            now: () => DateTime(2026, 11, 1)));
    // The default search is KUL to NRT, whose Tokyo photo is bundled.
    expect(api.asked, isEmpty);
    await tester.enterText(find.byType(TextField).at(1), 'OKJ');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(api.asked, ['Hakone']);
    expect(find.textContaining('Photos (Pixabay): snapper'), findsOneWidget);
  });

  testWidgets('Discover hero adds featured photos and a failure keeps the default',
      (tester) async {
    final api = FakePhotoApi();
    final source = PlacePhotoSource(api);
    await show(
        tester,
        DiscoverView(
            onOpenLemon: () {}, onSelectTab: (_) {}, photos: source));
    expect(api.featuredCalls, 1);
    expect(find.text('Photo by wanderer on Pixabay'), findsNothing,
        reason: 'the bundled hero shows first');

    await show(
        tester,
        DiscoverView(
            onOpenLemon: () {},
            onSelectTab: (_) {},
            photos: PlacePhotoSource(FakePhotoApi(fail: true))));
    expect(find.textContaining('Pixabay'), findsNothing);
  });

  test('Photo source asks once per place and retries after a failure',
      () async {
    final api = FakePhotoApi();
    final source = PlacePhotoSource(api);
    await source.forPlace('Hakone');
    await source.forPlace(' hakone ');
    expect(api.asked, ['Hakone']);

    final failing = FakePhotoApi(fail: true);
    final retrying = PlacePhotoSource(failing);
    expect(await retrying.forPlace('Hakone'), isNull);
    expect(await retrying.forPlace('Hakone'), isNull);
    expect(failing.asked.length, 2);
  });

  test('placePhotos and featuredPhotos complete backend-relative image URLs',
      () async {
    final api = TravelApiService(
        client: MockClient((request) async => http.Response(
            jsonEncode({
              'photos': [
                {
                  'id': 1,
                  'image_url': '/photos/image/1',
                  'page_url': 'https://pixabay.com/photos/1/',
                  'photographer': 'snapper',
                  'photographer_url': 'https://pixabay.com/users/snapper-1/',
                  'tags': 'japan, travel'
                }
              ]
            }),
            200)));
    final place = await api.placePhotos(' Hakone ');
    final featured = await api.featuredPhotos();
    for (final photo in [place.single, featured.single]) {
      expect(photo.imageUrl, startsWith('http'));
      expect(photo.imageUrl, endsWith('/photos/image/1'));
      expect(photo.photographer, 'snapper');
    }
  });
}
