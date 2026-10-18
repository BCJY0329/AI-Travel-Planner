import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../config/app_theme.dart';

/// A finite entrance; reduced-motion users see content immediately.
class GentleReveal extends StatelessWidget {
  final Widget child;
  final Duration delay;
  const GentleReveal(
      {super.key, required this.child, this.delay = Duration.zero});
  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    return child
        .animate(delay: delay)
        .fadeIn(duration: AppTheme.motionEntrance, curve: AppTheme.motionCurve)
        .slideY(
            begin: .04,
            end: 0,
            duration: AppTheme.motionEntrance,
            curve: AppTheme.motionCurve);
  }
}
