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
  /// next reply plus whatever trip fields it has extracted so far. Once a
  /// plan exists, [planSummary] lets Lemon read edit requests (DECISIONS 069).
  Future<LemonChatResult> sendChatTurn({
    required List<ChatTurn> messages,
    required String provider,
    String? planSummary,
    int? planDays,
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
              if (planSummary != null) 'plan_summary': planSummary,
              if (planDays != null) 'plan_days': planDays,
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

  /// Lemon's popular spots for a destination (DECISIONS 069). A big city can
  /// take about 35 s the first time (the backend waits up to 60 s, then
  /// caches for a day). Never throws: a failure is status 'unavailable'.
  static const spotsTimeout = Duration(seconds: 65);

  Future<SpotsResult> getPopularSpots(String destination,
      {List<String> interests = const []}) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/lemon/spots').replace(
        queryParameters: {
          'destination': destination,
          if (interests.isNotEmpty) 'interests': interests.take(12).toList(),
        });
    try {
      final response = await http.get(uri).timeout(spotsTimeout);
      if (response.statusCode == 200) {
        return SpotsResult.fromJson(
            jsonDecode(response.body) as Map<String, dynamic>);
      }
    } catch (_) {
      // Falls through to 'unavailable'.
    }
    return SpotsResult(status: 'unavailable', destination: destination);
  }

  /// Mirrors travel_backend/services/itinerary_builder.py: 3-day windows run
  /// 3 at a time, each wave gets 75 s. The extra 25 s covers the backend's
  /// 10 s context lookup plus response slack (the original 100 s for one wave).
  /// With `auto`, each window falls back through the providers on its own,
  /// with a fresh budget on each (DECISIONS 063), so the wait covers all three
  /// (Groq, Gemini, OpenRouter: `_FALLBACK_ORDER` in auto_provider.py).
  static const int _windowDays = 3;
  static const int _concurrentWindows = 3;
  static const int _waveSeconds = 75;
  static const int _overheadSeconds = 25;
  static const int _autoProviders = 3;

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
    final turns = request.provider.toLowerCase() == 'auto' ? _autoProviders : 1;
    return Duration(seconds: _overheadSeconds + _waveSeconds * waves * turns);
  }

  /// One day is one window: one wave per provider (edit_day in
  /// itinerary_builder.py), plus the same 25 s for context and slack.
  static Duration editTimeoutFor(String provider) => Duration(
      seconds: _overheadSeconds +
          _waveSeconds *
              (provider.toLowerCase() == 'auto' ? _autoProviders : 1));

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
    throw LemonApiException(_detail(response,
        'Something went wrong while planning your trip.'));
  }

  /// Changes one day (DECISIONS 069). The result is previewed by the app
  /// before it replaces the old day; a failure leaves the plan as it was.
  Future<PlanEditResult> editPlan(
      {required TripRequest trip,
      required List<ItineraryDay> days,
      required PlanEdit edit}) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/lemon/edit');
    late final http.Response response;
    try {
      response = await http
          .post(uri,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'trip': trip.toJson(),
                'days': [for (final d in days) d.toJson()],
                'action': edit.action,
                'day': edit.day,
                if (edit.stop != null) 'stop': edit.stop,
                if (edit.instruction != null) 'instruction': edit.instruction,
              }))
          .timeout(editTimeoutFor(trip.provider));
    } catch (e) {
      throw LemonApiException(
        "I couldn't reach the travel planner backend. Make sure the server is running and try again.",
      );
    }
    if (response.statusCode == 200) {
      return PlanEditResult.fromJson(
          jsonDecode(response.body) as Map<String, dynamic>);
    }
    throw LemonApiException(_detail(
        response, "Lemon couldn't change that day right now. Your plan is unchanged."));
  }

  // Backend returns {"detail": "..."} for both 502 and 422 errors.
  static String _detail(http.Response response, String fallback) {
    try {
      final body = jsonDecode(response.body);
      if (body is Map && body['detail'] is String) {
        return body['detail'] as String;
      }
    } catch (_) {}
    return fallback;
  }
}
