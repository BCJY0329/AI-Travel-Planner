import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/itinerary_models.dart';

class LemonApiException implements Exception {
  final String message;
  LemonApiException(this.message);
  @override
  String toString() => message;
}

class LemonApiService {
  Future<ItineraryResponse> planTrip(TripRequest request) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/lemon/plan');
    late final http.Response response;
    try {
      response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(request.toJson()),
          )
          .timeout(const Duration(seconds: 60));
    } catch (e) {
      throw LemonApiException(
        "I couldn't reach the travel planner backend. Make sure the server is running and try again.",
      );
    }

    if (response.statusCode == 200) {
      return ItineraryResponse.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    }

    // Backend returns {"detail": "..."} for both 502 and 422 errors.
    String detail = 'Something went wrong while planning your trip.';
    try {
      final body = jsonDecode(response.body);
      if (body is Map && body['detail'] != null) {
        detail = body['detail'].toString();
      }
    } catch (_) {}
    throw LemonApiException(detail);
  }
}
