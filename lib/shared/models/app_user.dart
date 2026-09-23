import 'package:equatable/equatable.dart';

import '../../core/enums/app_enums.dart';

/// Application user / session subject.
///
/// Named `AppUser` to avoid clashing with `firebase_auth`'s `User`. This stays
/// compatible with Firebase Auth: the [id] can hold the Firebase UID.
class AppUser extends Equatable {
  const AppUser({
    required this.id,
    required this.name,
    required this.role,
    required this.parkId,
    this.isAvailable = true,
  });

  final String id;
  final String name;
  final UserRole role;
  final String parkId;
  final bool isAvailable;

  bool get isResponder =>
      role == UserRole.ranger || role == UserRole.communityLiaisonOfficer;

  AppUser copyWith({
    String? id,
    String? name,
    UserRole? role,
    String? parkId,
    bool? isAvailable,
  }) =>
      AppUser(
        id: id ?? this.id,
        name: name ?? this.name,
        role: role ?? this.role,
        parkId: parkId ?? this.parkId,
        isAvailable: isAvailable ?? this.isAvailable,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'role': role.wire,
        'parkId': parkId,
        'isAvailable': isAvailable,
      };

  factory AppUser.fromMap(Map<String, dynamic> map) => AppUser(
        id: map['id'] as String,
        name: map['name'] as String,
        role: parseEnum(UserRole.values, map['role'], fallback: UserRole.ranger),
        parkId: map['parkId'] as String,
        isAvailable: map['isAvailable'] as bool? ?? true,
      );

  @override
  List<Object?> get props => [id, name, role, parkId, isAvailable];
}
