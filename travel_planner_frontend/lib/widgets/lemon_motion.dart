import 'package:flutter/material.dart';

/// Repeats a gentle animation for as long as it is on screen.
/// Reduced-motion users get the still [child] at once.
class AmbientMotion extends StatefulWidget {
  /// Endless loops keep `pumpAndSettle` from settling, so widget tests turn
  /// this off in `test/flutter_test_config.dart` and get [testCycles] instead.
  static bool loopForever = true;
  static const testCycles = 2;

  final Duration period;
  final bool reverse;
  final Widget child;
  final Widget Function(double t, Widget child) builder;
  const AmbientMotion(
      {super.key,
      required this.period,
      required this.builder,
      required this.child,
      this.reverse = true});
  @override
  State<AmbientMotion> createState() => _AmbientMotionState();
}

class _AmbientMotionState extends State<AmbientMotion>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: widget.period);
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started && !MediaQuery.disableAnimationsOf(context)) {
      _started = true;
      _run();
    }
  }

  Future<void> _run() async {
    try {
      for (var i = 0;
          AmbientMotion.loopForever || i < AmbientMotion.testCycles;
          i++) {
        await _c.forward(from: widget.reverse ? null : 0).orCancel;
        if (widget.reverse) await _c.reverse().orCancel;
      }
    } on TickerCanceled {
      // Disposed mid-cycle.
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return widget.child;
    return AnimatedBuilder(
        animation: _c,
        builder: (context, child) => widget.builder(_c.value, child!),
        child: widget.child);
  }
}

/// Lemon's idle float: drifts up and back.
class LemonFloat extends StatelessWidget {
  final Widget child;
  final double distance;
  const LemonFloat({super.key, required this.child, this.distance = 8});
  @override
  Widget build(BuildContext context) => AmbientMotion(
      period: const Duration(milliseconds: 2200),
      builder: (t, child) => Transform.translate(
          offset: Offset(0, -distance * Curves.easeInOut.transform(t)),
          child: child),
      child: child);
}

/// A ring that swells and fades around Lemon to invite a tap.
class PulseRing extends StatelessWidget {
  final double size;
  final Color color;
  final double width;
  const PulseRing(
      {super.key, required this.size, required this.color, this.width = 3});
  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return SizedBox(width: size, height: size);
    }
    return IgnorePointer(
        child: AmbientMotion(
            period: const Duration(milliseconds: 2800),
            reverse: false,
            builder: (t, child) => Opacity(
                opacity: (1 - t) * .6,
                child: Transform.scale(scale: 1 + .16 * t, child: child)),
            child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: color, width: width)))));
  }
}

/// A slow zoom in and back out across a photo so the hero feels alive.
class SlowZoom extends StatelessWidget {
  final Widget child;
  const SlowZoom({super.key, required this.child});
  @override
  Widget build(BuildContext context) => AmbientMotion(
      period: const Duration(seconds: 20),
      builder: (t, child) => Transform.scale(
          scale: 1.04 + .08 * Curves.easeInOut.transform(t), child: child),
      child: child);
}
