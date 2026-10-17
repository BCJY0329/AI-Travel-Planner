import 'package:flutter/material.dart';

/// Frame the face from the original 675 x 856 artwork, without stretching it.
class LemonAvatarImage extends StatelessWidget {
  final double radius;
  const LemonAvatarImage({required this.radius, super.key});

  @override
  Widget build(BuildContext context) {
    final diameter = radius * 2;
    // A 540px square around the full face, starting at (140, -10) in the source.
    final scale = diameter / 540;
    return ClipOval(
      child: SizedBox(
        width: diameter,
        height: diameter,
        child: Stack(children: [
          Positioned(
            left: -140 * scale,
            top: 10 * scale,
            width: 675 * scale,
            height: 856 * scale,
            child: Image.asset('assets/images/lemon_avatar.png',
                fit: BoxFit.contain,
                filterQuality: FilterQuality.medium,
                isAntiAlias: true),
          ),
        ]),
      ),
    );
  }
}
