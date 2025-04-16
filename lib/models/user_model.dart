import 'package:cloud_firestore/cloud_firestore.dart';

enum UserRole { mentor, member, none }

class UserModel {
  final String id;
  final String displayName;
  final String email;
  final String? photoURL;
  final Timestamp createdAt;
  final String bio;
  final String status;
  final bool isActive;
  final String privacyLevel;
  final List<String> favTags;

  UserModel({
    required this.id,
    required this.displayName,
    required this.email,
    this.photoURL,
    required this.createdAt,
    required this.bio,
    required this.status,
    required this.isActive,
    required this.privacyLevel,
    required this.favTags,
  });

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return UserModel(
      id: doc.id,
      displayName: data['displayName'] as String? ?? 'Unknown User',
      email: data['email'] as String? ?? '',
      photoURL: data['photoURL'] as String?,
      createdAt: data['createdAt'] as Timestamp? ?? Timestamp.now(),
      bio: data['bio'] as String? ?? '',
      status: data['status'] as String? ?? '',
      isActive: data['isActive'] as bool? ?? false,
      privacyLevel: data['privacyLevel'] as String? ?? 'private',
      favTags: List<String>.from(data['favTags'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'displayName': displayName,
      'email': email,
      'photoURL': photoURL,
      'createdAt': createdAt,
      'bio': bio,
      'status': status,
      'isActive': isActive,
      'privacyLevel': privacyLevel,
      'favTags': favTags,
    };
  }
}

class UserSettings {
  final bool notificationsEnabled;
  final String theme;

  UserSettings({required this.notificationsEnabled, required this.theme});

  factory UserSettings.fromMap(Map<String, dynamic> map) {
    return UserSettings(
      notificationsEnabled: map['notificationsEnabled'] as bool? ?? true,
      theme: map['theme'] as String? ?? 'light',
    );
  }

  Map<String, dynamic> toMap() {
    return {'notificationsEnabled': notificationsEnabled, 'theme': theme};
  }
}
