import 'package:flutter/foundation.dart';

class ApiConfig {
  /// - Flutter Web: the browser can reach 127.0.0.1 directly.
  /// - Android emulator: 127.0.0.1 refers to the emulator itself, not your PC,
  ///   so the special alias 10.0.2.2 is used to reach the host machine.
  /// - Physical Android device: neither works — replace with your PC's LAN IP.
  static String get baseUrl {
    if (kIsWeb) return 'http://127.0.0.1:8000';
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000';
    }
    return 'http://127.0.0.1:8000';
  }
}
