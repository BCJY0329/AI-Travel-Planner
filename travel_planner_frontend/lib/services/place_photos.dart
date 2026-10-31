import 'package:flutter/foundation.dart';
import '../config/discover_content.dart';
import '../models/travel_models.dart';
import 'travel_api_service.dart';

/// Pixabay banner photos, shared by every page so a place is fetched once
/// per app session (the backend caches them too). Any failure (no key,
/// offline, rate limit) just means no photo, and is retried next time.
class PlacePhotoSource {
  PlacePhotoSource(this._api);
  final TravelApiService _api;
  final _places = <String, Future<List<PlacePhoto>>>{};
  Future<List<DiscoverPhoto>>? _featured;

  /// One photo of [place]'s country, varied by place so cities in one
  /// country don't all share the same picture.
  Future<DiscoverPhoto?> forPlace(String place) async {
    final key = place.trim().toLowerCase();
    if (key.isEmpty) return null;
    final request = _places[key] ??= _api.placePhotos(place);
    try {
      final photos = await request;
      if (photos.isEmpty) return null;
      final pick = key.codeUnits.fold<int>(0, (a, b) => a + b) % photos.length;
      return asDiscoverPhoto(photos[pick]);
    } catch (_) {
      _places.remove(key);
      return null;
    }
  }

  /// Pixabay editors' choice travel photos for the Discover hero.
  Future<List<DiscoverPhoto>> featured() async {
    final request = _featured ??= _api
        .featuredPhotos()
        .then((photos) => photos.map(asDiscoverPhoto).toList());
    try {
      return await request;
    } catch (_) {
      _featured = null;
      return const [];
    }
  }

  static DiscoverPhoto asDiscoverPhoto(PlacePhoto photo) => DiscoverPhoto(
      asset: '',
      url: photo.imageUrl,
      description: photo.tags.isEmpty ? 'Travel photo' : photo.tags,
      credit: photo.photographer,
      source: 'Pixabay');
}

/// The banner photo for whichever place a view is showing: a bundled photo
/// when one shows that city, else a Pixabay country photo once it arrives.
class BannerPhoto {
  String? _place;
  DiscoverPhoto? _remote;

  /// Call from build; [onLoaded] runs (to rebuild) when a remote photo arrives.
  DiscoverPhoto? resolve(
      PlacePhotoSource? source, String place, VoidCallback onLoaded) {
    final bundled = DiscoverContent.photoForPlace(place);
    if (bundled != null || source == null) return bundled;
    if (place != _place) {
      _place = place;
      _remote = null;
      source.forPlace(place).then((photo) {
        if (_place != place || photo == null) return;
        _remote = photo;
        onLoaded();
      });
    }
    return _remote;
  }
}
