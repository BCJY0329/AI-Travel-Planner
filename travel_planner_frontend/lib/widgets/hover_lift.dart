import 'package:flutter/material.dart';
import '../config/app_theme.dart';

/// Visual feedback only: child retains its own tap, focus and semantics.
class HoverLift extends StatefulWidget {
  final Widget child;
  const HoverLift({super.key, required this.child});
  @override
  State<HoverLift> createState() => _HoverLiftState();
}

class _HoverLiftState extends State<HoverLift> {
  bool hover = false, pressed = false;
  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    return MouseRegion(
        onEnter: (_) => setState(() => hover = true),
        onExit: (_) => setState(() {
              hover = false;
              pressed = false;
            }),
        child: Listener(
            onPointerDown: (_) => setState(() => pressed = true),
            onPointerUp: (_) => setState(() => pressed = false),
            onPointerCancel: (_) => setState(() => pressed = false),
            child: AnimatedScale(
                scale: reduced
                    ? 1
                    : (pressed
                        ? .98
                        : hover
                            ? 1.025
                            : 1),
                duration: reduced ? Duration.zero : AppTheme.motionFast,
                curve: AppTheme.motionCurve,
                child: widget.child)));
  }
}
