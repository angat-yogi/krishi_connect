import 'package:cloud_firestore/cloud_firestore.dart';

enum UserRole { farmer, shopkeeper }

extension UserRoleX on UserRole {
  String get key => switch (this) {
        UserRole.farmer => 'farmer',
        UserRole.shopkeeper => 'shopkeeper',
      };

  String get label => switch (this) {
        UserRole.farmer => 'Farmer',
        UserRole.shopkeeper => 'Shopkeeper',
      };

  static UserRole? fromKey(String? value) {
    switch (value) {
      case 'farmer':
        return UserRole.farmer;
      case 'shopkeeper':
        return UserRole.shopkeeper;
      default:
        return null;
    }
  }
}

class UserProfile {
  const UserProfile({
    required this.uid,
    required this.email,
    this.role,
    this.displayName,
    this.photoUrl,
    this.location,
    this.createdAt,
    this.following = const [],
    this.blockedUsers = const [],
  });

  final String uid;
  final String email;
  final UserRole? role;
  final String? displayName;
  final String? photoUrl;
  final String? location;
  final DateTime? createdAt;
  final List<String> following;
  final List<String> blockedUsers;

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'displayName': displayName,
      'photoUrl': photoUrl,
      'location': location,
      'role': role?.key,
      'createdAt': createdAt,
      'following': following,
      'blockedUsers': blockedUsers,
    };
  }

  factory UserProfile.fromMap(String uid, Map<String, dynamic>? data) {
    if (data == null) {
      throw StateError('Missing user data for uid=$uid');
    }

    return UserProfile(
      uid: uid,
      email: data['email'] as String? ?? '',
      displayName: data['displayName'] as String?,
      photoUrl: data['photoUrl'] as String?,
      location: data['location'] as String?,
      role: UserRoleX.fromKey(data['role'] as String?),
      createdAt: _dateTimeFrom(data['createdAt']),
      following: _stringList(data['following']),
      blockedUsers: _stringList(data['blockedUsers']),
    );
  }

  UserProfile copyWith({
    String? email,
    UserRole? role,
    String? displayName,
    String? photoUrl,
    String? location,
    DateTime? createdAt,
    List<String>? following,
    List<String>? blockedUsers,
  }) {
    return UserProfile(
      uid: uid,
      email: email ?? this.email,
      role: role ?? this.role,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      location: location ?? this.location,
      createdAt: createdAt ?? this.createdAt,
      following: following ?? this.following,
      blockedUsers: blockedUsers ?? this.blockedUsers,
    );
  }
}

DateTime? _dateTimeFrom(dynamic value) {
  if (value == null) return null;
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return DateTime.tryParse(value.toString());
}

String profileDisplayLabel(UserProfile profile) {
  final name = profile.displayName;
  if (name != null && name.trim().isNotEmpty) {
    return name.trim();
  }
  return profile.email;
}

String profileRoleLabel(UserProfile profile) {
  return profile.role?.label ?? 'Role not set';
}

String profileHeaderLabel(UserProfile profile) {
  final name = profileDisplayLabel(profile);
  final role = profile.role?.label ?? 'Set role';
  return '$name ($role)';
}

List<String> _stringList(dynamic value) {
  if (value is Iterable) {
    return value.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
  }
  return const [];
}
