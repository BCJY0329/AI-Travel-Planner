import 'package:shared_preferences/shared_preferences.dart';

/// How Lemon collects the trip (DECISIONS 059). Free text is the default;
/// guided is the step-by-step controls.
enum ChatMode { free, guided }

/// Lemon's chat settings, kept on this device. The gear menu in the chat
/// header holds them, so more settings can join [ChatMode] later.
class ChatSettingsStore {
  static const _modeKey = 'lemon.chat_mode';

  /// The saved mode, or null when nothing is saved or storage is unavailable
  /// (private windows, blocked site data, tests without a plugin).
  Future<ChatMode?> loadMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_modeKey);
      return ChatMode.values.where((m) => m.name == saved).firstOrNull;
    } catch (_) {
      return null;
    }
  }

  Future<void> saveMode(ChatMode mode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_modeKey, mode.name);
    } catch (_) {
      // The choice still applies for this visit.
    }
  }
}

/// In-memory store for tests and previews.
class MemoryChatSettingsStore implements ChatSettingsStore {
  ChatMode? saved;
  MemoryChatSettingsStore([this.saved]);
  @override
  Future<ChatMode?> loadMode() async => saved;
  @override
  Future<void> saveMode(ChatMode mode) async => saved = mode;
}
