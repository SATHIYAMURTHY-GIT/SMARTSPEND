import 'package:flutter/material.dart';

String formatCurrency(double amount) => '₹${amount.toStringAsFixed(2)}';

String normalizeCategoryName(String? value) {
  final cleaned = value == null ? '' : value.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (cleaned.isEmpty) return '';

  final words = cleaned.toLowerCase().split(' ');
  return words
      .map((word) => word.isEmpty ? '' : word[0].toUpperCase() + word.substring(1))
      .join(' ');
}

String normalizeCategoryKey(String? value) => normalizeCategoryName(value).toLowerCase();

List<String> deriveAvailableCategories(Iterable<String?> categories) {
  final normalized = <String>{};
  for (final category in categories) {
    final cleaned = normalizeCategoryName(category);
    if (cleaned.isEmpty) continue;
    normalized.add(cleaned);
  }

  final list = normalized.toList()..sort();
  return list;
}

String resolveCategorySelection(String? input, List<String> existingCategories) {
  final trimmed = input == null ? '' : input.trim();
  final normalizedInput = normalizeCategoryKey(trimmed);
  if (normalizedInput.isEmpty) return '';

  for (final category in existingCategories) {
    if (normalizeCategoryKey(category) == normalizedInput) {
      return normalizeCategoryName(category);
    }
  }

  return normalizeCategoryName(trimmed);
}

Color categoryColorForKey(
  String? value, {
  List<Color>? palette,
}) {
  const defaultPalette = <Color>[
    Color(0xFF5E2BBF),
    Color(0xFF7B61FF),
    Color(0xFF2BB7A4),
    Color(0xFF1C9BD6),
    Color(0xFFEF6C57),
    Color(0xFFF4A261),
    Color(0xFF7AC74F),
    Color(0xFF9C6ADE),
    Color(0xFF4DB6AC),
    Color(0xFFF06292),
  ];

  final resolvedPalette = palette ?? defaultPalette;
  final normalized = normalizeCategoryKey(value);
  if (normalized.isEmpty) {
    return resolvedPalette.first;
  }

  var hash = 2166136261;
  for (final codeUnit in normalized.codeUnits) {
    hash ^= codeUnit;
    hash *= 16777619;
  }

  final index = (hash.abs() % resolvedPalette.length);
  return resolvedPalette[index];
}

String formatMinorUnits(int amount) {
  final absoluteAmount = amount.abs();
  final wholeUnits = absoluteAmount ~/ 100;
  final minorUnits = (absoluteAmount % 100).toString().padLeft(2, '0');
  return '₹$wholeUnits.$minorUnits';
}