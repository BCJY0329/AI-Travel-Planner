import 'package:flutter/material.dart';

class LemonAvatarImage extends StatelessWidget {
  final double radius;
  const LemonAvatarImage({super.key, this.radius = 16});

  @override
  Widget build(BuildContext context) {
    final size = (radius * 2 * MediaQuery.of(context).devicePixelRatio).round();

    return ClipOval(
      child: SizedBox(
        width: radius * 2,
        height: radius * 2,
        child: Image.asset(
          'assets/images/lemon_avatar.png',
          fit: BoxFit.cover,
          alignment: Alignment.topCenter, // shift crop focus upward, toward the face
          filterQuality: FilterQuality.high,
          cacheWidth: size,
          cacheHeight: size,
          errorBuilder: (context, error, stackTrace) => Container(
            color: Colors.amber.shade300,
            child: Icon(Icons.emoji_emotions, color: Colors.white, size: radius),
          ),
        ),
      ),
    );
  }
}