# LemonTrip frontend

Your personal travel companion, built with Flutter. Lemon.ai helps collect a destination, dates, travelers, budget, and interests, then generates an itinerary after confirmation.

From this directory, use `flutter analyze --no-pub`, `flutter test --no-pub`, and `flutter build web --no-pub` with the existing dependencies. The API base address is configured in `lib/config/api_config.dart`; the FastAPI server is separate.

See [project tasks](../docs/TASKS.md), [known issues](../docs/KNOWN_ISSUES.md), and [verification](../docs/TESTING.md). Search tabs are view-only, trips remain in memory, and listing photos are not integrated. Location actions open an external map in web builds; other platforms offer a copyable link.
