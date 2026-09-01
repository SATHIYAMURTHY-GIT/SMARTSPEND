import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/budget.dart';

class BudgetRepository {
  BudgetRepository({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  Future<MonthlyBudget?> getBudget() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return null;

    final snapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('settings')
        .doc('budget')
        .get();

    if (!snapshot.exists || snapshot.data() == null) {
      return null;
    }

    return MonthlyBudget.fromFirestore(snapshot.data()!, userId: userId);
  }

  Stream<MonthlyBudget?> watchBudget() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return Stream.value(null);

    return _firestore
        .collection('users')
        .doc(userId)
        .collection('settings')
        .doc('budget')
        .snapshots()
        .map((snapshot) {
          if (!snapshot.exists || snapshot.data() == null) return null;
          return MonthlyBudget.fromFirestore(snapshot.data()!, userId: userId);
        });
  }

  Future<void> upsertBudget({required int monthlyLimitMinorUnits}) async {
    if (monthlyLimitMinorUnits <= 0) {
      throw ArgumentError.value(monthlyLimitMinorUnits, 'monthlyLimitMinorUnits');
    }

    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      throw StateError('An authenticated user is required for the budget.');
    }

    final reference = _firestore.collection('users').doc(userId).collection('settings').doc('budget');
    final data = {
      'userId': userId,
      'monthlyLimitMinorUnits': monthlyLimitMinorUnits,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    await reference.set(data, SetOptions(merge: true));
  }

  Future<void> deleteBudget() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    final reference = _firestore.collection('users').doc(userId).collection('settings').doc('budget');
    await reference.delete();
  }
}
