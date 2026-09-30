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

/// Synchronously-readable onboarding-completed flag for the router guard.
///
/// Seeded in `main()` with the value loaded from [OnboardingRepository] and
/// flipped to `true` when the onboarding flow finishes. Kept separate from the
/// async repository so the router `redirect` (which must be synchronous) can read
/// it without awaiting SharedPreferences.
class OnboardingCompletedNotifier extends Notifier<bool> {
  OnboardingCompletedNotifier([this._initial = false]);

  final bool _initial;

  @override
  bool build() => _initial;

  void complete() => state = true;
}

final onboardingCompletedProvider =
    NotifierProvider<OnboardingCompletedNotifier, bool>(
  OnboardingCompletedNotifier.new,
);
