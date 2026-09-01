import 'package:cloud_firestore/cloud_firestore.dart';

enum AppAvatar {
  rabbit(id: 'rabbit', label: 'Rabbit', assetPath: 'assets/images/RABBIT.png'),
  elephant(id: 'elephant', label: 'Elephant', assetPath: 'assets/images/ELEPHANT.png'),
  deer(id: 'deer', label: 'Deer', assetPath: 'assets/images/DEER.png'),
  cheetah(id: 'cheetah', label: 'Cheetah', assetPath: 'assets/images/CHEETAH.png'),
  giraffe(id: 'giraffe', label: 'Giraffe', assetPath: 'assets/images/GIRAFFE.png');

  const AppAvatar({
    required this.id,
    required this.label,
    required this.assetPath,
  });

  final String id;
  final String label;
  final String assetPath;

  static AppAvatar fromId(String? id, {AppAvatar fallback = AppAvatar.rabbit}) {
    if (id == null) return fallback;
    final normalized = id.trim().toLowerCase();
    for (final avatar in AppAvatar.values) {
      if (avatar.id.toLowerCase() == normalized ||
          avatar.name.toLowerCase() == normalized) {
        return avatar;
      }
    }
    return fallback;
  }
}

class UserProfile {
  const UserProfile({
    required this.userId,
    this.displayName,
    this.avatar = 'rabbit',
    this.updatedAt,
  });

  final String userId;
  final String? displayName;
  final String avatar;
  final DateTime? updatedAt;

  String get safeDisplayName {
    final trimmed = displayName?.trim() ?? '';
    return trimmed.isNotEmpty ? trimmed : 'SmartSpend';
  }

  AppAvatar get appAvatar => AppAvatar.fromId(avatar);

  factory UserProfile.fromFirestore(
    Map<String, dynamic> data, {
    required String userId,
  }) {
    DateTime? updatedAt;
    final timestamp = data['updatedAt'];
    if (timestamp is Timestamp) {
      updatedAt = timestamp.toDate();
    } else if (timestamp is String) {
      updatedAt = DateTime.tryParse(timestamp);
    }

    return UserProfile(
      userId: userId,
      displayName: data['displayName'] as String?,
      avatar: (data['avatar'] as String?) ?? 'rabbit',
      updatedAt: updatedAt,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      if (displayName != null) 'displayName': displayName!.trim(),
      'avatar': avatar,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  UserProfile copyWith({
    String? displayName,
    String? avatar,
    DateTime? updatedAt,
  }) {
    return UserProfile(
      userId: userId,
      displayName: displayName ?? this.displayName,
      avatar: avatar ?? this.avatar,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
