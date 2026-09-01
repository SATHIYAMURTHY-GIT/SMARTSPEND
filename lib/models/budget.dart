import 'package:cloud_firestore/cloud_firestore.dart';

class MonthlyBudget {
  const MonthlyBudget({
    required this.userId,
    required this.monthlyLimitMinorUnits,
    required this.updatedAt,
  });

  final String userId;
  final int monthlyLimitMinorUnits;
  final DateTime? updatedAt;

  Map<String, dynamic> toFirestore({required String authenticatedUserId}) {
    return {
      'userId': authenticatedUserId,
      'monthlyLimitMinorUnits': monthlyLimitMinorUnits,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  factory MonthlyBudget.fromFirestore(
    Map<String, dynamic> data, {
    required String userId,
  }) {
    return MonthlyBudget(
      userId: userId,
      monthlyLimitMinorUnits: (data['monthlyLimitMinorUnits'] as num?)?.toInt() ?? 0,
      updatedAt: _dateFromFirestore(data['updatedAt']),
    );
  }

  static DateTime? _dateFromFirestore(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }
}
