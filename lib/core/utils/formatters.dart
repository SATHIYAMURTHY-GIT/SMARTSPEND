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

/// Centralized category-to-color mapping ensuring permanent, consistent colors everywhere.
const Map<String, Color> kCategoryColors = <String, Color>{
  'food': Color(0xFF8E24AA), // Purple
  'dining': Color(0xFF8E24AA), // Purple
  'groceries': Color(0xFF8E24AA), // Purple
  'grocery': Color(0xFF8E24AA), // Purple
  'restaurant': Color(0xFF8E24AA), // Purple
  'cafe': Color(0xFF8E24AA), // Purple
  'transport': Color(0xFF1E88E5), // Blue
  'transportation': Color(0xFF1E88E5), // Blue
  'fuel': Color(0xFF1E88E5), // Blue
  'petrol': Color(0xFF1E88E5), // Blue
  'gas': Color(0xFF1E88E5), // Blue
  'taxi': Color(0xFF1E88E5), // Blue
  'cab': Color(0xFF1E88E5), // Blue
  'commute': Color(0xFF1E88E5), // Blue
  'shopping': Color(0xFFFB8C00), // Orange
  'retail': Color(0xFFFB8C00), // Orange
  'clothing': Color(0xFFFB8C00), // Orange
  'electronics': Color(0xFFFB8C00), // Orange
  'market': Color(0xFFFB8C00), // Orange
  'bills': Color(0xFF43A047), // Green
  'bill': Color(0xFF43A047), // Green
  'utilities': Color(0xFF43A047), // Green
  'utility': Color(0xFF43A047), // Green
  'electricity': Color(0xFF43A047), // Green
  'water': Color(0xFF43A047), // Green
  'rent': Color(0xFF43A047), // Green
  'recharge': Color(0xFF43A047), // Green
  'education': Color(0xFFE53935), // Red
  'books': Color(0xFFE53935), // Red
  'course': Color(0xFFE53935), // Red
  'tuition': Color(0xFFE53935), // Red
  'school': Color(0xFFE53935), // Red
  'college': Color(0xFFE53935), // Red
  'entertainment': Color(0xFFFDD835), // Yellow
  'movies': Color(0xFFFDD835), // Yellow
  'games': Color(0xFFFDD835), // Yellow
  'leisure': Color(0xFFFDD835), // Yellow
  'party': Color(0xFFFDD835), // Yellow
  'healthcare': Color(0xFFE91E63), // Pink
  'health': Color(0xFFE91E63), // Pink
  'medical': Color(0xFFE91E63), // Pink
  'medicine': Color(0xFFE91E63), // Pink
  'doctor': Color(0xFFE91E63), // Pink
  'hospital': Color(0xFFE91E63), // Pink
  'pharmacy': Color(0xFFE91E63), // Pink
  'travel': Color(0xFF00897B), // Teal
  'vacation': Color(0xFF00897B), // Teal
  'flight': Color(0xFF00897B), // Teal
  'hotel': Color(0xFF00897B), // Teal
  'trip': Color(0xFF00897B), // Teal
  'tourism': Color(0xFF00897B), // Teal
  'subscriptions': Color(0xFF3949AB), // Indigo
  'subscription': Color(0xFF3949AB), // Indigo
  'ott': Color(0xFF3949AB), // Indigo
  'streaming': Color(0xFF3949AB), // Indigo
  'membership': Color(0xFF3949AB), // Indigo
  'other': Color(0xFF757575), // Grey
  'others': Color(0xFF757575), // Grey
  'general': Color(0xFF757575), // Grey
  'misc': Color(0xFF757575), // Grey
  'miscellaneous': Color(0xFF757575), // Grey
};

const List<Color> kFallbackCategoryColors = <Color>[
  Color(0xFF8E24AA), // Purple
  Color(0xFF1E88E5), // Blue
  Color(0xFFFB8C00), // Orange
  Color(0xFF43A047), // Green
  Color(0xFFE53935), // Red
  Color(0xFFFDD835), // Yellow
  Color(0xFFE91E63), // Pink
  Color(0xFF00897B), // Teal
  Color(0xFF3949AB), // Indigo
  Color(0xFF6D4C41), // Brown
  Color(0xFF00ACC1), // Cyan
  Color(0xFFD81B60), // Deep Pink
  Color(0xFF5E35B1), // Deep Purple
  Color(0xFF7CB342), // Light Green
  Color(0xFF757575), // Grey
];

Color categoryColorForKey(
  String? value, {
  List<Color>? palette,
}) {
  final normalized = normalizeCategoryKey(value);
  if (normalized.isEmpty) {
    return const Color(0xFF757575); // Grey
  }

  // 1. Direct centralized dictionary match
  if (kCategoryColors.containsKey(normalized)) {
    return kCategoryColors[normalized]!;
  }

  // 2. Keyword/substring match against known categories
  for (final entry in kCategoryColors.entries) {
    if (normalized.contains(entry.key) || entry.key.contains(normalized)) {
      return entry.value;
    }
  }

  // 3. Deterministic hash fallback for unmapped custom categories
  final resolvedPalette = palette ?? kFallbackCategoryColors;
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