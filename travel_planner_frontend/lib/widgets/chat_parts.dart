import 'dart:async';

import 'package:flutter/material.dart';
import '../config/app_theme.dart';
import 'lemon_avatar_image.dart';
import 'lemon_motion.dart';

// Lemon.ai chat polish (DECISIONS 057): messages rise in, typing dots, the
// planning card and the option pills. Every animation is skipped when the
// reader turns animations off.

/// Fades [child] in while it rises a few pixels, once, when it first
/// appears. [play] false shows it at once (messages already on screen when
/// the panel opens), as does reduced motion.
class RiseIn extends StatefulWidget {
  final Widget child;
  final bool play;
  final Duration delay;
  final Alignment origin;
  const RiseIn(
      {super.key,
      required this.child,
      this.play = true,
      this.delay = Duration.zero,
      this.origin = Alignment.topLeft});
  @override
  State<RiseIn> createState() => _RiseInState();
}

class _RiseInState extends State<RiseIn> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 380));
  late final Animation<double> _t =
      CurvedAnimation(parent: _c, curve: const Cubic(.22, 1, .36, 1));
  Timer? _wait;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_c.isAnimating || _c.isCompleted || _wait != null) return;
    if (!widget.play || MediaQuery.disableAnimationsOf(context)) {
      _c.value = 1;
    } else if (widget.delay == Duration.zero) {
      _c.forward();
    } else {
      _wait = Timer(widget.delay, () {
        if (mounted) _c.forward();
      });
    }
  }

  @override
  void dispose() {
    _wait?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
      animation: _t,
      builder: (context, child) => Opacity(
          opacity: _t.value,
          child: Transform.translate(
              offset: Offset(0, 12 * (1 - _t.value)),
              child: Transform.scale(
                  scale: .96 + .04 * _t.value,
                  alignment: widget.origin,
                  child: child))),
      child: widget.child);
}

/// Three dots that bob in turn inside Lemon's bubble while she works out a
/// reply. Screen readers hear [label] instead.
class TypingDots extends StatelessWidget {
  final String label;
  const TypingDots({super.key, required this.label});
  @override
  Widget build(BuildContext context) => Semantics(
      label: label,
      liveRegion: true,
      excludeSemantics: true,
      child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const LemonAvatarImage(radius: 18),
                const SizedBox(width: 8),
                Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 16),
                    decoration: BoxDecoration(
                        color: AppTheme.surface,
                        border: Border.all(color: AppTheme.lemonBubbleEdge),
                        borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(4),
                            topRight: Radius.circular(18),
                            bottomLeft: Radius.circular(18),
                            bottomRight: Radius.circular(18)),
                        boxShadow: [
                          BoxShadow(
                              color:
                                  AppTheme.bubbleShadow.withValues(alpha: .08),
                              blurRadius: 10,
                              offset: const Offset(0, 3))
                        ]),
                    child: AmbientMotion(
                        period: const Duration(milliseconds: 1100),
                        reverse: false,
                        builder: (t, _) =>
                            Row(mainAxisSize: MainAxisSize.min, children: [
                              for (var i = 0; i < 3; i++) ...[
                                if (i > 0) const SizedBox(width: 5),
                                _dot(t, i),
                              ]
                            ]),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          for (var i = 0; i < 3; i++) ...[
                            if (i > 0) const SizedBox(width: 5),
                            _dot(-1, i),
                          ]
                        ]))),
              ])));

  // t < 0 draws the still dots (reduced motion).
  static Widget _dot(double t, int i) {
    var lift = 0.0, alpha = .7;
    if (t >= 0) {
      // Each dot peaks 0.14 of the cycle after the one before.
      final p = ((t - i * .14) % 1 + 1) % 1;
      final wave = p < .3 ? Curves.easeInOut.transform(p / .3) : 0.0;
      final fall = p >= .3 && p < .6
          ? 1 - Curves.easeInOut.transform((p - .3) / .3)
          : 0.0;
      final h = p < .3 ? wave : fall;
      lift = 5 * h;
      alpha = .45 + .55 * h;
    }
    return Transform.translate(
        offset: Offset(0, -lift),
        child: Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
                color: const Color(0xFFC9B48C).withValues(alpha: alpha),
                shape: BoxShape.circle)));
  }
}

/// Shown while Lemon builds the itinerary, in place of a spinner: her full
/// face floating in a lemon ring, a status line that changes every few
/// seconds and a sliding bar. The lines move on a timer, not on real
/// progress (the backend sends none), so they stay general and the last
/// one holds.
class PlanningCard extends StatefulWidget {
  static const lines = [
    'Checking the weather…',
    'Finding places worth visiting…',
    'Writing your days…',
    "Adding Lemon's tips…",
    'Almost there…',
  ];
  const PlanningCard({super.key});
  @override
  State<PlanningCard> createState() => _PlanningCardState();
}

class _PlanningCardState extends State<PlanningCard> {
  int _line = 0;
  Timer? _timer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Tests turn endless motion off; the first line then stays.
    if (_timer == null &&
        AmbientMotion.loopForever &&
        !MediaQuery.disableAnimationsOf(context)) {
      _timer = Timer.periodic(const Duration(milliseconds: 2500), (_) {
        if (_line >= PlanningCard.lines.length - 1) {
          _timer?.cancel();
          return;
        }
        setState(() => _line++);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const status = TextStyle(
        fontFamily: AppTheme.chatFont,
        color: AppTheme.sorbetInk,
        fontSize: 14,
        height: 1.4,
        fontWeight: FontWeight.w600);
    final reduced = MediaQuery.disableAnimationsOf(context);
    return Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: AppTheme.sorbet,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.sandBorder),
            boxShadow: [
              BoxShadow(
                  color: AppTheme.bubbleShadow.withValues(alpha: .08),
                  blurRadius: 14,
                  offset: const Offset(0, 4))
            ]),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            SizedBox(
                width: 64,
                height: 64,
                child: Stack(alignment: Alignment.center, children: [
                  const PulseRing(
                      size: 62, color: AppTheme.accentLemon, width: 2),
                  LemonFloat(
                      distance: 5,
                      child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(
                              color: AppTheme.accentLemon,
                              shape: BoxShape.circle),
                          child: const CircleAvatar(
                              radius: 26,
                              backgroundColor: AppTheme.surface,
                              child: LemonAvatarImage(radius: 26)))),
                ])),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text('Lemon is planning your trip',
                      style: AppTheme.buttonText(size: 15.5)
                          .copyWith(color: AppTheme.sandInk)),
                  const SizedBox(height: 4),
                  Semantics(
                      liveRegion: true,
                      child: AnimatedSwitcher(
                          duration: reduced
                              ? Duration.zero
                              : const Duration(milliseconds: 320),
                          transitionBuilder: (child, a) => FadeTransition(
                              opacity: a,
                              child: SlideTransition(
                                  position: Tween(
                                          begin: const Offset(0, .4),
                                          end: Offset.zero)
                                      .animate(a),
                                  child: child)),
                          layoutBuilder: (current, previous) => Stack(
                                  alignment: Alignment.centerLeft,
                                  children: [
                                    ...previous,
                                    if (current != null) current
                                  ]),
                          child: Text(PlanningCard.lines[_line],
                              key: ValueKey(_line), style: status))),
                ])),
          ]),
          const SizedBox(height: 14),
          const _SlidingBar(),
          const SizedBox(height: 10),
          const Text(
              'Longer trips can take over a minute. You can keep browsing while you wait.',
              style: TextStyle(
                  fontFamily: AppTheme.chatFont,
                  color: AppTheme.sorbetInk,
                  fontSize: 12.5,
                  height: 1.45,
                  fontWeight: FontWeight.w400)),
        ]));
  }
}

class _SlidingBar extends StatelessWidget {
  const _SlidingBar();
  @override
  Widget build(BuildContext context) {
    const segment = DecoratedBox(
        decoration: BoxDecoration(
            borderRadius: BorderRadius.all(Radius.circular(99)),
            gradient:
                LinearGradient(colors: [AppTheme.accentLemon, AppTheme.cta])));
    return ExcludeSemantics(
        child: ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: Container(
                height: 6,
                color: AppTheme.sand,
                child: AmbientMotion(
                    period: const Duration(milliseconds: 1800),
                    reverse: false,
                    builder: (t, child) => Align(
                        // From fully off the left edge to off the right.
                        alignment: Alignment(
                            -2.4 + 4.8 * Curves.easeInOut.transform(t), 0),
                        child: child),
                    child: const FractionallySizedBox(
                        widthFactor: .4, child: segment)))));
  }
}

/// A large fixed-choice pill (budget): an icon tile, a bold label, a hint
/// line and a tick that fills when chosen. Sky blue with a solid shadow
/// once picked, white with a pale sky edge before.
class OptionPill extends StatefulWidget {
  final String label, hint;
  final IconData icon;
  final bool selected;
  final VoidCallback onPressed;
  const OptionPill(
      {super.key,
      required this.label,
      required this.hint,
      required this.icon,
      required this.selected,
      required this.onPressed});
  @override
  State<OptionPill> createState() => _OptionPillState();
}

class _OptionPillState extends State<OptionPill> {
  bool _hover = false, _focus = false;
  @override
  Widget build(BuildContext context) {
    final on = widget.selected;
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : AppTheme.motionFast;
    return Semantics(
        inMutuallyExclusiveGroup: true,
        checked: on,
        child: AnimatedContainer(
            duration: duration,
            curve: AppTheme.motionCurve,
            transform: Matrix4.translationValues(0, _hover ? -1 : 0, 0),
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                boxShadow: [
                  BoxShadow(
                      color: AppTheme.ctaShadow
                          .withValues(alpha: on ? .5 : (_hover ? .32 : .2)),
                      blurRadius: on || _hover ? 14 : 8,
                      offset: Offset(0, on || _hover ? 5 : 2))
                ]),
            child: Material(
                color: on ? AppTheme.cta : AppTheme.surface,
                shape: StadiumBorder(
                    side: _focus && AppTheme.showFocus
                        ? AppTheme.focusSide
                        : BorderSide(
                            color: on || _hover
                                ? AppTheme.ctaEdge
                                : AppTheme.skyBlue,
                            width: 1.5)),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                    onTap: widget.onPressed,
                    onHover: (v) => setState(() => _hover = v),
                    onFocusChange: (v) => setState(() => _focus = v),
                    child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 60),
                        child: Padding(
                            padding: const EdgeInsets.fromLTRB(8, 8, 14, 8),
                            child: Row(children: [
                              Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                      color:
                                          on ? AppTheme.surface : AppTheme.sky,
                                      shape: BoxShape.circle),
                                  child: Icon(widget.icon,
                                      size: 22, color: AppTheme.primary)),
                              const SizedBox(width: 12),
                              Expanded(
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                    Text(widget.label,
                                        style: AppTheme.buttonText(size: 15.5)
                                            .copyWith(
                                                color: AppTheme.ctaInk,
                                                height: 1.25)),
                                    const SizedBox(height: 1),
                                    // 6.4:1 on white, 4.9:1 on cta.
                                    Text(widget.hint,
                                        style: const TextStyle(
                                            fontFamily: AppTheme.chatFont,
                                            color: Color(0xFF44566E),
                                            fontSize: 13,
                                            height: 1.35)),
                                  ])),
                              const SizedBox(width: 8),
                              AnimatedContainer(
                                  duration: duration,
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: on
                                          ? AppTheme.ctaInk
                                          : Colors.transparent,
                                      border: Border.all(
                                          color: on
                                              ? AppTheme.ctaInk
                                              : AppTheme.ctaEdge,
                                          width: 2)),
                                  child: on
                                      ? const Icon(Icons.check_rounded,
                                          size: 15, color: AppTheme.surface)
                                      : null),
                            ])))))));
  }
}

/// A small multi-choice pill (interests) with its own icon. Picked pills
/// fill sky blue with a shadow, and the icon pops into a tick.
class InterestPill extends StatefulWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final ValueChanged<bool> onChanged;
  const InterestPill(
      {super.key,
      required this.label,
      required this.icon,
      required this.selected,
      required this.onChanged});
  @override
  State<InterestPill> createState() => _InterestPillState();
}

class _InterestPillState extends State<InterestPill> {
  bool _hover = false, _focus = false;
  @override
  Widget build(BuildContext context) {
    final on = widget.selected;
    final reduced = MediaQuery.disableAnimationsOf(context);
    final duration = reduced ? Duration.zero : AppTheme.motionFast;
    return Semantics(
        toggled: on,
        child: AnimatedContainer(
            duration: duration,
            curve: AppTheme.motionCurve,
            transform: Matrix4.translationValues(0, _hover ? -1 : 0, 0),
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                boxShadow: [
                  BoxShadow(
                      color: AppTheme.ctaShadow
                          .withValues(alpha: on ? .45 : (_hover ? .3 : .18)),
                      blurRadius: on || _hover ? 12 : 6,
                      offset: Offset(0, on || _hover ? 4 : 2))
                ]),
            child: Material(
                color: on ? AppTheme.cta : AppTheme.surface,
                shape: StadiumBorder(
                    side: _focus && AppTheme.showFocus
                        ? AppTheme.focusSide
                        : BorderSide(
                            color: on || _hover
                                ? AppTheme.ctaEdge
                                : AppTheme.skyBlue,
                            width: 1.5)),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                    onTap: () => widget.onChanged(!on),
                    onHover: (v) => setState(() => _hover = v),
                    onFocusChange: (v) => setState(() => _focus = v),
                    child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 44),
                        child: Padding(
                            padding: const EdgeInsets.fromLTRB(11, 8, 15, 8),
                            child:
                                Row(mainAxisSize: MainAxisSize.min, children: [
                              AnimatedSwitcher(
                                  duration: reduced
                                      ? Duration.zero
                                      : const Duration(milliseconds: 300),
                                  transitionBuilder: (child, a) =>
                                      ScaleTransition(
                                          scale: CurvedAnimation(
                                              parent: a,
                                              curve: Curves.easeOutBack),
                                          child: child),
                                  child: Icon(
                                      on ? Icons.check_rounded : widget.icon,
                                      key: ValueKey(on),
                                      size: 18,
                                      color: on
                                          ? AppTheme.ctaInk
                                          : AppTheme.primary)),
                              const SizedBox(width: 7),
                              Text(widget.label,
                                  style: AppTheme.buttonText(
                                          size: 14,
                                          weight: on
                                              ? FontWeight.w700
                                              : FontWeight.w600)
                                      .copyWith(
                                          color: on
                                              ? AppTheme.ctaInk
                                              : AppTheme.textPrimary)),
                            ])))))));
  }
}
