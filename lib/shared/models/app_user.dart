import 'package:equatable/equatable.dart';

import '../../core/enums/app_enums.dart';

/// Application user / session subject.
///
/// Named `AppUser` to avoid clashing with `firebase_auth`'s `User`. This stays
/// compatible with Firebase Auth: the [id] holds the Firebase UID and the rest
/// of the profile is loaded from the Firestore `users/{uid}` document.
class AppUser extends Equatable {
  const AppUser({
    required this.id,
    required this.name,
    required this.role,
    required this.parkId,
    this.email = '',
    this.isAvailable = true,
    this.isActive = true,
  });

  /// Firebase Auth UID / Firestore document id.
  final String id;
  final String name;
  final String email;
  final UserRole role;
  final String parkId;

  /// Field-availability flag (used by UC03 responder assignment).
  final bool isAvailable;

  /// Whether the account is enabled. Inactive accounts are blocked at login.
  final bool isActive;

  bool get isResponder =>
      role == UserRole.ranger || role == UserRole.communityLiaisonOfficer;

  AppUser copyWith({
    String? id,
    String? name,
    String? email,
    UserRole? role,
    String? parkId,
    bool? isAvailable,
    bool? isActive,
  }) =>
      AppUser(
        id: id ?? this.id,
        name: name ?? this.name,
        email: email ?? this.email,
        role: role ?? this.role,
        parkId: parkId ?? this.parkId,
        isAvailable: isAvailable ?? this.isAvailable,
        isActive: isActive ?? this.isActive,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'email': email,
        'role': role.wire,
        'parkId': parkId,
        'isAvailable': isAvailable,
        'isActive': isActive,
      };

  factory AppUser.fromMap(Map<String, dynamic> map) => AppUser(
        id: map['id'] as String,
        name: map['name'] as String,
        email: map['email'] as String? ?? '',
        role: parseEnum(UserRole.values, map['role'], fallback: UserRole.ranger),
        parkId: map['parkId'] as String,
        isAvailable: map['isAvailable'] as bool? ?? true,
        isActive: map['isActive'] as bool? ?? true,
      );

  @override
  List<Object?> get props =>
      [id, name, email, role, parkId, isAvailable, isActive];
}
