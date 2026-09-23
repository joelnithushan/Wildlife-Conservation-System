import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/enums/app_enums.dart';
import '../demo/demo_data.dart';
import '../models/app_user.dart';

/// Simple current-session abstraction (no full auth workflow yet).
///
/// Holds the active [AppUser] and allows demo/development switching between
/// roles. Compatible with Firebase Auth: once real auth exists, set the signed-in
/// user via [signIn] using the Firebase UID as [AppUser.id].
class CurrentUserNotifier extends Notifier<AppUser> {
  @override
  AppUser build() => DemoData.parkManager;

  /// Replace the active user (e.g. after Firebase sign-in).
  void signIn(AppUser user) => state = user;

  /// Demo helper: switch to a representative user for the given role.
  void switchRole(UserRole role) {
    state = switch (role) {
      UserRole.parkManager => DemoData.parkManager,
      UserRole.ranger => DemoData.rangerPerera,
      UserRole.communityLiaisonOfficer => DemoData.liaisonOfficer,
      UserRole.conservationResearcher => DemoData.researcher,
    };
  }

  void setAvailability(bool isAvailable) =>
      state = state.copyWith(isAvailable: isAvailable);
}

/// The active application user.
final currentUserProvider =
    NotifierProvider<CurrentUserNotifier, AppUser>(CurrentUserNotifier.new);
