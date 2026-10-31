class FlightOffer {
  final String price;
  final String currency;
  final String duration;
  final int stops;
  final String departure;
  final String departureTime;
  final String arrival;
  final String arrivalTime;
  final String carrier;

  /// The arrival airport's city (e.g. Tokyo for NRT), if Duffel gave one.
  final String? arrivalCity;

  FlightOffer({
    required this.price,
    required this.currency,
    required this.duration,
    required this.stops,
    required this.departure,
    required this.departureTime,
    required this.arrival,
    required this.arrivalTime,
    required this.carrier,
    this.arrivalCity,
  });

  factory FlightOffer.fromJson(Map<String, dynamic> json) {
    return FlightOffer(
      price: json['price']?.toString() ?? '0.00',
      currency: json['currency']?.toString() ?? 'USD',
      duration: json['duration']?.toString() ?? '',
      stops: (json['stops'] as num?)?.toInt() ?? 0,
      departure: json['departure']?.toString() ?? 'DEP',
      departureTime: json['departure_time']?.toString() ?? '',
      arrival: json['arrival']?.toString() ?? 'ARR',
      arrivalTime: json['arrival_time']?.toString() ?? '',
      carrier: json['carrier']?.toString() ?? 'AIR',
      arrivalCity: json['arrival_city']?.toString(),
    );
  }

  String get readableDuration {
    // converts PT7H47M -> 7h 47m
    var clean = duration.replaceAll('PT', '');
    clean = clean.replaceAll('H', 'h ');
    clean = clean.replaceAll('M', 'm');
    return clean.isEmpty ? 'Direct' : clean.trim();
  }

  String get stopsText {
    if (stops == 0) return 'Direct / Non-stop';
    if (stops == 1) return '1 Stop';
    return '$stops Stops';
  }

  String formatTime(String iso) {
    if (iso.isEmpty) return '--:--';
    try {
      final dt = DateTime.parse(iso);
      final hour = dt.hour.toString().padLeft(2, '0');
      final minute = dt.minute.toString().padLeft(2, '0');
      return '$hour:$minute';
    } catch (_) {
      return iso.length > 5 ? iso.substring(11, 16) : iso;
    }
  }

  String get departureClock => formatTime(departureTime);
  String get arrivalClock => formatTime(arrivalTime);
}

class HotelItem {
  final String name;
  final String address;
  final double? lat;
  final double? lon;

  HotelItem({required this.name, required this.address, this.lat, this.lon});

  factory HotelItem.fromJson(Map<String, dynamic> json) {
    String availableText(dynamic value, String fallback) {
      final text = value?.toString().trim() ?? '';
      return text.isEmpty ? fallback : text;
    }
    return HotelItem(
      name: availableText(json['name'], 'Unnamed hotel'),
      address: availableText(json['address'], 'Address unavailable'),
      lat: (json['lat'] as num?)?.toDouble(),
      lon: (json['lon'] as num?)?.toDouble(),
    );
  }
}

class AttractionItem {
  final String name;
  final String category;
  final double? lat;
  final double? lon;
  final String description;

  AttractionItem({
    required this.name,
    required this.category,
    this.lat,
    this.lon,
    this.description = 'Description unavailable.',
  });

  factory AttractionItem.fromJson(Map<String, dynamic> json) {
    final rawCat = json['category']?.toString() ?? 'Sight';
    var cleanCat = 'Sightseeing';
    if (rawCat.contains('entertainment')) {
      cleanCat = 'Entertainment';
    } else if (rawCat.contains('sights') || rawCat.contains('attraction')) {
      cleanCat = 'Landmark & Sights';
    } else if (rawCat.contains('culture') || rawCat.contains('heritage')) {
      cleanCat = 'Culture & Heritage';
    }

    return AttractionItem(
      name: json['name']?.toString() ?? 'Historical Landmark',
      category: cleanCat,
      lat: (json['lat'] as num?)?.toDouble(),
      lon: (json['lon'] as num?)?.toDouble(),
    );
  }
}

/// A Pixabay photo of a destination's country, served by the backend
/// (`GET /photos/place`). Pixabay must be credited wherever one is shown.
class PlacePhoto {
  final String imageUrl;
  final String pageUrl;
  final String photographer;
  final String photographerUrl;
  final String tags;

  PlacePhoto({
    required this.imageUrl,
    required this.pageUrl,
    required this.photographer,
    required this.photographerUrl,
    this.tags = '',
  });

  /// [baseUrl] completes the backend-relative `image_url`.
  factory PlacePhoto.fromJson(Map<String, dynamic> json, String baseUrl) =>
      PlacePhoto(
        imageUrl: '$baseUrl${json['image_url']}',
        pageUrl: json['page_url']?.toString() ?? 'https://pixabay.com/',
        photographer: json['photographer']?.toString() ?? 'Pixabay',
        photographerUrl: json['photographer_url']?.toString() ?? '',
        tags: json['tags']?.toString() ?? '',
      );
}

/// An airport serving a place (`GET /airports/search`), nearest first.
class Airport {
  final String iataCode;
  final String name;
  final String? cityName;

  Airport({required this.iataCode, required this.name, this.cityName});

  factory Airport.fromJson(Map<String, dynamic> json) => Airport(
        iataCode: json['iata_code'].toString(),
        name: json['name']?.toString() ?? json['iata_code'].toString(),
        cityName: json['city_name']?.toString(),
      );
}

/// The planned trip that Flights, Hotels and Attractions start from (KI-21).
/// A new plan is a new object, so views follow it once and then keep the
/// user's own edits until the next plan.
class TripContext {
  final String destination;
  final DateTime startDate;
  final int travelers;

  const TripContext(
      {required this.destination,
      required this.startDate,
      required this.travelers});
}
