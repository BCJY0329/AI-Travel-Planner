import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/chat_models.dart';
import '../models/itinerary_models.dart';

class LemonApiException implements Exception {
  final String message;
  LemonApiException(this.message);
  @override
  String toString() => message;
}

class LemonApiService {
  /// One turn of the freeform planning conversation. Sends the full message
  /// history every time (the backend is stateless) and gets back Lemon's
  /// next reply plus whatever trip fields it has extracted so far.
  Future<LemonChatResult> sendChatTurn({
    required List<ChatTurn> messages,
    required String provider,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/lemon/chat');
    late final http.Response response;
    try {
      response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'messages': messages.map((m) => m.toJson()).toList(),
              'provider': provider,
            }),
          )
          .timeout(const Duration(seconds: 45));
    } catch (e) {
      throw LemonApiException(
        "I couldn't reach the travel planner backend. Make sure the server is running and try again.",
      );
    }

    if (response.statusCode == 200) {
      return LemonChatResult.fromJson(
          jsonDecode(response.body) as Map<String, dynamic>);
    }

    throw LemonApiException('Lemon had trouble understanding that.');
  }

  /// Mirrors travel_backend/services/itinerary_builder.py: 3-day windows run
  /// 3 at a time, each wave gets 75 s. The extra 25 s covers the backend's
  /// 10 s context lookup plus response slack (the original 100 s for one wave).
  static const int _windowDays = 3;
  static const int _concurrentWindows = 3;
  static const int _waveSeconds = 75;
  static const int _overheadSeconds = 25;

  static Duration planTimeoutFor(TripRequest request) {
    var days = 1;
    try {
      final start = DateTime.parse(request.startDate);
      final end = DateTime.parse(request.endDate);
      // UTC calendar dates, so a daylight-saving change can't shorten the count.
      days = DateTime.utc(end.year, end.month, end.day)
              .difference(DateTime.utc(start.year, start.month, start.day))
              .inDays +
          1;
    } on FormatException {
      // The backend rejects malformed dates quickly; one wave is plenty.
    }
    if (days < 1) days = 1;
    final windows = (days + _windowDays - 1) ~/ _windowDays;
    final waves = (windows + _concurrentWindows - 1) ~/ _concurrentWindows;
    return Duration(seconds: _overheadSeconds + _waveSeconds * waves);
  }

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
          .timeout(planTimeoutFor(request));
    } catch (e) {
      throw LemonApiException(
        "I couldn't reach the travel planner backend. Make sure the server is running and try again.",
      );
    }

    if (response.statusCode == 200) {
      return ItineraryResponse.fromJson(
          jsonDecode(response.body) as Map<String, dynamic>);
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
