import 'dart:async';

import 'package:travel_planner_frontend/widgets/lemon_motion.dart';

/// Runs before every test file. Lemon's idle animations loop forever in the
/// app; in tests they run a couple of cycles so `pumpAndSettle` can settle.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  AmbientMotion.loopForever = false;
  await testMain();
}
