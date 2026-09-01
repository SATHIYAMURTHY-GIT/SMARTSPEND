import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

import '../core/config/cloudinary_config.dart';

class ReceiptUploadException implements Exception {
  const ReceiptUploadException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ReceiptUploadService {
  ReceiptUploadService({http.Client? client, ImagePicker? imagePicker})
      : _httpClient = client ?? http.Client(),
        _imagePicker = imagePicker ?? ImagePicker();

  final http.Client _httpClient;
  final ImagePicker _imagePicker;

  Future<XFile?> pickReceiptImage({required ImageSource source}) async {
    try {
      final pickedFile = await _imagePicker.pickImage(
        source: source,
        preferredCameraDevice: CameraDevice.rear,
        imageQuality: 85,
      );
      if (pickedFile == null) return null;

      final extension = pickedFile.name.split('.').last.toLowerCase();
      const allowedExtensions = {
        'jpg',
        'jpeg',
        'png',
        'webp',
        'bmp',
        'heic',
        'heif',
      };
      if (!allowedExtensions.contains(extension)) {
        throw const ReceiptUploadException(
          'Only common image formats are supported for receipts.',
        );
      }

      return pickedFile;
    } on PlatformException {
      return null;
    } on ReceiptUploadException {
      rethrow;
    } catch (_) {
      return null;
    }
  }

  Future<String> uploadReceiptFile(XFile file) async {
    final imageFile = File(file.path);
    if (!await imageFile.exists()) {
      throw const ReceiptUploadException('The selected receipt is no longer available.');
    }

    final fileName = file.name.isNotEmpty ? file.name : 'receipt.jpg';
    final extension = fileName.split('.').last.toLowerCase();
    const allowedExtensions = {'jpg', 'jpeg', 'png', 'webp', 'bmp', 'heic', 'heif'};
    if (!allowedExtensions.contains(extension)) {
      throw const ReceiptUploadException('Only image files can be uploaded as receipts.');
    }

    final bytes = await imageFile.readAsBytes();
    final preparedBytes = await _prepareImageForUpload(bytes);

    final request = http.MultipartRequest('POST', cloudinaryUploadUri)
      ..files.add(
        http.MultipartFile.fromBytes(
          'file',
          preparedBytes,
          filename: fileName,
        ),
      );

    final response = await _httpClient
        .send(request)
        .timeout(const Duration(seconds: 30));
    final responseBody = await response.stream.bytesToString();

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ReceiptUploadException(
        'Receipt upload failed (${response.statusCode}). Please try again.',
      );
    }

    final decodedBody = jsonDecode(responseBody);
    if (decodedBody is! Map<String, dynamic>) {
      throw const ReceiptUploadException(
        'Receipt upload returned an invalid response.',
      );
    }

    final secureUrl = decodedBody['secure_url'] as String? ?? decodedBody['url'] as String?;
    if (secureUrl == null || secureUrl.trim().isEmpty) {
      throw const ReceiptUploadException(
        'Receipt upload did not return a valid secure URL.',
      );
    }

    return secureUrl;
  }

  Future<Uint8List> _prepareImageForUpload(Uint8List bytes) async {
    try {
      final decodedImage = img.decodeImage(bytes);
      if (decodedImage == null) return bytes;

      final shouldResize = decodedImage.width > 1800 || decodedImage.height > 1800;
      final resizedImage = shouldResize
          ? img.copyResize(
              decodedImage,
              width: decodedImage.width > decodedImage.height ? 1800 : null,
              height: decodedImage.height > decodedImage.width ? 1800 : null,
              maintainAspect: true,
            )
          : decodedImage;

      final encodedImage = img.encodeJpg(resizedImage, quality: 82);
      return encodedImage.lengthInBytes < bytes.lengthInBytes ? encodedImage : bytes;
    } catch (_) {
      return bytes;
    }
  }
}
