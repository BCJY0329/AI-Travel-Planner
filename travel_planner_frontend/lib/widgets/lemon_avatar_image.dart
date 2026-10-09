import 'package:flutter/material.dart';

class LemonAvatarImage extends StatelessWidget {
  final double radius;
  const LemonAvatarImage({required this.radius, super.key});

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.of(context).devicePixelRatio;
    final decodeSize = (radius * 2 * dpr * 2).round(); // extra *2 since we're zooming in past the box size

    return ClipOval(
      child: SizedBox(
        width: radius * 2,
        height: radius * 2,
        child: Transform.scale(
          scale: 2.0,                          // how far to zoom in — increase to crop tighter on the face
          alignment: const Alignment(0.6, -0.5), // which point stays fixed while zooming — negative Y = toward the top/face
          child: Image.asset(
            'assets/images/lemon_avatar.png',
            fit: BoxFit.cover,
            filterQuality: FilterQuality.high,
            cacheWidth: decodeSize,
            cacheHeight: decodeSize,
          ),
        ),
      ),
    );
  }
}