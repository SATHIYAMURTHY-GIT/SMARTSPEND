import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../services/ocr_service.dart';

final receiptOcrServiceProvider = Provider<ReceiptOcrService>((ref) {
  return ReceiptOcrService();
});

final ocrExtractionProvider = FutureProvider.family<OcrExtractionResult, XFile>((ref, file) {
  final service = ref.watch(receiptOcrServiceProvider);
  return service.extractFromImage(file);
});
