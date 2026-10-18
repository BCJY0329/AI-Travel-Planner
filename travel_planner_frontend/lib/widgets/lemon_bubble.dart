import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../config/app_theme.dart';
import 'lemon_avatar_image.dart';
import 'lemon_motion.dart';

class LemonBubble extends StatefulWidget {
  final VoidCallback onTap;
  const LemonBubble({super.key, required this.onTap});
  @override
  State<LemonBubble> createState() => _LemonBubbleState();
}

class _LemonBubbleState extends State<LemonBubble> {
  static const invitations = [
    "Turn your dream travel plan into an itinerary!",
    "Your next adventure called. Shall we make a plan?",
    "Big trip or little escape? Let us dream it up!",
    "You bring the curiosity. I will help with the plan!",
    "Your helpful travel planner here! Ready whenever you are!",
    "Travel to wherever you dream of! The sky's the limit!",
  ];
  bool _hover = false, _focused = false;
  int _invitation = -1;
  bool get _expanded => _hover || _focused;
  void _update({bool? hover, bool? focused}) {
    final wasExpanded = _expanded;
    setState(() {
      _hover = hover ?? _hover;
      _focused = focused ?? _focused;
      if (!wasExpanded && _expanded) {
        _invitation = (_invitation + 1) % invitations.length;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final width = math.min(340.0, MediaQuery.sizeOf(context).width - 40);
    return Stack(clipBehavior: Clip.none, children: [
      if (!_expanded)
        const Positioned(
            left: 0,
            top: 0,
            child: PulseRing(size: 76, color: AppTheme.primary)),
      _launcher(width),
    ]);
  }

  Widget _launcher(double width) {
    return Material(
      // One surface for both states so expanding feels like the same card.
      color: AppTheme.surface,
      elevation: _expanded ? 8 : 4,
      shadowColor: Colors.black.withValues(alpha: .25),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_expanded ? 28 : 40),
          side: const BorderSide(color: AppTheme.skyMint, width: 1.5)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: widget.onTap,
        hoverColor: Colors.transparent,
        focusColor: Colors.transparent,
        onHover: (value) => _update(hover: value),
        onFocusChange: (value) => _update(focused: value),
        child: Semantics(
          label: 'Ask Lemon',
          button: true,
          child: _LauncherSize(
            child: SizedBox(
              width: _expanded ? width : 76,
              child: _expanded
                  ? Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(children: [
                        Expanded(
                            child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Hey, explorer! ✨',
                                style: TextStyle(
                                    color: AppTheme.teal,
                                    fontWeight: FontWeight.w800)),
                            const SizedBox(height: 6),
                            Text(invitations[_invitation < 0 ? 0 : _invitation],
                                style: const TextStyle(height: 1.4)),
                            const SizedBox(height: 10),
                            const Text('Let’s plan together →',
                                style: TextStyle(
                                    color: AppTheme.primary,
                                    fontWeight: FontWeight.w700)),
                          ],
                        )),
                        const SizedBox(width: 8),
                        Image.asset('assets/images/lemon_avatar.png',
                            width: 88,
                            height: 116,
                            fit: BoxFit.contain,
                            filterQuality: FilterQuality.high,
                            excludeFromSemantics: true),
                      ]),
                    )
                  : const Padding(
                      padding: EdgeInsets.all(6),
                      child: LemonAvatarImage(radius: 32)),
            ),
          ),
        ),
      ),
    );
  }
}

class _LauncherSize extends StatelessWidget {
  final Widget child;
  const _LauncherSize({required this.child});
  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    return AnimatedSize(
        duration: AppTheme.motionStandard,
        curve: AppTheme.motionCurve,
        alignment: Alignment.bottomRight,
        child: child);
  }
}
