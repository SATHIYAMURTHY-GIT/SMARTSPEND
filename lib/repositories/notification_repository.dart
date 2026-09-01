import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/notification_preferences.dart';

class NotificationRepository {
  NotificationRepository({FirebaseFirestore? firestore, FirebaseAuth? auth})
      : _firestoreInstance = firestore,
        _authInstance = auth;

  final FirebaseFirestore? _firestoreInstance;
  final FirebaseAuth? _authInstance;

  FirebaseFirestore get _firestore =>
      _firestoreInstance ?? FirebaseFirestore.instance;
  FirebaseAuth get _auth => _authInstance ?? FirebaseAuth.instance;

  DocumentReference<Map<String, dynamic>>? _preferencesDoc() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return null;
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('settings')
        .doc('notifications');
  }

  Future<NotificationPreferences> getPreferences() async {
    final doc = _preferencesDoc();
    if (doc == null) return const NotificationPreferences();

    final snapshot = await doc.get();
    if (!snapshot.exists || snapshot.data() == null) {
      return const NotificationPreferences();
    }

    return NotificationPreferences.fromFirestore(snapshot.data()!);
  }

  Stream<NotificationPreferences> watchPreferences() {
    final doc = _preferencesDoc();
    if (doc == null) {
      return Stream.value(const NotificationPreferences());
    }

    return doc.snapshots().map((snapshot) {
      if (!snapshot.exists || snapshot.data() == null) {
        return const NotificationPreferences();
      }
      return NotificationPreferences.fromFirestore(snapshot.data()!);
    });
  }

  Future<void> updatePreferences(NotificationPreferences preferences) async {
    final doc = _preferencesDoc();
    if (doc == null) {
      throw StateError('An authenticated user is required for notification settings.');
    }

    final data = preferences.toFirestore()
      ..addAll({'updatedAt': FieldValue.serverTimestamp()});

    await doc.set(data, SetOptions(merge: true));
  }
}
