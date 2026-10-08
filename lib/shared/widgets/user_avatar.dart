import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../models/app_user.dart';

/// Circular profile picture for an [AppUser].
///
/// Shows the stored [AppUser.photoUrl] when available, otherwise falls back to
/// the user's initials on a branded background. Used in the admin list and the
/// profile section.
class UserAvatar extends StatelessWidget {
  const UserAvatar({super.key, required this.user, this.radius = 24});

  final AppUser user;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final hasPhoto = user.photoUrl.isNotEmpty;
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.primary.withValues(alpha: 0.12),
      backgroundImage: hasPhoto ? NetworkImage(user.photoUrl) : null,
      child: hasPhoto
          ? null
          : Text(
              _initials(user.name),
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
                fontSize: radius * 0.7,
              ),
            ),
    );
  }

  static String _initials(String name) {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      return parts.first.characters.first.toUpperCase();
    }
    return (parts.first.characters.first + parts.last.characters.first)
        .toUpperCase();
  }
}
