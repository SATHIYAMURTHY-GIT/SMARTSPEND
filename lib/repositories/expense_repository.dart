import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/expense.dart';

class ExpenseRepository {
  ExpenseRepository({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestoreInstance = firestore,
      _authInstance = auth;

  final FirebaseFirestore? _firestoreInstance;
  final FirebaseAuth? _authInstance;

  FirebaseFirestore get _firestore =>
      _firestoreInstance ?? FirebaseFirestore.instance;
  FirebaseAuth get _auth => _authInstance ?? FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> _expensesForCurrentUser() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      throw StateError('An authenticated user is required for expenses.');
    }

    return _firestore.collection('users').doc(userId).collection('expenses');
  }

  Stream<List<Expense>> watchExpenses() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return Stream.value(const <Expense>[]);

    return _expensesForCurrentUser()
        .orderBy('date', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (document) => Expense.fromFirestore(
                  document.id,
                  {...document.data(), 'userId': userId},
                ),
              )
              .toList(growable: false),
        );
  }

  Future<String> createExpense(Expense expense) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      throw StateError('An authenticated user is required for expenses.');
    }

    final reference = _expensesForCurrentUser().doc();
    final data = expense.toFirestore(authenticatedUserId: userId)
      ..addAll({
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    await reference.set(data);
    return reference.id;
  }

  Future<void> updateExpense(Expense expense) async {
    if (expense.id.isEmpty) throw ArgumentError.value(expense.id, 'id');

    final data = expense.toFirestore(
      authenticatedUserId: _requireUserId(),
    )..addAll({'updatedAt': FieldValue.serverTimestamp()});
    await _expensesForCurrentUser().doc(expense.id).set(
      data,
      SetOptions(merge: true),
    );
  }

  Future<void> deleteExpense(String expenseId) async {
    if (expenseId.isEmpty) throw ArgumentError.value(expenseId, 'expenseId');
    await _expensesForCurrentUser().doc(expenseId).delete();
  }

  String _requireUserId() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      throw StateError('An authenticated user is required for expenses.');
    }
    return userId;
  }
}
