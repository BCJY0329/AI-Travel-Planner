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
  final double rating;
  final int pricePerNight;
  final List<String> amenities;

  HotelItem({
    required this.name,
    required this.address,
    this.lat,
    this.lon,
    this.rating = 4.6,
    this.pricePerNight = 135,
    this.amenities = const ['Free WiFi', 'Air Conditioning', 'Breakfast', 'City View'],
  });

  factory HotelItem.fromJson(Map<String, dynamic> json, {int index = 0}) {
    // Generate realistic simulated perks and ratings for visual delight
    final ratings = [4.8, 4.6, 4.9, 4.5, 4.7, 4.4];
    final prices = [120, 165, 210, 95, 140, 185];
    final amenityList = [
      ['Free WiFi', 'Breakfast Included', 'City View', 'Air Conditioning'],
      ['Infinity Pool', 'Spa & Wellness', 'Free High-speed WiFi', 'Bar / Lounge'],
      ['Boutique Interior', 'Metro 2m Walk', 'Concierge Service', 'Coffee Maker'],
      ['Rooftop Terrace', 'Buffet Breakfast', 'Airport Shuttle', 'Room Service'],
    ];

    return HotelItem(
      name: json['name']?.toString() ?? 'Boutique Hotel',
      address: json['address']?.toString() ?? 'Central District',
      lat: (json['lat'] as num?)?.toDouble(),
      lon: (json['lon'] as num?)?.toDouble(),
      rating: ratings[index % ratings.length],
      pricePerNight: prices[index % prices.length],
      amenities: amenityList[index % amenityList.length],
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
    this.description = 'Popular landmark featuring stunning architecture and rich cultural history.',
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
