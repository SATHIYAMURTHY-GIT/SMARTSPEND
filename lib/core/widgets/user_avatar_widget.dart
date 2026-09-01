import 'package:flutter/material.dart';

import '../../models/user_profile.dart';

class UserAvatarWidget extends StatelessWidget {
  const UserAvatarWidget({
    this.avatarId,
    this.radius = 24,
    this.showBorder = false,
    this.borderColor,
    this.borderWidth = 2.5,
    super.key,
  });

  final String? avatarId;
  final double radius;
  final bool showBorder;
  final Color? borderColor;
  final double borderWidth;

  @override
  Widget build(BuildContext context) {
    final avatar = AppAvatar.fromId(avatarId);
    final theme = Theme.of(context);
    final size = radius * 2;

    Widget avatarImage = ClipOval(
      child: Image.asset(
        avatar.assetPath,
        width: size,
        height: size,
        cacheWidth: (size * 3).toInt().clamp(48, 256),
        cacheHeight: (size * 3).toInt().clamp(48, 256),
        fit: BoxFit.cover,
        filterQuality: FilterQuality.medium,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            width: size,
            height: size,
            color: theme.colorScheme.primaryContainer,
            alignment: Alignment.center,
            child: Icon(
              Icons.pets_rounded,
              size: radius,
              color: theme.colorScheme.onPrimaryContainer,
            ),
          );
        },
      ),
    );

    if (showBorder) {
      avatarImage = Container(
        padding: const EdgeInsets.all(2.5),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: borderColor ?? theme.colorScheme.primary,
            width: borderWidth,
          ),
        ),
        child: avatarImage,
      );
    }

    return avatarImage;
  }
}
