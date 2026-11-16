// Lemon.ai phase 3 (DECISIONS 073): places from photos and links, a
// checklist with one "Add selected", and "plan a trip there?" when no
// destination is known. Fake services and a fake photo picker; never a live
// backend.
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travel_planner_frontend/chat/chat_message.dart';
import 'package:travel_planner_frontend/chat/lemon_chat_controller.dart';
import 'package:travel_planner_frontend/models/chat_models.dart';
import 'package:travel_planner_frontend/models/itinerary_models.dart';
import 'package:travel_planner_frontend/models/media_models.dart';
import 'package:travel_planner_frontend/services/chat_settings.dart';
import 'package:travel_planner_frontend/services/lemon_api_service.dart';
import 'package:travel_planner_frontend/services/photo_picker.dart';
import 'package:travel_planner_frontend/widgets/lemon_chat_panel.dart';

class MediaApi extends LemonApiService {
  final List<LemonChatResult> replies = [];
  final List<List<ChatTurn>> chats = [];
  final List<(int, List<String>, String?)> mediaCalls = [];
  MediaResult media = const MediaResult(status: 'nothing_found', reply: 'Nothing here.');

  @override
  Future<LemonChatResult> sendChatTurn(
      {required List<ChatTurn> messages,
      required String provider,
      String? planSummary,
      int? planDays}) async {
    chats.add(List.of(messages));
    return replies.isEmpty ? LemonChatResult(reply: 'Tell me more!') : replies.removeAt(0);
  }

  @override
  Future<SpotsResult> getPopularSpots(String destination,
          {List<String> interests = const []}) async =>
      SpotsResult(status: 'none', destination: destination);

  @override
  Future<PlanEditResult> editPlan(
          {required TripRequest trip,
          required List<ItineraryDay> days,
          required PlanEdit edit}) async =>
      throw LemonApiException('offline');

  @override
  Future<MediaResult> findPlaces(
      {List<PickedPhoto> photos = const [],
      List<String> links = const [],
      String? destination}) async {
    mediaCalls.add((photos.length, List.of(links), destination));
    return media;
  }
}

class FakePicker extends PhotoPicker {
  final List<int> limits = [];
  int count;
  FakePicker([this.count = 1]);

  @override
  Future<PhotoPickResult> pick({required int limit}) async {
    limits.add(limit);
    return PhotoPickResult([for (var i = 0; i < count && i < limit; i++) photo(i)], 0);
  }
}

// A 1×1 transparent PNG, so Image.memory has something real to decode.
final _png = Uint8List.fromList([
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, //
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
  0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
  0x42, 0x60, 0x82
]);

PickedPhoto photo(int i) => PickedPhoto(bytes: _png, mime: 'image/png', name: 'p$i.png');

const fushimi = MediaCandidate(
    name: 'Fushimi Inari Shrine',
    city: 'Kyoto',
    country: 'Japan',
    confidence: 'high',
    evidence: 'sign reads 伏見稲荷大社',
    status: 'verified',
    placeId: 'g-fi',
    lat: 34.967,
    lon: 135.772,
    matchedName: 'Fushimi Inari-taisha',
    inDestination: true,
    distanceKm: 4.9);
const todaiji = MediaCandidate(
    name: 'Tōdai-ji',
    city: 'Nara',
    country: 'Japan',
    evidence: 'giant wooden hall',
    status: 'verified',
    placeId: 'g-td',
    lat: 34.689,
    lon: 135.84,
    inDestination: false,
    distanceKm: 36.4);
const secretCafe = MediaCandidate(
    name: 'Secret Cafe', city: 'Kyoto', evidence: 'cup with a logo', status: 'not_found');

const found = MediaResult(
    status: 'ok',
    reply: "I spotted 3 places! 📸 Tick the ones you'd like in your trip.",
    candidates: [fushimi, todaiji, secretCafe]);

String iso(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
final start = DateUtils.dateOnly(DateTime.now()).add(const Duration(days: 20));

LemonChatResult kyoto() => LemonChatResult(
    reply: 'Kyoto, lovely!',
    destination: 'Kyoto',
    destinationLabel: 'Kyoto, Japan',
    destinationStatus: 'verified',
    startDate: iso(start),
    endDate: iso(start.add(const Duration(days: 2))),
    nextField: 'confirm');

bool said(LemonChatController c, String text) =>
    c.messages.any((m) => m.text?.contains(text) == true);

LemonChatController free(MediaApi api, {ChatMode mode = ChatMode.free}) {
  final c = LemonChatController(api: api, mode: mode, settings: MemoryChatSettingsStore());
  c.startIfNeeded();
  return c;
}

MediaFinding lastFinding(LemonChatController c) =>
    c.messages.lastWhere((m) => m.type == ChatMessageType.media).finding!;

Future<void> pumpPanel(WidgetTester tester, LemonChatController c,
    {double width = 800, PhotoPicker? picker}) async {
  tester.view.physicalSize = Size(width, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(const SizedBox());
  await tester.pumpWidget(MaterialApp(
      home: Scaffold(
          body: Center(
              child: SizedBox(
                  width: width < 500 ? width : 420,
                  height: 1100,
                  child: LemonChatPanel(
                      controller: c, onClose: () {}, photoPicker: picker ?? FakePicker()))))));
  await tester.pumpAndSettle();
}

Future<void> reveal(WidgetTester tester, Finder finder) async {
  await tester.pumpAndSettle();
  // The panel sits at the bottom; earlier cards are found by scrolling up.
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(finder, -120,
        scrollable: find.byType(Scrollable).first, maxScrolls: 60);
  }
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

void main() {
  group('Links in messages', () {
    test('Readable links are found; shorteners are not', () {
      expect(
          LemonChatController.readableLinks(
              'see https://www.tiktok.com/@a/video/1, and www.timeout.com/kyoto! or https://bit.ly/x'),
          ['https://www.tiktok.com/@a/video/1', 'https://www.timeout.com/kyoto']);
      expect(LemonChatController.withoutLinks('Kyoto trip https://youtu.be/abc please'),
          'Kyoto trip please');
      expect(LemonChatController.withoutLinks('go https://bit.ly/x'), 'go https://bit.ly/x');
    });

    test('A link alone goes to the media check, not the chat', () async {
      final api = MediaApi()..media = found;
      final c = free(api);
      addTearDown(c.dispose);
      await c.handleUserInput('https://www.tiktok.com/@a/video/1');
      expect(api.chats, isEmpty);
      expect(api.mediaCalls.single.$1, 0);
      expect(api.mediaCalls.single.$2, ['https://www.tiktok.com/@a/video/1']);
      expect(api.mediaCalls.single.$3, isNull);
      expect(c.messages.last.type, ChatMessageType.media);
    });

    test('Words around a link go to the chat first, without the link', () async {
      final api = MediaApi()
        ..media = found
        ..replies.add(kyoto());
      final c = free(api);
      addTearDown(c.dispose);
      await c.handleUserInput('3 days in Kyoto, want to go here https://youtu.be/abc');
      expect(api.chats.single.last.content, '3 days in Kyoto, want to go here');
      // The destination the words named is used for the map check.
      expect(api.mediaCalls.single.$3, 'Kyoto, Japan');
      expect(api.chats.single.any((t) => t.content.contains('youtu')), isFalse);
    });

    test('Found places never reach the chat transcript', () async {
      final api = MediaApi()
        ..media = found
        ..replies.addAll([kyoto(), kyoto()]);
      final c = free(api);
      addTearDown(c.dispose);
      await c.handleUserInput('Kyoto from ${iso(start)} for 3 days');
      await c.handleUserInput('https://www.tiktok.com/@a/video/1');
      await c.handleUserInput('2 travelers');
      expect(api.chats.last.any((t) => t.content.contains('Fushimi')), isFalse);
    });

    test('Screenshot and busy replies are shown as Lemon says them', () async {
      for (final result in const [
        MediaResult(status: 'needs_screenshot', reply: "I can't open Instagram or Facebook posts."),
        MediaResult(status: 'busy', reply: "I'm a little busy looking at photos right now."),
        MediaResult(status: 'unavailable', reply: ''),
      ]) {
        final api = MediaApi()..media = result;
        final c = free(api);
        await c.handleUserInput('https://www.instagram.com/p/x/');
        expect(c.messages.last.type, ChatMessageType.text);
        expect(c.messages.last.text,
            result.reply.isEmpty ? MediaResult.unavailableReply : result.reply);
        expect(c.isBusy, isFalse);
        c.dispose();
      }
    });
  });

  group('Photos', () {
    test('Up to 3 photos wait for the message and are sent once', () async {
      final api = MediaApi()..media = found;
      final c = free(api);
      addTearDown(c.dispose);
      c.addPhotos([photo(0), photo(1), photo(2), photo(3)]);
      expect(c.pendingPhotos.length, 3);
      expect(c.photoNote, 'Up to 3 photos per message.');
      c.removePhoto(0);
      expect(c.pendingPhotos.length, 2);
      await c.handleUserInput('');
      expect(api.mediaCalls.single.$1, 2);
      expect(c.pendingPhotos, isEmpty);
      final mine = c.messages.firstWhere((m) => m.sender == ChatSender.user);
      expect(mine.photos.length, 2);
    });

    test('Map-confirmed places in the destination start ticked', () async {
      final api = MediaApi()
        ..media = found
        ..replies.add(kyoto());
      final c = free(api);
      addTearDown(c.dispose);
      await c.handleUserInput('Kyoto from ${iso(start)} for 3 days');
      c.addPhotos([photo(0)]);
      await c.handleUserInput('');
      final finding = lastFinding(c);
      expect(finding.selected, {0}); // Fushimi yes; Nara day trip no; not found no
      c.toggleCandidate(finding, 2); // not found: can't be ticked
      expect(finding.selected, {0});
      c.toggleCandidate(finding, 1);
      c.addSelected(finding);
      expect(c.mustVisit.map((m) => (m.name, m.status, m.placeId, m.matchedName)), [
        ('Fushimi Inari Shrine', 'verified', 'g-fi', 'Fushimi Inari-taisha'),
        ('Tōdai-ji', 'verified', 'g-td', null),
      ]);
      expect(said(c, 'Added Fushimi Inari Shrine and Tōdai-ji to your must-visits!'), isTrue);
      expect(said(c, 'plan Tōdai-ji as a day trip'), isTrue);
      expect(finding.state, 'added');
      c.toggleCandidate(finding, 0);
      expect(finding.selected, {0, 1}, reason: 'an added finding is closed');
    });

    test('Adding stops at 10 must-visits and skips ones already there', () async {
      final api = MediaApi()
        ..replies.add(kyoto())
        ..media = MediaResult(status: 'ok', reply: 'Found!', candidates: [
          for (var i = 0; i < 10; i++)
            MediaCandidate(name: 'Place $i', status: 'verified', inDestination: true),
          const MediaCandidate(name: 'Place 10', status: 'verified', inDestination: true),
        ]);
      final c = free(api);
      addTearDown(c.dispose);
      await c.handleUserInput('Kyoto from ${iso(start)} for 3 days');
      c.mustVisit.add(const MustVisitPlace(name: 'Place 0'));
      c.addPhotos([photo(0)]);
      await c.handleUserInput('');
      c.addSelected(lastFinding(c));
      expect(c.mustVisit.length, 10);
      expect(said(c, 'I can keep up to 10'), isTrue);
    });

    test('No destination: Lemon offers the city, and Yes plans it', () async {
      final api = MediaApi()
        ..media = const MediaResult(
            status: 'ok',
            reply: 'That looks like Fushimi Inari Shrine in Kyoto! 📸 Want to plan a trip to Kyoto?',
            candidates: [
              MediaCandidate(name: 'Fushimi Inari Shrine', city: 'Kyoto', country: 'Japan', status: 'verified'),
              MediaCandidate(name: 'Tōdai-ji', city: 'Nara', country: 'Japan', status: 'verified'),
            ],
            suggestedDestination: 'Kyoto, Japan')
        ..replies.add(kyoto());
      final c = free(api);
      addTearDown(c.dispose);
      c.addPhotos([photo(0)]);
      await c.handleUserInput('');
      final finding = lastFinding(c);
      expect(finding.suggestedCity, 'Kyoto');
      expect(finding.selected, {0}, reason: 'only the suggested city starts ticked');
      c.addSelected(finding);
      expect(c.mustVisit, isEmpty, reason: 'no destination yet');
      await c.acceptSuggestedDestination(finding);
      expect(api.chats.single.last.content, 'Kyoto, Japan');
      expect(c.destination, 'Kyoto');
      c.addSelected(finding);
      expect(c.mustVisit.map((m) => m.name), ['Fushimi Inari Shrine']);
    });

    test('No thanks closes the offer', () async {
      final api = MediaApi()
        ..media = const MediaResult(
            status: 'ok',
            reply: 'Want to plan a trip to Kyoto?',
            candidates: [MediaCandidate(name: 'Fushimi Inari Shrine', city: 'Kyoto', status: 'verified')],
            suggestedDestination: 'Kyoto, Japan');
      final c = free(api);
      addTearDown(c.dispose);
      c.addPhotos([photo(0)]);
      await c.handleUserInput('');
      final finding = lastFinding(c);
      c.declineSuggestedDestination(finding);
      expect(finding.state, 'dismissed');
      expect(api.chats, isEmpty);
      expect(said(c, 'No problem!'), isTrue);
    });
  });

  group('Panel', () {
    testWidgets('Photo button, tray and checklist work at every width', (tester) async {
      for (final width in [360.0, 800.0, 1440.0]) {
        final api = MediaApi()
          ..media = found
          ..replies.add(kyoto());
        final c = free(api);
        await c.handleUserInput('Kyoto from ${iso(start)} for 3 days');
        final picker = FakePicker(2);
        await pumpPanel(tester, c, width: width, picker: picker);

        await tester.tap(find.byTooltip('Add photos (up to 3)'));
        await tester.pumpAndSettle();
        expect(picker.limits, [3]);
        expect(c.pendingPhotos.length, 2);
        expect(find.text("Photos are only used to find places and aren't kept."), findsOneWidget);
        await tester.tap(find.byTooltip('Remove photo 2'));
        await tester.pumpAndSettle();
        expect(c.pendingPhotos.length, 1);

        await tester.tap(find.byTooltip('Send message'));
        await tester.pumpAndSettle();
        expect(api.mediaCalls.single.$1, 1);

        await reveal(tester, find.text('Fushimi Inari Shrine'));
        expect(find.text('On the map as Fushimi Inari-taisha'), findsOneWidget);
        expect(find.text('Seen: sign reads 伏見稲荷大社'), findsOneWidget);
        expect(find.text('In Nara · 36 km away, day trip'), findsOneWidget);
        expect(find.text("Couldn't find this on the map"), findsOneWidget);
        expect(find.text('High'), findsOneWidget);
        expect(find.text('Maybe'), findsNWidgets(2));

        await reveal(tester, find.text('Tōdai-ji'));
        await tester.tap(find.text('Tōdai-ji'));
        await tester.pumpAndSettle();
        await reveal(tester, find.text('Add selected (2)'));
        await tester.tap(find.text('Add selected (2)'));
        await tester.pumpAndSettle();
        expect(c.mustVisit.map((m) => m.name), ['Fushimi Inari Shrine', 'Tōdai-ji']);
        await reveal(tester, find.text('Added to your trip brief'));
        final sentPhoto =
            find.byWidgetPredicate((w) => w is Image && w.semanticLabel == 'Your photo');
        await reveal(tester, sentPhoto);
        expect(sentPhoto, findsWidgets);
        expect(tester.takeException(), isNull, reason: 'width $width');
        c.dispose();
      }
    });

    testWidgets('Yes, plan Kyoto and No thanks show at every width', (tester) async {
      for (final width in [360.0, 800.0, 1440.0]) {
        final api = MediaApi()
          ..media = const MediaResult(
              status: 'ok',
              reply: 'That looks like Fushimi Inari Shrine in Kyoto! 📸 Want to plan a trip to Kyoto?',
              candidates: [
                MediaCandidate(name: 'Fushimi Inari Shrine', city: 'Kyoto', country: 'Japan', status: 'verified')
              ],
              suggestedDestination: 'Kyoto, Japan')
          ..replies.add(kyoto());
        final c = free(api);
        c.addPhotos([photo(0)]);
        await c.handleUserInput('');
        await pumpPanel(tester, c, width: width);
        await reveal(tester, find.text('No thanks'));
        expect(find.text('Yes, plan Kyoto'), findsOneWidget);
        await tester.tap(find.text('Yes, plan Kyoto'));
        await tester.pumpAndSettle();
        expect(c.destination, 'Kyoto');
        await reveal(tester, find.text('Add selected (1)'));
        expect(tester.takeException(), isNull, reason: 'width $width');
        c.dispose();
      }
    });

    testWidgets('A photo alone can be sent with an empty box', (tester) async {
      final api = MediaApi();
      final c = free(api);
      await pumpPanel(tester, c, picker: FakePicker(1));
      await tester.tap(find.byTooltip('Add photos (up to 3)'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Send message'));
      await tester.pumpAndSettle();
      expect(api.mediaCalls.length, 1);
      expect(find.text('Nothing here.'), findsOneWidget);
      c.dispose();
    });
  });

  test('MediaResult JSON matches the backend', () {
    final r = MediaResult.fromJson({
      'status': 'ok',
      'reply': 'Found!',
      'suggested_destination': 'Kyoto, Japan',
      'candidates': [
        {
          'name': 'Fushimi Inari Shrine',
          'city': 'Kyoto',
          'country': 'Japan',
          'confidence': 'high',
          'evidence': 'torii',
          'source': 'link',
          'status': 'verified',
          'place_id': 'g',
          'lat': 34.9,
          'lon': 135.7,
          'matched_name': 'Fushimi Inari-taisha',
          'in_destination': false,
          'distance_km': 36.4
        },
        {'name': '  '},
      ]
    });
    expect(r.candidates.length, 1);
    final c = r.candidates.single;
    expect((c.source, c.isDayTrip, c.distanceKm, c.matchedName), ('link', true, 36.4, 'Fushimi Inari-taisha'));
    expect(MediaCandidate.fromJson(c.toJson()).toJson(), c.toJson());
    expect(PickedPhoto.mimeFor(null, 'a.JPG'), 'image/jpeg');
    expect(PickedPhoto.mimeFor('image/heic', 'a.heic'), isNull);
  });
}
