import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/travel_models.dart';

class TravelApiService {
  TravelApiService({http.Client? client, http.Client? hotelClient})
      : _client = client, _hotelClient = hotelClient;
  final http.Client? _client;
  final http.Client? _hotelClient;

  Future<List<dynamic>> _list(String path, Map<String, String> query,
      String key, {http.Client? client}) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}$path').replace(queryParameters: query);
    final response = await ((client ?? _client)?.get(uri) ?? http.get(uri))
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw const FormatException('Travel search failed');
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return data[key] as List;
  }

  Future<List<FlightOffer>> searchFlights({
    required String origin, required String destination,
    required String departureDate, int adults = 1,
  }) async {
    final offers = await _list('/flights/search', {
      'origin': origin.trim().toUpperCase(),
      'destination': destination.trim().toUpperCase(),
      'departure_date': departureDate, 'adults': '$adults',
    }, 'offers');
    return offers.map((o) => FlightOffer.fromJson(o as Map<String, dynamic>)).toList();
  }

  Future<List<HotelItem>> searchHotels({required String city, int radiusKm = 5}) async {
    final hotels = await _list('/hotels/search', {
      'city': city.trim(), 'radius_km': '$radiusKm',
    }, 'hotels', client: _hotelClient);
    return hotels.map((h) => HotelItem.fromJson(h as Map<String, dynamic>)).toList();
  }

  Future<List<AttractionItem>> getAttractions({required String city, int radiusKm = 5}) async {
    final attractions = await _list('/places/attractions', {
      'city': city.trim(), 'radius_km': '$radiusKm',
    }, 'attractions');
    return attractions.map((a) => AttractionItem.fromJson(a as Map<String, dynamic>)).toList();
  }
}
