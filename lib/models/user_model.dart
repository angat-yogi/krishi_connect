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
  });

  final String uid;
  final String email;
  final UserRole? role;
  final String? displayName;
  final String? photoUrl;
  final String? location;
  final DateTime? createdAt;

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'displayName': displayName,
      'photoUrl': photoUrl,
      'location': location,
      'role': role?.key,
      'createdAt': createdAt,
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
    );
  }

  UserProfile copyWith({
    String? email,
    UserRole? role,
    String? displayName,
    String? photoUrl,
    String? location,
    DateTime? createdAt,
  }) {
    return UserProfile(
      uid: uid,
      email: email ?? this.email,
      role: role ?? this.role,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      location: location ?? this.location,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

DateTime? _dateTimeFrom(dynamic value) {
  if (value == null) return null;
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return DateTime.tryParse(value.toString());
}
