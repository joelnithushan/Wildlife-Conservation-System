import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// WildGuard logo + wordmark + tagline. Shared by the splash, loading and login
/// screens so branding stays consistent. Uses the existing logo asset.
class WildGuardBrand extends StatelessWidget {
  const WildGuardBrand({
    super.key,
    this.logoSize = 140,
    this.showWordmark = true,
    this.showTagline = true,
  });

  final double logoSize;
  final bool showWordmark;
  final bool showTagline;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          'assets/images/wildguard_logo.png',
          width: logoSize,
          height: logoSize,
          fit: BoxFit.contain,
          semanticLabel: 'WildGuard logo',
        ),
        if (showWordmark) ...[
          const SizedBox(height: 12),
          const Text(
            'WILDGUARD',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              letterSpacing: 3,
              color: AppColors.primary,
            ),
          ),
        ],
        if (showTagline) ...[
          const SizedBox(height: 6),
          Text(
            'Conserve • Track • Protect',
            style: TextStyle(
              fontSize: 13,
              letterSpacing: 1.2,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ],
    );
  }
}
