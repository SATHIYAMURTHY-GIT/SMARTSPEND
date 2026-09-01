import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/receipt_upload_service.dart';

final receiptUploadServiceProvider = Provider<ReceiptUploadService>((ref) {
  return ReceiptUploadService();
});
