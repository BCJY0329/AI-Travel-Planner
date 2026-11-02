import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travel_planner_frontend/chat/chat_message.dart';
import 'package:travel_planner_frontend/chat/lemon_chat_controller.dart';
import 'package:travel_planner_frontend/config/app_theme.dart';
import 'package:travel_planner_frontend/models/travel_models.dart';
import 'package:travel_planner_frontend/screens/views/attractions_view.dart';
import 'package:travel_planner_frontend/screens/views/discover_view.dart';
import 'package:travel_planner_frontend/screens/views/flights_view.dart';
import 'package:travel_planner_frontend/screens/views/hotels_view.dart';
import 'package:travel_planner_frontend/screens/views/itinerary_view.dart';
import 'package:travel_planner_frontend/widgets/chat_bubble.dart';
import 'package:travel_planner_frontend/widgets/lemon_brand.dart';
import 'package:travel_planner_frontend/widgets/lemon_bubble.dart';
import 'package:travel_planner_frontend/widgets/lemon_chat_panel.dart';
import 'package:travel_planner_frontend/widgets/page_parts.dart';

import 'lemon_redesign_test.dart' show FakeLemonApi;
import 'page_redesign_test.dart' show FakeTravelApi, pumpAt;

/// The fill of the elevated button whose label is [label].
Color? buttonFill(WidgetTester tester, String label) {
  final button = tester.widget<ButtonStyleButton>(find
      .ancestor(
          of: find.text(label),
          matching: find.byWidgetPredicate((w) => w is ElevatedButton))
      .first);
  return button.style?.backgroundColor?.resolve({});
}

/// The search card's own width (SearchCard aligns it within the full row).
double searchCardWidth(WidgetTester tester) => tester
    .getSize(find
        .descendant(
            of: find.byType(SearchCard), matching: find.byType(Container))
        .first)
    .width;

void main() {
  testWidgets('Search pages are sky blue; Flights has the mock search button',
      (tester) async {
    final api = FakeTravelApi();
    // DECISIONS 046-048: sky blue pages. Flights uses the shared rounded
    // SearchButton; Hotels and Attractions keep the theme's pill button.
    for (final (view, label, rounded) in [
      (FlightsView(apiService: api), 'Find Flights', true),
      (HotelsView(apiService: api), 'Find Hotels', false),
      (AttractionsView(apiService: api), 'Discover Attractions', false),
    ]) {
      for (final width in [360.0, 800.0, 1440.0]) {
        await pumpAt(tester, width, view);
        final why = '$label at $width';
        expect(tester.takeException(), isNull, reason: why);
        expect(find.byType(PageTone), findsNothing, reason: why);
        expect(
            find.byType(SearchButton), rounded ? findsOneWidget : findsNothing,
            reason: why);
        expect(buttonFill(tester, label), rounded ? AppTheme.cta : isNull,
            reason: why);
        final style =
            DefaultTextStyle.of(tester.element(find.text(label))).style;
        // DECISIONS 056: every filled button label is Outfit 800.
        expect(style.fontFamily, AppTheme.buttonFont, reason: why);
        expect(style.fontWeight, FontWeight.w800, reason: why);
      }
    }
  });

  testWidgets(
      'Search rows: Flights button beside, others no taller than fields',
      (tester) async {
    final api = FakeTravelApi();
    // Hotels and Attractions: the row keeps the fields' own height.
    for (final (view, label) in [
      (HotelsView(apiService: api), 'Find Hotels'),
      (AttractionsView(apiService: api), 'Discover Attractions')
    ]) {
      await pumpAt(tester, 1440, view);
      final field = tester.getSize(find.byType(SearchField).first);
      final button = tester.getSize(find
          .ancestor(of: find.text(label), matching: find.byType(ElevatedButton))
          .first);
      expect(button.height, lessThanOrEqualTo(field.height), reason: label);
    }
    // Flights: the button sits beside the last field (Travelers) on the
    // same row instead of taking an empty full-width row of its own.
    for (final width in [1440.0, 800.0]) {
      await pumpAt(tester, width, FlightsView(apiService: api));
      final button = tester.getRect(find.byType(SearchButton));
      final last = tester.getRect(find.byType(SearchField).last);
      expect(button.left, greaterThan(last.right), reason: '$width');
      expect(button.center.dy, closeTo(last.center.dy, .5), reason: '$width');
    }
  });

  testWidgets('Search pages hold with large text and no motion',
      (tester) async {
    final api = FakeTravelApi();
    for (final width in [800.0, 1100.0]) {
      tester.view.physicalSize = Size(width, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final view in [
        FlightsView(apiService: api),
        HotelsView(apiService: api),
        AttractionsView(apiService: api),
      ]) {
        await tester.pumpWidget(MaterialApp(
            theme: AppTheme.lightTheme,
            home: MediaQuery(
                data: MediaQueryData(
                    size: Size(width, 1400),
                    textScaler: const TextScaler.linear(1.6),
                    disableAnimations: true),
                child: Scaffold(body: view))));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull,
            reason: '${view.runtimeType} at $width');
      }
    }
  });

  testWidgets('Results banner grows with large text (KI-28)', (tester) async {
    Future<Size> banner(double scale) async {
      await tester.pumpWidget(MaterialApp(
          theme: AppTheme.lightTheme,
          home: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(scale)),
              child: const Scaffold(
                  body: SingleChildScrollView(
                      child: ResultsBanner(
                          photo: null,
                          title: 'Things to do in Kyoto',
                          subtitle: '12 places within 5 km'))))));
      await tester.pump();
      expect(tester.takeException(), isNull, reason: 'scale $scale');
      return tester.getSize(find.byType(ResultsBanner));
    }

    expect((await banner(1)).height, 150);
    expect((await banner(2)).height, greaterThan(150));
  });

  testWidgets('Hotel and attraction icon tiles are lemon (DECISIONS 051)',
      (tester) async {
    Color? tileColour(Widget w) => w is Container &&
            w.decoration is BoxDecoration &&
            w.constraints?.maxWidth == 46 &&
            w.constraints?.maxHeight == 46
        ? (w.decoration as BoxDecoration).color
        : null;
    final api = FakeTravelApi();
    for (final (view, cards) in [
      (HotelsView(apiService: api) as Widget, null),
      (AttractionsView(apiService: api), 3),
    ]) {
      await pumpAt(tester, 1440, view);
      final tiles = tester
          .widgetList(find.byWidgetPredicate((w) => tileColour(w) != null))
          .map(tileColour)
          .toList();
      expect(tiles, isNotEmpty, reason: '${view.runtimeType}');
      if (cards != null) expect(tiles.length, cards);
      expect(tiles.toSet(), {AppTheme.lemonAccent},
          reason: '${view.runtimeType}');
    }
  });

  testWidgets('Flight carriers are sky blue, direct lemon, stops sand',
      (tester) async {
    // Three different airlines, which per-airline colours would tell apart.
    const codes = ['ZZ', 'AA', 'JL'];
    await pumpAt(tester, 1440, FlightsView(apiService: _MixedCarriers(codes)));
    final carriers = tester
        .widgetList<Container>(find.byWidgetPredicate((w) =>
            w is Container &&
            w.decoration is BoxDecoration &&
            (w.decoration as BoxDecoration).shape == BoxShape.circle &&
            w.child is Text &&
            codes.contains((w.child as Text).data)))
        .map((w) => (w.decoration as BoxDecoration).color)
        .toList();
    expect(carriers.length, greaterThanOrEqualTo(codes.length));
    expect(carriers.toSet(), {AppTheme.cta});
    Color? pill(Finder text) => (tester
            .widget<Container>(
                find.ancestor(of: text, matching: find.byType(Container)).first)
            .decoration as BoxDecoration)
        .color;
    expect(find.text('Direct'), findsWidgets);
    for (final e in find.text('Direct').evaluate()) {
      expect(pill(find.byWidget(e.widget)), AppTheme.lemonAccent);
    }
    final stops = find.textContaining('Stop');
    for (final e in stops.evaluate()) {
      expect(pill(find.byWidget(e.widget)), AppTheme.sand);
    }
  });

  testWidgets('A one-field search card stays compact on wide screens',
      (tester) async {
    final api = FakeTravelApi();
    await pumpAt(tester, 1440, AttractionsView(apiService: api));
    expect(searchCardWidth(tester), lessThanOrEqualTo(760));
    // Hotels and Flights are capped too (DECISIONS 053), with every field
    // still on one row at desktop width.
    await pumpAt(tester, 1440, HotelsView(apiService: api));
    expect(searchCardWidth(tester), lessThanOrEqualTo(940));
    expect(
        tester.getCenter(find.text('Destination city')).dy,
        moreOrLessEquals(tester.getCenter(find.text('Search radius')).dy,
            epsilon: 4));
    await pumpAt(tester, 1440, FlightsView(apiService: api));
    expect(searchCardWidth(tester), lessThanOrEqualTo(1080));
    expect(searchCardWidth(tester), greaterThan(900));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Lemon hover card wears the chat panel look', (tester) async {
    var taps = 0;
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
            body: Align(
                alignment: Alignment.bottomRight,
                child: LemonBubble(onTap: () => taps++)))));
    expect(find.text("Hi, I'm Lemon!"), findsNothing);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(find.byType(LemonBubble)));
    await tester.pumpAndSettle();
    // DECISIONS 057: Fredoka greeting, Lexend invitation, no pill.
    final title = tester.widget<Text>(find.text("Hi, I'm Lemon!"));
    expect(title.style?.color, AppTheme.sandInk);
    expect(title.style?.fontFamily, AppTheme.noteFont);
    expect(find.text(LemonBubble.invitations.first), findsOneWidget);
    final invite = tester.widget<Text>(find.descendant(
        of: find.byType(LemonBubble),
        matching: find.byWidgetPredicate(
            (w) => w is Text && w.style?.fontFamily == AppTheme.chatFont)));
    expect(invite.style?.color, AppTheme.sorbetInk);
    // The sorbet fade behind it.
    expect(
        tester
            .widgetList<Ink>(find.descendant(
                of: find.byType(LemonBubble), matching: find.byType(Ink)))
            .any((ink) => (ink.decoration as BoxDecoration?)?.gradient != null),
        isTrue);
    expect(find.textContaining('plan together'), findsNothing);
    // Lemon's full avatar, uncropped as before 051 (DECISIONS 053).
    final avatar = tester.widget<Image>(find.descendant(
        of: find.byType(LemonBubble), matching: find.byType(Image)));
    expect(avatar.fit, BoxFit.contain);
    expect((avatar.width, avatar.height), (88, 116));
    expect((avatar.image as AssetImage).assetName,
        'assets/images/lemon_avatar.png');
    await tester.tap(find.byType(LemonBubble));
    expect(taps, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Chat bubbles: Lemon plain white, traveller sky to lilac',
      (tester) async {
    BoxDecoration bubbleOf(String text) => tester
        .widgetList<Container>(find.ancestor(
            of: find.text(text), matching: find.byType(Container)))
        .map((c) => c.decoration)
        .whereType<BoxDecoration>()
        .firstWhere((d) => d.boxShadow != null);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Column(children: [
      for (final message in [
        ChatMessage.text(ChatSender.bot, 'Sunny days ahead ☀️🍋'),
        ChatMessage.text(ChatSender.user, 'Kyoto'),
      ])
        ChatBubbleWidget(
            message: message, onQuickReply: (_) {}, onPickDate: (_) {}),
    ]))));
    // DECISIONS 055: emoji sit on plain white with a warm hairline edge and
    // no yellow outline or stripe.
    final lemon = bubbleOf('Sunny days ahead ☀️🍋');
    expect(lemon.color, AppTheme.surface);
    expect(lemon.gradient, isNull);
    final edge = lemon.border as Border;
    expect(edge.top.color, AppTheme.lemonBubbleEdge);
    expect(edge.left.color, AppTheme.lemonBubbleEdge);
    final text = tester.widget<Text>(find.text('Sunny days ahead ☀️🍋'));
    expect(text.style!.color, AppTheme.chatText);
    expect(bubbleOf('Kyoto').gradient, AppTheme.travellerBubble);
    expect(AppTheme.travellerBubble.colors, [AppTheme.cta, AppTheme.lilac]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Discover hero words and buttons use Outfit', (tester) async {
    await pumpAt(
        tester, 1440, DiscoverView(onOpenLemon: () {}, onSelectTab: (_) {}));
    for (final text in [
      'YOUR AI TRAVEL COMPANION',
      "Tell Lemon where you'd like to go and she'll shape the days around what you love.",
      'Plan a trip with Lemon',
      'Explore places',
      'Pick your somewhere',
    ]) {
      final style = DefaultTextStyle.of(tester.element(find.text(text).first))
          .style
          .merge(tester.widget<Text>(find.text(text).first).style);
      expect(style.fontFamily, AppTheme.tripBodyFont, reason: text);
    }
    // The title keeps its Unbounded heading face.
    expect(
        tester.widget<Text>(find.text('A little curiosity.')).style!.fontFamily,
        AppTheme.tripHeadingFont);
  });

  test('Tip labels are shuffled per day without repeats in a day', () {
    List<String> day(int d) => [for (var n = 1; n <= 4; n++) tipLabelFor(d, n)];
    for (var d = 1; d <= 30; d++) {
      expect(day(d).toSet().length, 4, reason: 'day $d');
      if (d > 1) expect(day(d), isNot(day(d - 1)), reason: 'day $d');
    }
    // Not every day starts the same way, and the order is stable.
    expect({for (var d = 1; d <= 7; d++) tipLabelFor(d, 1)}.length,
        greaterThan(1));
    expect(day(3), day(3));
    // A fifth stop wraps round to the day's first label.
    expect(tipLabelFor(2, 5), tipLabelFor(2, 1));
  });

  testWidgets('Plan with Lemon is warm sand on every page that offers it',
      (tester) async {
    var opened = 0;
    final api = FakeTravelApi();
    await pumpAt(
        tester, 1440, HotelsView(apiService: api, onOpenLemon: () => opened++));
    await tester.ensureVisible(find.text('Plan with Lemon'));
    expect(buttonFill(tester, 'Plan with Lemon'), AppTheme.planButton);
    await tester.tap(find.text('Plan with Lemon'));
    expect(opened, 1);

    await pumpAt(tester, 1440,
        AttractionsView(apiService: api, onOpenLemon: () => opened++));
    await tester.ensureVisible(find.text('Plan with Lemon'));
    expect(buttonFill(tester, 'Plan with Lemon'), AppTheme.planButton);

    // Without a callback the band stays hidden.
    await pumpAt(tester, 1440, HotelsView(apiService: api));
    expect(find.text('Plan with Lemon'), findsNothing);
  });

  for (final width in [360.0, 800.0, 1440.0]) {
    testWidgets('Pre-plan itinerary is the sand page at $width',
        (tester) async {
      var opened = 0;
      await pumpAt(tester, width,
          ItineraryView(itinerary: null, onOpenLemon: () => opened++));
      expect(find.text('Your next adventure starts here'), findsOneWidget);
      expect(find.text('What Lemon will ask'), findsOneWidget);
      expect(find.text('Budget'), findsOneWidget);
      expect(buttonFill(tester, 'Plan with Lemon'), AppTheme.planButton);
      await tester.tap(find.text('Plan with Lemon'));
      expect(opened, 1);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('New layouts hold at 360 px with large text and no motion',
      (tester) async {
    tester.view.physicalSize = const Size(360, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    Widget wrap(Widget child) => MaterialApp(
        theme: AppTheme.lightTheme,
        home: MediaQuery(
            data: const MediaQueryData(
                size: Size(360, 1400),
                textScaler: TextScaler.linear(1.6),
                disableAnimations: true),
            child: Scaffold(body: child)));
    await tester
        .pumpWidget(wrap(ItineraryView(itinerary: null, onOpenLemon: () {})));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    final c = LemonChatController(api: FakeLemonApi())
      ..nextField = 'budget_level';
    addTearDown(c.dispose);
    await tester.pumpWidget(wrap(SizedBox(
        width: 320, child: LemonChatPanel(controller: c, onClose: () {}))));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('Chat header shows the lemon badge and step states',
      (tester) async {
    final c = LemonChatController(api: FakeLemonApi())
      ..nextField = 'budget_level';
    addTearDown(c.dispose);
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SizedBox(
                width: 420,
                child: LemonChatPanel(controller: c, onClose: () {})))));
    expect(find.byType(LemonMark), findsOneWidget);
    expect(find.text('Your personal travel companion'), findsOneWidget);
    expect(find.bySemanticsLabel('Who: done'), findsOneWidget);
    expect(find.bySemanticsLabel('Budget: current step'), findsOneWidget);
    expect(find.bySemanticsLabel('Loves: to do'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('Chat messages and typing boxes use Lexend (DECISIONS 057)',
      (tester) async {
    Future<LemonChatController> pump(String field) async {
      final c = LemonChatController(api: FakeLemonApi())
        ..nextField = field
        ..messages.addAll([
          ChatMessage.text(ChatSender.bot, 'Where shall we go?'),
          ChatMessage.text(ChatSender.user, 'Kyoto'),
        ]);
      addTearDown(c.dispose);
      await tester.pumpWidget(MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
              body: SizedBox(
                  width: 420,
                  child: LemonChatPanel(controller: c, onClose: () {})))));
      await tester.pump();
      return c;
    }

    String? typedFont() => tester
        .widget<EditableText>(find.byType(EditableText).last)
        .style
        .fontFamily;

    expect(AppTheme.chatFont, 'Lexend');
    // The destination box, at the start of a chat.
    await pump('destination');
    expect(typedFont(), AppTheme.chatFont);
    expect(
        tester
            .widget<EditableText>(find.byType(EditableText).last)
            .style
            .fontWeight,
        FontWeight.w600);
    // Both voices' bubbles.
    for (final text in ['Where shall we go?', 'Kyoto']) {
      final bubble = find.descendant(
          of: find.byType(ChatBubbleWidget), matching: find.text(text));
      expect(tester.widget<Text>(bubble).style?.fontFamily, AppTheme.chatFont,
          reason: text);
    }

    // The travellers and other-interests boxes.
    await pump('travelers');
    expect(typedFont(), AppTheme.chatFont);
    await pump('interests');
    expect(typedFont(), AppTheme.chatFont);
    expect(tester.takeException(), isNull);
  });
}

/// The fake flights, each with a different airline code.
class _MixedCarriers extends FakeTravelApi {
  final List<String> codes;
  _MixedCarriers(this.codes);
  @override
  Future<List<FlightOffer>> searchFlights(
      {required String origin,
      required String destination,
      required String departureDate,
      int adults = 1}) async {
    final offers = await super.searchFlights(
        origin: origin,
        destination: destination,
        departureDate: departureDate,
        adults: adults);
    return [
      for (var i = 0; i < offers.length; i++)
        FlightOffer(
            price: offers[i].price,
            currency: offers[i].currency,
            duration: offers[i].duration,
            stops: offers[i].stops,
            departure: offers[i].departure,
            departureTime: offers[i].departureTime,
            arrival: offers[i].arrival,
            arrivalTime: offers[i].arrivalTime,
            carrier: codes[i % codes.length]),
    ];
  }
}
