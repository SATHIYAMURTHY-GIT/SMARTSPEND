import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/user_profile.dart';

class UserProfileRepository {
  UserProfileRepository({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestoreInstance = firestore,
      _authInstance = auth;

  final FirebaseFirestore? _firestoreInstance;
  final FirebaseAuth? _authInstance;

  FirebaseFirestore get _firestore =>
      _firestoreInstance ?? FirebaseFirestore.instance;
  FirebaseAuth get _auth => _authInstance ?? FirebaseAuth.instance;

  Future<void> upsertForUser(User user) async {
    final reference = _firestore.collection('users').doc(user.uid);
    late final DocumentSnapshot<Map<String, dynamic>> snapshot;

    try {
      snapshot = await reference.get();
    } on FirebaseException catch (error, stackTrace) {
      debugPrint(
        'Firestore user profile read failed: '
        'code=${error.code}, message=${error.message}',
      );
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    }

    final now = FieldValue.serverTimestamp();

    final profile = <String, dynamic>{
      'uid': user.uid,
      'name': user.displayName,
      'email': user.email,
      'profilePhotoUrl': user.photoURL,
      'updatedAt': now,
      'preferredCurrency': 'USD',
      'themePreference': 'system',
    };

    if (!snapshot.exists) {
      profile['createdAt'] = now;
    }

    try {
      await reference.set(profile, SetOptions(merge: true));
    } on FirebaseException catch (error, stackTrace) {
      debugPrint(
        'Firestore user profile write failed: '
        'code=${error.code}, message=${error.message}',
      );
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    }
  }

  Future<UserProfile?> getProfile() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return null;

    final snapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('settings')
        .doc('profile')
        .get();

    if (!snapshot.exists || snapshot.data() == null) {
      return null;
    }

    return UserProfile.fromFirestore(snapshot.data()!, userId: userId);
  }

  Stream<UserProfile?> watchProfile() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return Stream.value(null);

    return _firestore
        .collection('users')
        .doc(userId)
        .collection('settings')
        .doc('profile')
        .snapshots()
        .map((snapshot) {
          if (!snapshot.exists || snapshot.data() == null) return null;
          return UserProfile.fromFirestore(snapshot.data()!, userId: userId);
        });
  }

  Future<void> updateProfile({String? displayName, String? avatar}) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('An authenticated user is required to update profile.');
    }

    final reference = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('settings')
        .doc('profile');

    final data = <String, dynamic>{
      'userId': user.uid,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (displayName != null) {
      final trimmed = displayName.trim();
      if (trimmed.isEmpty) {
        throw ArgumentError('Username cannot be empty.');
      }
      data['displayName'] = trimmed;
    }

    if (avatar != null) {
      data['avatar'] = avatar.trim().toLowerCase();
    }

    await reference.set(data, SetOptions(merge: true));
  }
}