// lib/core/models/app_user.dart
// Domain model for an authenticated user.
// Decouples the rest of the app from FirebaseAuth's User class.
// All UI and state layers consume AppUser — never FirebaseAuth.User directly.

import 'package:firebase_auth/firebase_auth.dart';

/// [USER] Core domain model representing an authenticated Swipify user.
/// Maps directly from Firebase's User object + custom Firestore fields.
class AppUser {
  final String uid;
  final String? name;
  final String? username;
  final String? email;
  final String? phoneNumber;
  final String? photoUrl;
  final bool isEmailVerified;
  
  // Profile fields
  final String? gender; // male, female, other
  final String? dateOfBirth; // YYYY-MM-DD
  
  // Custom fields for Swipify
  final String sellerStatus; // NONE, PENDING, APPROVED, REJECTED
  final String role; // user, seller, admin
  final List<String> followedSellers;
  final String? deviceToken;

  const AppUser({
    required this.uid,
    this.name,
    this.username,
    this.email,
    this.phoneNumber,
    this.photoUrl,
    this.isEmailVerified = false,
    this.gender,
    this.dateOfBirth,
    this.sellerStatus = 'NONE',
    this.role = 'user',
    this.deviceToken,
    this.followedSellers = const [],
  });

  /// Maps a Firebase [User] → [AppUser] cleanly.
  factory AppUser.fromFirebaseUser(User firebaseUser, {Map<String, dynamic>? extraData}) {
    return AppUser(
      uid: firebaseUser.uid,
      name: extraData?['name'] ?? firebaseUser.displayName,
      username: extraData?['username'],
      email: extraData?['email'] ?? firebaseUser.email,
      phoneNumber: extraData?['phone_number'] ?? firebaseUser.phoneNumber,
      photoUrl: firebaseUser.photoURL,
      isEmailVerified: firebaseUser.emailVerified,
      gender: extraData?['gender'],
      dateOfBirth: extraData?['date_of_birth'],
      sellerStatus: extraData?['seller_status'] ?? 'NONE',
      role: extraData?['role'] ?? 'user',
      deviceToken: extraData?['device_token'],
      followedSellers: List<String>.from(extraData?['followed_sellers'] ?? []),
    );
  }

  /// Copy with helper for updates
  AppUser copyWith({
    String? name,
    String? username,
    String? email,
    String? phoneNumber,
    String? photoUrl,
    bool? isEmailVerified,
    String? gender,
    String? dateOfBirth,
    String? sellerStatus,
    String? role,
    String? deviceToken,
    List<String>? followedSellers,
  }) {
    return AppUser(
      uid: uid,
      name: name ?? this.name,
      username: username ?? this.username,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      photoUrl: photoUrl ?? this.photoUrl,
      isEmailVerified: isEmailVerified ?? this.isEmailVerified,
      gender: gender ?? this.gender,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      sellerStatus: sellerStatus ?? this.sellerStatus,
      role: role ?? this.role,
      deviceToken: deviceToken ?? this.deviceToken,
      followedSellers: followedSellers ?? this.followedSellers,
    );
  }

  /// Safe display name: name → email prefix → fallback 'User'
  String get displayName {
    if (name != null && name!.trim().isNotEmpty) return name!.trim();
    if (email != null && email!.isNotEmpty) return email!.split('@').first;
    return 'User';
  }

  /// Check if user has administrative privileges
  bool get isAdmin {
    const adminRoles = [
      'super_admin',
      'operations_admin',
      'finance_admin',
      'moderator',
      'support_admin',
      'admin'
    ];
    return adminRoles.contains(role.toLowerCase());
  }

  @override
  String toString() =>
      'AppUser(uid: $uid, name: $name, email: $email, sellerStatus: $sellerStatus, role: $role)';
}

