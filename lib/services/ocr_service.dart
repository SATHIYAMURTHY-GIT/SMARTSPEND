import 'dart:io';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

class OcrItem {
  const OcrItem({required this.name, this.quantity, this.price});

  final String name;
  final String? quantity;
  final String? price;

  bool get hasDetails => name.trim().isNotEmpty || quantity != null || price != null;
}

class OcrExtractionResult {
  const OcrExtractionResult({
    this.merchant,
    this.amountInMinorUnits,
    this.date,
    this.items = const <OcrItem>[],
    this.rawText = '',
  });

  final String? merchant;
  final int? amountInMinorUnits;
  final DateTime? date;
  final List<OcrItem> items;
  final String rawText;

  bool get hasSuggestions =>
      (merchant != null && merchant!.trim().isNotEmpty) ||
      amountInMinorUnits != null ||
      date != null ||
      items.isNotEmpty;
}

class OcrException implements Exception {
  const OcrException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ReceiptOcrService {
  ReceiptOcrService({TextRecognizer? recognizer})
      : _recognizer = recognizer ?? TextRecognizer(script: TextRecognitionScript.latin);

  final TextRecognizer _recognizer;
  final Map<String, OcrExtractionResult> _cache = <String, OcrExtractionResult>{};

  Future<OcrExtractionResult> extractFromImage(XFile file) async {
    final cacheKey = file.path;
    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey]!;
    }

    final imageFile = File(file.path);
    if (!await imageFile.exists()) {
      throw const OcrException('The selected receipt image is no longer available.');
    }

    try {
      final inputImage = InputImage.fromFilePath(file.path);
      final recognizedText = await _recognizer.processImage(inputImage);
      final result = parseRecognizedText(recognizedText.text);
      _cache[cacheKey] = result;
      return result;
    } on Exception {
      throw const OcrException('We could not read the receipt image. You can try a clearer photo or enter the details manually.');
    }
  }

  OcrExtractionResult parseRecognizedText(String rawText) {
    final normalized = rawText.replaceAll('\r', '').trim();
    if (normalized.isEmpty) {
      return const OcrExtractionResult();
    }

    final lines = normalized
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();

    return OcrExtractionResult(
      merchant: _detectMerchant(lines),
      amountInMinorUnits: _detectAmount(lines),
      date: _detectDate(lines),
      items: _detectItems(lines),
      rawText: normalized,
    );
  }

  static String? _detectMerchant(List<String> lines) {
    final candidates = <String>[];
    for (final line in lines.take(8)) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      if (!RegExp(r'[A-Za-z]').hasMatch(trimmed)) continue;
      if (_looksLikeNonsensicalLine(trimmed)) continue;
      candidates.add(trimmed);
    }

    for (final candidate in candidates) {
      final match = candidate.toLowerCase();
      if (match.contains('receipt') ||
          match.contains('invoice') ||
          match.contains('tax') ||
          match.contains('total') ||
          match.contains('amount') ||
          match.contains('thank you') ||
          match.contains('welcome')) {
        continue;
      }
      return candidate;
    }

    return candidates.firstOrNull;
  }

  static bool _looksLikeNonsensicalLine(String line) {
    final lower = line.toLowerCase();
    if (lower.contains('total') ||
        lower.contains('subtotal') ||
        lower.contains('tax') ||
        lower.contains('gst') ||
        lower.contains('cash') ||
        lower.contains('card') ||
        lower.contains('change') ||
        lower.contains('balance') ||
        lower.contains('discount') ||
        lower.contains('qty') ||
        lower.contains('amount')) {
      return true;
    }

    final numericCount = RegExp(r'\d').allMatches(line).length;
    return numericCount > line.length ~/ 5;
  }

  static int? _detectAmount(List<String> lines) {
    for (final line in lines) {
      final formatted = _extractAmountFromLine(line);
      if (formatted != null) return formatted;
    }
    return null;
  }

  static int? _extractAmountFromLine(String line) {
    final lower = line.toLowerCase();
    final isTotalContext = RegExp(r'(total|amount|net|due|payable|balance|grand total|bill|amt)').hasMatch(lower);
    final containsCurrency = RegExp(r'(₹|rs|inr|rupees)').hasMatch(lower);
    if (!isTotalContext && !containsCurrency) {
      return null;
    }

    final candidates = <String>[];
    final amountMatches = RegExp(
      r'(?:₹|rs\.?|inr|rupees?)\s*([0-9][0-9,\.\s]*)|([0-9][0-9,\.\s]*)\s*(?:₹|rs\.?|inr|rupees?)',
      caseSensitive: false,
    ).allMatches(line);
    for (final match in amountMatches) {
      final candidate = (match.group(1) ?? match.group(2) ?? '').trim();
      if (candidate.isNotEmpty) {
        candidates.add(candidate);
      }
    }

    if (candidates.isEmpty) {
      final fallback = RegExp(r'\b\d{1,3}(?:[.,]\d{1,2})?\b').firstMatch(line);
      if (fallback != null && (isTotalContext || lower.contains('₹') || lower.contains('rs'))) {
        candidates.add(fallback.group(0)!);
      }
    }

    for (final candidate in candidates) {
      final parsed = _parseMoneyValue(candidate);
      if (parsed != null) return parsed;
    }

    return null;
  }

  static int? _parseMoneyValue(String value) {
    final normalized = value
        .replaceAll(RegExp(r'[^0-9.]'), '')
        .trim();
    if (normalized.isEmpty) return null;

    final parsed = double.tryParse(normalized);
    if (parsed == null) return null;

    final minorUnits = (parsed * 100).round();
    if (minorUnits <= 0) return null;
    return minorUnits;
  }

  static DateTime? _detectDate(List<String> lines) {
    final patterns = [
      DateFormat('dd/MM/yyyy'),
      DateFormat('d/M/yyyy'),
      DateFormat('dd-MM-yyyy'),
      DateFormat('d-M-yyyy'),
      DateFormat('yyyy-MM-dd'),
      DateFormat('dd/MM/yy'),
      DateFormat('d/M/yy'),
      DateFormat('dd MMM yyyy'),
      DateFormat('d MMM yyyy'),
      DateFormat('dd MMMM yyyy'),
      DateFormat('d MMMM yyyy'),
      DateFormat('MMM d, yyyy'),
      DateFormat('MMMM d, yyyy'),
    ];

    for (final line in lines) {
      final candidate = _firstDateCandidate(line);
      if (candidate == null) continue;
      for (final format in patterns) {
        try {
          final parsed = format.parseStrict(candidate);
          return _dayOnly(parsed);
        } catch (_) {
          // Ignore and continue trying other patterns.
        }
      }
    }

    return null;
  }

  static String? _firstDateCandidate(String line) {
    final dateMatches = RegExp(
      r'\b(?:\d{1,2}[/-]\d{1,2}[/-]\d{2,4}|\d{4}[/-]\d{1,2}[/-]\d{1,2}|\d{1,2}\s+[A-Za-z]{3,9}\s+\d{2,4}|[A-Za-z]{3,9}\s+\d{1,2},\s*\d{2,4})\b',
    ).allMatches(line);

    for (final match in dateMatches) {
      final candidate = match.group(0)?.trim();
      if (candidate != null && candidate.isNotEmpty) {
        return candidate.replaceAll(RegExp(r'\s+'), ' ');
      }
    }
    return null;
  }

  static DateTime _dayOnly(DateTime date) => DateTime(date.year, date.month, date.day);

  static List<OcrItem> _detectItems(List<String> lines) {
    final items = <OcrItem>[];

    for (final line in lines) {
      final lower = line.toLowerCase();
      if (lower.contains('total') ||
          lower.contains('subtotal') ||
          lower.contains('tax') ||
          lower.contains('gst') ||
          lower.contains('discount') ||
          lower.contains('cash') ||
          lower.contains('card') ||
          lower.contains('balance') ||
          lower.contains('change') ||
          lower.contains('receipt') ||
          lower.contains('invoice')) {
        continue;
      }

      final priceMatch = RegExp(
        r'(?:₹|rs\.?|inr|rupees?)\s*([0-9][0-9,\.\s]*)\s*$|([0-9][0-9,\.\s]*)\s*(?:₹|rs\.?|inr|rupees?)\s*$',
        caseSensitive: false,
      ).firstMatch(line);
      if (priceMatch == null) continue;

      final rawName = line.substring(0, (priceMatch.start)).trim();
      final name = rawName.replaceAll(RegExp(r'\s+'), ' ');
      if (name.isEmpty || name.length < 2) continue;

      final quantityMatch = RegExp(r'(?:(\d+)\s*[xX]\s*)|(?:qty\s*(\d+))').firstMatch(line);
      final rawPrice = (priceMatch.group(1) ?? priceMatch.group(2) ?? '').trim();
      final price = rawPrice.isEmpty ? null : rawPrice;
      final quantity = quantityMatch == null ? null : (quantityMatch.group(1) ?? quantityMatch.group(2));

      items.add(
        OcrItem(
          name: name,
          quantity: quantity,
          price: price,
        ),
      );
    }

    return items;
  }
}

extension _ListFirstOrNull<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
