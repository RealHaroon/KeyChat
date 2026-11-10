import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// The KeyChat logo: a key-shaped sparkle on the brand gradient.
/// Used as the AI's avatar in chat and on the welcome screens.
class KeyChatLogo extends StatelessWidget {
  const KeyChatLogo({super.key, this.size = 40});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: AppTheme.brandGradient,
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      child: Icon(
        Icons.auto_awesome_rounded,
        size: size * 0.55,
        color: Colors.white,
      ),
    );
  }
}
