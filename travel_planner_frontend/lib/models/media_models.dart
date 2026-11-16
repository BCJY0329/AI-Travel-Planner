import 'dart:typed_data';

/// A photo picked for Lemon to look at (DECISIONS 073). Kept in memory only,
/// never saved, and dropped once the message is sent.
class PickedPhoto {
  final Uint8List bytes;

  /// 'image/jpeg', 'image/png' or 'image/webp' (what POST /lemon/media takes).
  final String mime;
  final String name;
  const PickedPhoto({required this.bytes, required this.mime, this.name = ''});

  static const allowedMimes = {'image/jpeg', 'image/png', 'image/webp'};

  /// travel_backend/models/media.py MAX_IMAGE_BYTES.
  static const maxBytes = 4 * 1024 * 1024;

  /// The type from a picker's mime, else from the file name.
  static String? mimeFor(String? mime, String name) {
    final given = (mime ?? '').toLowerCase();
    if (allowedMimes.contains(given)) return given;
    final lower = name.toLowerCase();
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    return null;
  }
}

/// One place Lemon found in a photo or link (travel_backend/models/media.py
/// MediaCandidate).
class MediaCandidate {
  final String name;
  final String? city;
  final String? country;

  /// 'high' or 'maybe'.
  final String confidence;
  final String evidence;

  /// 'photo' or 'link'.
  final String source;

  /// 'verified' (on the map), 'not_found' or 'unchecked' (the check failed).
  final String status;
  final String? placeId;
  final double? lat;
  final double? lon;
  final String? matchedName;

  /// Null when there was no destination to compare with.
  final bool? inDestination;
  final double? distanceKm;

  const MediaCandidate(
      {required this.name,
      this.city,
      this.country,
      this.confidence = 'maybe',
      this.evidence = '',
      this.source = 'photo',
      this.status = 'unchecked',
      this.placeId,
      this.lat,
      this.lon,
      this.matchedName,
      this.inDestination,
      this.distanceKm});

  factory MediaCandidate.fromJson(Map<String, dynamic> json) => MediaCandidate(
        name: (json['name'] as String? ?? '').trim(),
        city: (json['city'] as String?)?.trim(),
        country: (json['country'] as String?)?.trim(),
        confidence: json['confidence'] == 'high' ? 'high' : 'maybe',
        evidence: (json['evidence'] as String? ?? '').trim(),
        source: json['source'] == 'link' ? 'link' : 'photo',
        status: json['status'] as String? ?? 'unchecked',
        placeId: json['place_id'] as String?,
        lat: (json['lat'] as num?)?.toDouble(),
        lon: (json['lon'] as num?)?.toDouble(),
        matchedName: (json['matched_name'] as String?)?.trim(),
        inDestination: json['in_destination'] as bool?,
        distanceKm: (json['distance_km'] as num?)?.toDouble(),
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'city': city,
        'country': country,
        'confidence': confidence,
        'evidence': evidence,
        'source': source,
        'status': status,
        'place_id': placeId,
        'lat': lat,
        'lon': lon,
        'matched_name': matchedName,
        'in_destination': inDestination,
        'distance_km': distanceKm,
      };

  bool get canAdd => status != 'not_found';

  /// Further than a day trip from the destination's centre.
  bool get isDayTrip => status == 'verified' && inDestination == false;
}

/// POST /lemon/media. status: 'ok', 'nothing_found', 'needs_screenshot',
/// 'busy' or 'unavailable'.
class MediaResult {
  final String status;
  final String reply;
  final List<MediaCandidate> candidates;
  final String? suggestedDestination;
  const MediaResult(
      {required this.status,
      required this.reply,
      this.candidates = const [],
      this.suggestedDestination});

  static const unavailableReply =
      "I couldn't look at that right now. 🔍 Please try again, or tell me the place in words.";

  factory MediaResult.fromJson(Map<String, dynamic> json) => MediaResult(
        status: json['status'] as String? ?? 'unavailable',
        reply: (json['reply'] as String? ?? '').trim(),
        candidates: [
          for (final c in json['candidates'] as List? ?? const [])
            if (c is Map<String, dynamic>) MediaCandidate.fromJson(c)
        ].where((c) => c.name.isNotEmpty).toList(),
        suggestedDestination:
            (json['suggested_destination'] as String?)?.trim(),
      );
}
