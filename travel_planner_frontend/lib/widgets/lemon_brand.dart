import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../config/app_theme.dart';

/// The LemonTrip wordmark: bold (700) Fredoka letters, as in the mock, with a
/// lemon and leaf as the dot on the "i". A colour wave (lemon, then sand) runs
/// through the letters once when it first appears and again on hover, then the
/// lemon gives a little wiggle. It never loops; reduced-motion users see the
/// still wordmark.
class LemonBrand extends StatefulWidget {
  final double fontSize;
  const LemonBrand({super.key, this.fontSize = 28});
  @override
  State<LemonBrand> createState() => _LemonBrandState();
}

class _LemonBrandState extends State<LemonBrand>
    with SingleTickerProviderStateMixin {
  // A dotless "i": the lemon is its dot.
  static const _word = 'LemonTrıp';
  static const _lemonIndex = 7;
  static const _letterMs = 1500, _staggerMs = 110;
  static const _wiggleStartMs = 2080, _wiggleMs = 800;
  static const _totalMs = _wiggleStartMs + _wiggleMs;

  // Fredoka's x-height is half its em, so the "i" stem tops out there.
  static const _xHeight = .5;

  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: _totalMs));
  bool _started = false;

  static final _wave = TweenSequence<Color?>([
    TweenSequenceItem(
        tween: ColorTween(begin: AppTheme.textPrimary, end: AppTheme.lemonDeep),
        weight: 1),
    TweenSequenceItem(
        tween: ColorTween(begin: AppTheme.lemonDeep, end: AppTheme.sandDeep),
        weight: 1),
    TweenSequenceItem(
        tween: ColorTween(begin: AppTheme.sandDeep, end: AppTheme.textPrimary),
        weight: 1),
  ]);

  static final _wiggle = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 0, end: -14), weight: 1),
    TweenSequenceItem(tween: Tween(begin: -14, end: 10), weight: 1),
    TweenSequenceItem(tween: Tween(begin: 10, end: -5), weight: 1),
    TweenSequenceItem(tween: Tween(begin: -5, end: 0), weight: 1),
  ]);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      if (!MediaQuery.disableAnimationsOf(context)) _c.forward();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _replay() {
    if (MediaQuery.disableAnimationsOf(context) || _c.isAnimating) return;
    _c.forward(from: 0);
  }

  Color _letterColor(int index, double ms) {
    final t = (ms - index * _staggerMs) / _letterMs;
    if (t <= 0 || t >= 1) return AppTheme.textPrimary;
    return _wave.transform(Curves.easeInOut.transform(t))!;
  }

  double _lemonTurn(double ms) {
    final t = (ms - _wiggleStartMs) / _wiggleMs;
    if (t <= 0 || t >= 1) return 0;
    return _wiggle.transform(Curves.easeInOut.transform(t)) * math.pi / 180;
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.fontSize;
    final style = TextStyle(
        fontFamily: AppTheme.noteFont,
        fontSize: size,
        fontWeight: FontWeight.w700,
        letterSpacing: -.2,
        height: 1.15,
        color: AppTheme.textPrimary);
    final scaler = MediaQuery.textScalerOf(context);
    final layout = TextPainter(
        text: TextSpan(text: _word, style: style),
        textDirection: TextDirection.ltr,
        textScaler: scaler)
      ..layout();
    final iBox = layout
        .getBoxesForSelection(const TextSelection(
            baseOffset: _lemonIndex, extentOffset: _lemonIndex + 1))
        .first;
    final baseline =
        layout.computeDistanceToActualBaseline(TextBaseline.alphabetic);
    final em = scaler.scale(size);
    final lemon = em * .56;
    // The lemon's body fills the lower ~84% of its box; it sits just above
    // the stem, centred on it.
    final lemonTop = baseline - em * (_xHeight + .03) - lemon * .84;
    final lemonLeft = (iBox.left + iBox.right) / 2 - lemon / 2;
    layout.dispose();

    return Semantics(
      label: 'LemonTrip',
      excludeSemantics: true,
      child: MouseRegion(
        onEnter: (_) => _replay(),
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final ms = _c.value * _totalMs;
            final playing = _c.isAnimating;
            return Stack(clipBehavior: Clip.none, children: [
              Text.rich(
                  TextSpan(children: [
                    for (var i = 0; i < _word.length; i++)
                      TextSpan(
                          text: _word[i],
                          style: playing
                              ? TextStyle(color: _letterColor(i, ms))
                              : null),
                  ]),
                  style: style,
                  textScaler: scaler),
              Positioned(
                  left: lemonLeft,
                  top: lemonTop,
                  child: Transform.rotate(
                      angle: playing ? _lemonTurn(ms) : 0,
                      alignment: const Alignment(0, .7),
                      child: CustomPaint(
                          size: Size.square(lemon),
                          painter: _LemonPainter(detailed: lemon >= 24)))),
            ]);
          },
        ),
      ),
    );
  }
}

/// The wordmark's lemon on its own, for small badges (decorative).
class LemonMark extends StatelessWidget {
  final double size;
  const LemonMark({super.key, this.size = 20});
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
      child: CustomPaint(
          size: Size.square(size),
          painter: _LemonPainter(detailed: size >= 24)));
}

/// A plump tilted lemon with a shine and a green leaf, drawn on a 32-unit
/// grid. Small sizes drop the leaf vein and use a bolder outline.
class _LemonPainter extends CustomPainter {
  final bool detailed;
  const _LemonPainter({required this.detailed});

  static Path _body() => Path()
    ..moveTo(3.2, 18.4)
    ..relativeCubicTo(-.9, -.3, -1.3, -1.2, -.9, -2)
    ..relativeCubicTo(.3, -.6, 1, -.9, 1.6, -.8)
    ..cubicTo(5.6, 10.9, 10.2, 8, 15.6, 8.1)
    ..relativeCubicTo(4.9, .1, 9, 2.9, 10.6, 6.9)
    ..relativeCubicTo(.7, -.1, 1.4, .3, 1.6, 1)
    ..relativeCubicTo(.3, .8, -.2, 1.7, -1.1, 1.9)
    ..relativeCubicTo(-1.4, 4.8, -6, 8.2, -11.4, 8.1)
    ..relativeCubicTo(-5.2, -.1, -9.5, -3.2, -10.7, -7.2)
    ..close();

  static Path _leaf() => Path()
    ..moveTo(18.2, 9.6)
    ..relativeCubicTo(-.2, -3.4, 2.4, -6.2, 6.6, -6.6)
    ..relativeCubicTo(.1, 3.8, -2.6, 6.6, -6.6, 6.6)
    ..close();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 32, size.height / 32);
    final outline = detailed ? 1.3 : 1.7;

    canvas.save();
    canvas.translate(16, 18);
    canvas.rotate(-28 * math.pi / 180);
    canvas.translate(-16, -18);
    final body = _body();
    final bounds = body.getBounds();
    canvas.drawPath(
        body,
        Paint()
          ..shader = const RadialGradient(
              center: Alignment(-.24, -.3),
              radius: .72,
              colors: [
                Color(0xFFFFF08A),
                AppTheme.accentLemon,
                AppTheme.accentLemonDark
              ],
              stops: [
                0,
                .6,
                1
              ]).createShader(bounds));
    canvas.drawPath(
        body,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = outline
          ..strokeJoin = StrokeJoin.round
          ..color = const Color(0xFFC9960B));
    if (detailed) {
      canvas.save();
      canvas.translate(11.5, 13.4);
      canvas.rotate(-16 * math.pi / 180);
      canvas.drawOval(
          Rect.fromCenter(center: Offset.zero, width: 7.2, height: 3),
          Paint()..color = Colors.white.withValues(alpha: .7));
      canvas.restore();
    }
    canvas.restore();

    final leaf = _leaf();
    canvas.drawPath(leaf, Paint()..color = const Color(0xFF7CC36A));
    canvas.drawPath(
        leaf,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = detailed ? 1 : 1.2
          ..strokeJoin = StrokeJoin.round
          ..color = const Color(0xFF4E9A45));
    if (detailed) {
      canvas.drawPath(
          Path()
            ..moveTo(18.4, 9.4)
            ..relativeCubicTo(1.5, -1.9, 3.3, -3.4, 5.3, -4.4),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = .8
            ..strokeCap = StrokeCap.round
            ..color = const Color(0xFF4E9A45));
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_LemonPainter old) => old.detailed != detailed;
}
