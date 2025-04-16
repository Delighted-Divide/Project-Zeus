import 'package:cloud_firestore/cloud_firestore.dart';

class GroupSettings {
  final String visibility;
  final bool joinApproval;

  GroupSettings({required this.visibility, required this.joinApproval});

  factory GroupSettings.fromMap(Map<String, dynamic> map) {
    return GroupSettings(
      visibility: map['visibility'] as String? ?? 'private',
      joinApproval: map['joinApproval'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {'visibility': visibility, 'joinApproval': joinApproval};
  }
}

class GroupModel {
  final String id;
  final String name;
  final String description;
  final Timestamp createdAt;
  final String creatorId;
  final String? photoURL;
  final List<String> tags;
  final GroupSettings settings;

  GroupModel({
    required this.id,
    required this.name,
    required this.description,
    required this.createdAt,
    required this.creatorId,
    this.photoURL,
    required this.tags,
    required this.settings,
  });

  factory GroupModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return GroupModel(
      id: doc.id,
      name: data['name'] as String? ?? 'Unnamed Group',
      description: data['description'] as String? ?? '',
      createdAt: data['createdAt'] as Timestamp? ?? Timestamp.now(),
      creatorId: data['creatorId'] as String? ?? '',
      photoURL: data['photoURL'] as String?,
      tags: List<String>.from(data['tags'] ?? []),
      settings: GroupSettings.fromMap(
        data['settings'] as Map<String, dynamic>? ?? {},
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'createdAt': createdAt,
      'creatorId': creatorId,
      'photoURL': photoURL,
      'tags': tags,
      'settings': settings.toMap(),
    };
  }
}

class GroupMember {
  final String userId;
  final String displayName;
  final String? photoURL;
  final String role;
  final Timestamp joinedAt;

  GroupMember({
    required this.userId,
    required this.displayName,
    this.photoURL,
    required this.role,
    required this.joinedAt,
  });

  factory GroupMember.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return GroupMember(
      userId: doc.id,
      displayName: data['displayName'] as String? ?? 'Unknown User',
      photoURL: data['photoURL'] as String?,
      role: data['role'] as String? ?? 'member',
      joinedAt: data['joinedAt'] as Timestamp? ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'displayName': displayName,
      'photoURL': photoURL,
      'role': role,
      'joinedAt': joinedAt,
    };
  }

  bool get ismentor => role == 'mentor';
}

class GroupChannel {
  final String id;
  final String name;
  final String description;
  final String type;
  final Timestamp createdAt;
  final String createdBy;
  final String instructions;

  GroupChannel({
    required this.id,
    required this.name,
    required this.description,
    required this.type,
    required this.createdAt,
    required this.createdBy,
    required this.instructions,
  });

  factory GroupChannel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return GroupChannel(
      id: doc.id,
      name: data['name'] as String? ?? 'Unnamed Channel',
      description: data['description'] as String? ?? '',
      type: data['type'] as String? ?? 'discussion',
      createdAt: data['createdAt'] as Timestamp? ?? Timestamp.now(),
      createdBy: data['createdBy'] as String? ?? '',
      instructions: data['instructions'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'type': type,
      'createdAt': createdAt,
      'createdBy': createdBy,
      'instructions': instructions,
    };
  }
}

class AssessmentInfo {
  final String id;
  final String title;
  final String description;
  final String assignedBy;
  final Timestamp assignedAt;
  final Timestamp startTime;
  final Timestamp endTime;
  final bool hasTimer;
  final int timerDuration;
  final bool madeByAI;

  AssessmentInfo({
    required this.id,
    required this.title,
    required this.description,
    required this.assignedBy,
    required this.assignedAt,
    required this.startTime,
    required this.endTime,
    required this.hasTimer,
    required this.timerDuration,
    required this.madeByAI,
  });

  factory AssessmentInfo.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return AssessmentInfo(
      id: doc.id,
      title: data['title'] as String? ?? 'Unnamed Assessment',
      description: data['description'] as String? ?? '',
      assignedBy: data['assignedBy'] as String? ?? '',
      assignedAt: data['assignedAt'] as Timestamp? ?? Timestamp.now(),
      startTime: data['startTime'] as Timestamp? ?? Timestamp.now(),
      endTime: data['endTime'] as Timestamp? ?? Timestamp.now(),
      hasTimer: data['hasTimer'] as bool? ?? false,
      timerDuration: data['timerDuration'] as int? ?? 0,
      madeByAI: data['madeByAI'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'assignedBy': assignedBy,
      'assignedAt': assignedAt,
      'startTime': startTime,
      'endTime': endTime,
      'hasTimer': hasTimer,
      'timerDuration': timerDuration,
      'madeByAI': madeByAI,
    };
  }
}
