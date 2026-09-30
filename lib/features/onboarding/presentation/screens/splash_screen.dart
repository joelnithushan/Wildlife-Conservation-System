import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/widgets/wildguard_brand.dart';

/// First frame the app shows, and the session-restore / auth-loading state.
///
/// Navigation is driven centrally by the router `redirect`: this screen simply
/// stays visible while the auth session is [AuthInitial] / [AuthLoadingProfile]
/// and the redirect moves on once the session resolves. No artificial delay.
class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            WildGuardBrand(logoSize: 160),
            SizedBox(height: 40),
            SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                valueColor: AlwaysStoppedAnimation(AppColors.primary),
              ),
            ),
            SizedBox(height: 16),
            Text(
              'Loading your account…',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
