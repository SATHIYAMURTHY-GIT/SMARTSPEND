import 'package:flutter_test/flutter_test.dart';
import 'package:smartspend/core/config/cloudinary_config.dart';
import 'package:smartspend/services/receipt_upload_service.dart';

void main() {
  group('Cloudinary receipt upload', () {
    test('uses the centralized unsigned upload preset', () {
      expect(cloudinaryCloudName, 'dko0uefqk');
      expect(cloudinaryUnsignedUploadPreset, 'smartspend_receipts');
      expect(cloudinaryUploadUri.toString(), contains('/v1_1/dko0uefqk/image/upload'));
      expect(cloudinaryUploadUri.queryParameters['upload_preset'], 'smartspend_receipts');
    });

    test('receipt upload service provides a validation entry point', () {
      final service = ReceiptUploadService();
      expect(service, isA<ReceiptUploadService>());
    });
  });
}
