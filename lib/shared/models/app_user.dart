import 'package:equatable/equatable.dart';

import '../../core/enums/app_enums.dart';

/// Application user / session subject.
///
/// Named `AppUser` to avoid clashing with `firebase_auth`'s `User`. This stays
/// compatible with Firebase Auth: the [id] holds the Firebase UID and the rest
/// of the profile is loaded from the Firestore `users/{uid}` document.
///
/// Profiles are created and maintained by the system [UserRole.admin]; staff do
/// not self-register or edit their own details (see AGENTS.md §10/§13).
class AppUser extends Equatable {
  const AppUser({
    required this.id,
    required this.name,
    required this.role,
    required this.parkId,
    this.username = '',
    this.email = '',
    this.mobileNumber = '',
    this.personalMobileNumber = '',
    this.nic = '',
    this.gender,
    this.dateOfBirth,
    this.photoUrl = '',
    this.isAvailable = true,
    this.isActive = true,
  });

  /// Firebase Auth UID / Firestore document id.
  final String id;

  /// Full name, e.g. "Kumar Ravi". Shown in the profile section, to the admin,
  /// and in ranger/manager detail views. Elsewhere the [username] is used.
  final String name;

  /// System-generated login handle, e.g. `ranger_kumar_001`
  /// (`role_firstname_seq`). Unique across users. Empty for the seeded admin,
  /// which signs in by email only.
  final String username;

  final String email;
  final String mobileNumber;
  final String personalMobileNumber;
  final String nic;
  final Gender? gender;
  final DateTime? dateOfBirth;

  /// Firebase Storage download URL for the profile picture.
  final String photoUrl;

  final UserRole role;
  final String parkId;

  /// Field-availability flag (used by UC03 responder assignment).
  final bool isAvailable;

  /// Whether the account is enabled. Inactive accounts are blocked at login.
  final bool isActive;

  bool get isResponder =>
      role == UserRole.ranger || role == UserRole.communityLiaisonOfficer;

  bool get isAdmin => role == UserRole.admin;

  /// Age derived from [dateOfBirth] so it can never drift out of date.
  /// Returns null when no DOB is recorded. Uses a fixed "today" supplied by the
  /// caller when needed; defaults to [DateTime.now] for UI display.
  int? get age => ageAsOf(DateTime.now());

  int? ageAsOf(DateTime today) {
    final dob = dateOfBirth;
    if (dob == null) return null;
    var years = today.year - dob.year;
    final hadBirthday =
        today.month > dob.month ||
            (today.month == dob.month && today.day >= dob.day);
    if (!hadBirthday) years -= 1;
    return years < 0 ? 0 : years;
  }

  AppUser copyWith({
    String? id,
    String? name,
    String? username,
    String? email,
    String? mobileNumber,
    String? personalMobileNumber,
    String? nic,
    Gender? gender,
    DateTime? dateOfBirth,
    String? photoUrl,
    UserRole? role,
    String? parkId,
    bool? isAvailable,
    bool? isActive,
  }) =>
      AppUser(
        id: id ?? this.id,
        name: name ?? this.name,
        username: username ?? this.username,
        email: email ?? this.email,
        mobileNumber: mobileNumber ?? this.mobileNumber,
        personalMobileNumber: personalMobileNumber ?? this.personalMobileNumber,
        nic: nic ?? this.nic,
        gender: gender ?? this.gender,
        dateOfBirth: dateOfBirth ?? this.dateOfBirth,
        photoUrl: photoUrl ?? this.photoUrl,
        role: role ?? this.role,
        parkId: parkId ?? this.parkId,
        isAvailable: isAvailable ?? this.isAvailable,
        isActive: isActive ?? this.isActive,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'username': username,
        'email': email,
        'mobileNumber': mobileNumber,
        'personalMobileNumber': personalMobileNumber,
        'nic': nic,
        'gender': gender?.wire,
        'dateOfBirth': dateOfBirth?.toIso8601String(),
        'photoUrl': photoUrl,
        'role': role.wire,
        'parkId': parkId,
        'isAvailable': isAvailable,
        'isActive': isActive,
      };

  factory AppUser.fromMap(Map<String, dynamic> map) => AppUser(
        id: map['id'] as String,
        name: map['name'] as String,
        username: map['username'] as String? ?? '',
        email: map['email'] as String? ?? '',
        mobileNumber: map['mobileNumber'] as String? ?? '',
        personalMobileNumber: map['personalMobileNumber'] as String? ?? '',
        nic: map['nic'] as String? ?? '',
        gender: parseEnumOrNull(Gender.values, map['gender']),
        dateOfBirth: _parseDate(map['dateOfBirth']),
        photoUrl: map['photoUrl'] as String? ?? '',
        role: parseEnum(UserRole.values, map['role'], fallback: UserRole.ranger),
        parkId: map['parkId'] as String? ?? '',
        isAvailable: map['isAvailable'] as bool? ?? true,
        isActive: map['isActive'] as bool? ?? true,
      );

  static DateTime? _parseDate(Object? raw) {
    if (raw is String && raw.isNotEmpty) return DateTime.tryParse(raw);
    return null;
  }

  @override
  List<Object?> get props => [
        id,
        name,
        username,
        email,
        mobileNumber,
        personalMobileNumber,
        nic,
        gender,
        dateOfBirth,
        photoUrl,
        role,
        parkId,
        isAvailable,
        isActive,
      ];
}
