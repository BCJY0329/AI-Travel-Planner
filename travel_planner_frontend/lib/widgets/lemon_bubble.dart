import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../config/app_theme.dart';
import 'lemon_avatar_image.dart';
import 'lemon_motion.dart';

class LemonBubble extends StatefulWidget {
  final VoidCallback onTap;
  const LemonBubble({super.key, required this.onTap});

  /// Shown in turn each time the card opens (DECISIONS 057).
  static const invitations = [
    "Tell me where you're dreaming of, and I'll plan the days.",
    "Big adventure or quick escape? Let's plan it together.",
    "Pick a place and some dates. I'll take care of the rest.",
    "Got somewhere in mind? I'll turn it into a day-by-day plan.",
    "Ready when you are. Where shall we go next?",
    "Sun, snow or city lights? Tell me and we'll start planning.",
  ];
  @override
  State<LemonBubble> createState() => _LemonBubbleState();
}

class _LemonBubbleState extends State<LemonBubble> {
  bool _hover = false, _focused = false;
  int _invitation = -1;
  bool get _expanded => _hover || _focused;
  void _update({bool? hover, bool? focused}) {
    final wasExpanded = _expanded;
    setState(() {
      _hover = hover ?? _hover;
      _focused = focused ?? _focused;
      if (!wasExpanded && _expanded) {
        _invitation = (_invitation + 1) % LemonBubble.invitations.length;
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

  // The expanded card wears the chat panel's look (DECISIONS 051): its
  // sorbet header fade and a sand edge, with Fredoka and Lexend type
  // (DECISIONS 057). Lemon herself shows in full, uncropped (DECISIONS 053).
  static const _panelFade = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFF6EBD4), AppTheme.sorbet, AppTheme.surface],
      stops: [0, .45, .9]);

  Widget _launcher(double width) {
    return Material(
      // One surface for both states so expanding feels like the same card.
      color: AppTheme.surface,
      elevation: _expanded ? 8 : 4,
      shadowColor: _expanded
          ? AppTheme.sandDeep.withValues(alpha: .35)
          : Colors.black.withValues(alpha: .25),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_expanded ? 28 : 40),
          side: BorderSide(
              color: _expanded ? AppTheme.sandBorder : AppTheme.skyBlue,
              width: 1.5)),
      clipBehavior: Clip.antiAlias,
      child: Ink(
        decoration: BoxDecoration(gradient: _expanded ? _panelFade : null),
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
                              // Fredoka, the wordmark's rounded face, for
                              // her greeting; Lexend, her chat font, for the
                              // invitation. No call-to-action pill: the
                              // whole card opens the chat (DECISIONS 057).
                              // sandInk and sorbetInk are 7.9:1+ on the fade.
                              const Text("Hi, I'm Lemon!",
                                  style: TextStyle(
                                      fontFamily: AppTheme.noteFont,
                                      color: AppTheme.sandInk,
                                      fontSize: 19,
                                      height: 1.2,
                                      fontWeight: FontWeight.w700)),
                              const SizedBox(height: 6),
                              Text(
                                  LemonBubble.invitations[
                                      _invitation < 0 ? 0 : _invitation],
                                  style: const TextStyle(
                                      fontFamily: AppTheme.chatFont,
                                      color: AppTheme.sorbetInk,
                                      fontSize: 14.5,
                                      height: 1.5,
                                      fontWeight: FontWeight.w400)),
                            ],
                          )),
                          const SizedBox(width: 8),
                          // Lemon's full, uncropped avatar, as before 051.
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
