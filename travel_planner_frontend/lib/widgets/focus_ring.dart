import 'package:flutter/material.dart';
import '../config/app_theme.dart';

/// Outlines [child] while something inside it has keyboard focus, for the
/// custom cards and chips that would otherwise get only Material's faint
/// focus tint. Visual only: focus, taps and semantics stay with the child.
class FocusRing extends StatefulWidget {
  final Widget child;
  final BorderRadius borderRadius;
  final bool circle;
  const FocusRing(
      {super.key,
      required this.child,
      this.borderRadius = BorderRadius.zero,
      this.circle = false});
  @override
  State<FocusRing> createState() => _FocusRingState();
}

class _FocusRingState extends State<FocusRing> {
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    FocusManager.instance.addHighlightModeListener(_modeChanged);
  }

  @override
  void dispose() {
    FocusManager.instance.removeHighlightModeListener(_modeChanged);
    super.dispose();
  }

  void _modeChanged(FocusHighlightMode _) {
    if (_focused && mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) => Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onFocusChange: (value) => setState(() => _focused = value),
      // Always a DecoratedBox, so toggling the ring never remounts the child
      // (which would drop the focus it is showing).
      child: DecoratedBox(
          position: DecorationPosition.foreground,
          decoration: _focused && AppTheme.showFocus
              ? BoxDecoration(
                  shape: widget.circle ? BoxShape.circle : BoxShape.rectangle,
                  borderRadius: widget.circle ? null : widget.borderRadius,
                  border: Border.all(
                      color: AppTheme.focusRing,
                      width: 2.5,
                      strokeAlign: BorderSide.strokeAlignOutside))
              : const BoxDecoration(),
          child: widget.child));
}
