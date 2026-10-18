import 'package:flutter/material.dart';
import '../config/app_theme.dart';

/// A code-drawn citrus compass mark, crisp at every display density.
class LemonBrand extends StatelessWidget {
  const LemonBrand({super.key});
  @override
  Widget build(BuildContext context) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
            width: 42,
            height: 42,
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
                color: AppTheme.accentLemon,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                      color: AppTheme.accentLemon.withValues(alpha: .45),
                      blurRadius: 12,
                      offset: const Offset(0, 4))
                ]),
            child: const CustomPaint(painter: _CitrusCompass())),
        const SizedBox(width: 10),
        const Text.rich(
            TextSpan(text: 'Lemon', children: [
              TextSpan(
                  text: 'Trip', style: TextStyle(color: AppTheme.skyMintBright))
            ]),
            style: TextStyle(
                fontFamily: AppTheme.headingFont,
                color: AppTheme.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -.6)),
      ]);
}

class _CitrusCompass extends CustomPainter {
  const _CitrusCompass();
  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 32, size.height / 32);
    final line = Paint()
      ..color = AppTheme.lemonInk
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final fruit = Path()
      ..moveTo(5, 25)
      ..cubicTo(-2, 13, 9, 2, 21, 7)
      ..quadraticBezierTo(26, 6, 27, 9)
      ..cubicTo(35, 21, 21, 34, 10, 28)
      ..quadraticBezierTo(5, 30, 5, 25);
    canvas.drawPath(fruit, line);
    canvas.drawPath(
        Path()
          ..moveTo(19, 6)
          ..quadraticBezierTo(19, 0, 28, 1)
          ..quadraticBezierTo(27, 7, 19, 6),
        Paint()..color = AppTheme.lemonInk);
    canvas.drawPath(
        Path()
          ..moveTo(10, 23)
          ..quadraticBezierTo(8, 13, 21, 14),
        line..color = AppTheme.primary);
    canvas.drawCircle(
        const Offset(10, 23), 2, Paint()..color = AppTheme.primary);
    canvas.drawPath(
        Path()
          ..moveTo(18, 10)
          ..lineTo(24, 14)
          ..lineTo(18, 18),
        line);
  }

  @override
  bool shouldRepaint(covariant _CitrusCompass oldDelegate) => false;
}
