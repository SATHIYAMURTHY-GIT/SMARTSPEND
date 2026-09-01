import 'package:cloud_firestore/cloud_firestore.dart';

enum ExpenseType { debit, credit }

class Expense {
  const Expense({
    required this.id,
    required this.userId,
    required this.amount,
    required this.type,
    required this.category,
    required this.merchant,
    required this.description,
    required this.date,
    required this.paymentMethod,
    required this.receiptUrl,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String userId;

  /// The monetary amount in the currency's minor unit, such as cents.
  final int amount;
  final ExpenseType type;
  final String? category;
  final String? merchant;
  final String? description;
  final DateTime? date;
  final String? paymentMethod;
  final String? receiptUrl;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Map<String, dynamic> toFirestore({required String authenticatedUserId}) {
    return {
      'userId': authenticatedUserId,
      'amount': amount,
      'type': type.name,
      'category': category,
      'merchant': merchant,
      'description': description,
      'date': date == null ? null : Timestamp.fromDate(date!),
      'paymentMethod': paymentMethod,
      'receiptUrl': receiptUrl,
    };
  }

  factory Expense.fromFirestore(
    String documentId,
    Map<String, dynamic> data,
  ) {
    final typeValue = data['type'] as String?;
    final type = ExpenseType.values.firstWhere(
      (value) => value.name == typeValue,
      orElse: () => ExpenseType.debit,
    );

    return Expense(
      id: documentId,
      userId: data['userId'] as String? ?? '',
      amount: (data['amount'] as num?)?.toInt() ?? 0,
      type: type,
      category: data['category'] as String?,
      merchant: data['merchant'] as String?,
      description: data['description'] as String?,
      date: _dateFromFirestore(data['date']),
      paymentMethod: data['paymentMethod'] as String?,
      receiptUrl: data['receiptUrl'] as String?,
      createdAt: _dateFromFirestore(data['createdAt']),
      updatedAt: _dateFromFirestore(data['updatedAt']),
    );
  }

  static DateTime? _dateFromFirestore(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }
}