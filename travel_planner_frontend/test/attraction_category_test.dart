import 'package:flutter_test/flutter_test.dart';
import 'package:travel_planner_frontend/models/travel_models.dart';

/// Attractions are sorted into chips from Geoapify's whole category list
/// (DECISIONS 052, 053). Offline: hand-written payloads.
void main() {
  AttractionItem parse(Map<String, dynamic> json) =>
      AttractionItem.fromJson({'name': 'Place', 'lat': 1, 'lon': 2, ...json});

  test('A museum is Culture & Heritage, whatever comes first in the list', () {
    final item = parse({
      'category': 'building',
      'categories': ['building', 'entertainment', 'entertainment.museum'],
    });
    expect(item.category, 'Culture & Heritage');
    expect(
        item.categories, ['building', 'entertainment', 'entertainment.museum']);
  });

  test('A castle with a heritage tag is Culture & Heritage, not a sight', () {
    final item = parse({
      'categories': [
        'building',
        'heritage',
        'heritage.unesco',
        'tourism',
        'tourism.sights',
        'tourism.sights.castle'
      ],
    });
    expect(item.category, 'Culture & Heritage');
    expect(AttractionItem.classify(['entertainment.culture.theatre']),
        'Culture & Heritage');
  });

  test('Zoos, theme parks and cinemas are Entertainment', () {
    for (final kind in ['zoo', 'theme_park', 'cinema']) {
      expect(AttractionItem.classify(['entertainment', 'entertainment.$kind']),
          'Entertainment');
    }
  });

  test('Monuments, towers and ruins are Landmark & Sights', () {
    final item = parse({
      'categories': ['tourism', 'tourism.sights', 'tourism.sights.tower'],
    });
    expect(item.category, 'Landmark & Sights');
    expect(AttractionItem.classify(['tourism.sights.memorial']),
        'Landmark & Sights');
  });

  test('Artworks, viewpoints and unmatched places are Sightseeing', () {
    expect(
        AttractionItem.classify([
          'tourism',
          'tourism.attraction',
          'tourism.attraction.artwork',
        ]),
        'Sightseeing');
    expect(
        parse({
          'categories': ['building', 'tourism']
        }).category,
        'Sightseeing');
    expect(parse({'categories': <String>[]}).category, 'Sightseeing');
  });

  test('A legacy payload with only `category` still classifies', () {
    final item = parse({'category': 'entertainment.zoo'});
    expect(item.category, 'Entertainment');
    expect(item.categories, ['entertainment.zoo']);
    // And with nothing at all.
    final bare = parse({});
    expect(bare.category, 'Sightseeing');
    expect(bare.categories, isEmpty);
  });

  test('Non-string entries are dropped', () {
    final item = parse({
      'categories': ['tourism.sights', 7, null, 'heritage'],
    });
    expect(item.categories, ['tourism.sights', 'heritage']);
    expect(item.category, 'Culture & Heritage');
  });

  test('Entertainment and heritage match by prefix, not anywhere', () {
    // "building.entertainment" does not start with "entertainment".
    expect(AttractionItem.classify(['leisure.park']), 'Sightseeing');
    expect(AttractionItem.classify(['building.entertainment']), 'Sightseeing');
  });
}
