import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists whether the user has finished the first-run onboarding flow.
///
/// Backed by [SharedPreferences] so the splash screen can decide, on every cold
/// start, whether to route new users through onboarding or straight to home.
class OnboardingRepository {
  const OnboardingRepository();

  static const _completedKey = 'onboarding_completed';

  Future<bool> isCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_completedKey) ?? false;
  }

  Future<void> markCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_completedKey, true);
  }
}

final onboardingRepositoryProvider = Provider<OnboardingRepository>(
  (_) => const OnboardingRepository(),
);
