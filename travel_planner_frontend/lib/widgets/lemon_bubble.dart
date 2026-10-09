import 'package:flutter/material.dart';

class LemonBubble extends StatelessWidget {
  final VoidCallback onTap;
  const LemonBubble({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.of(context).devicePixelRatio;
    const displayWidth = 110.0; // bumped up from 90
    final decodeWidth = (displayWidth * dpr).round();

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Image.asset(
          'assets/images/lemon_avatar.png',
          width: displayWidth,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
          cacheWidth: decodeWidth,
        ),
      ),
    );
  }
}