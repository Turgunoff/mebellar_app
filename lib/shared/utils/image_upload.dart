import 'dart:io';

import 'package:image_picker/image_picker.dart';

/// Format/size guards we apply *before* trying to upload to storage. Backend
/// may also reject (S3 policy + file type validator), but we want a fast
/// client-side error before consuming the user's bandwidth.
class ImagePickConfig {
  static const Set<String> allowedExtensions = {
    'jpg', 'jpeg', 'png', 'webp',
  };
  static const int maxBytes = 10 * 1024 * 1024; // 10 MB
  static const double maxWidth = 2048;
  static const int quality = 85;
}

/// Result of [PickedImage] — exposes the local file plus a friendly extension
/// so the upload service can pass it onward to Supabase Storage.
class PickedImage {
  const PickedImage({
    required this.file,
    required this.extension,
    required this.bytes,
  });

  final File file;
  final String extension;
  final int bytes;
}

class ImagePickError implements Exception {
  ImagePickError(this.code, this.message);
  final String code;
  final String message;

  @override
  String toString() => 'ImagePickError($code): $message';
}

class ImageUploadHelper {
  ImageUploadHelper({ImagePicker? picker}) : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  /// Picks an image from the gallery (`source: gallery`) or camera, applies
  /// resize/quality limits via image_picker, and validates extension + size.
  /// Throws [ImagePickError] when validation fails so callers can surface a
  /// localised message.
  Future<PickedImage?> pick({required ImageSource source}) async {
    final picked = await _picker.pickImage(
      source: source,
      maxWidth: ImagePickConfig.maxWidth,
      imageQuality: ImagePickConfig.quality,
    );
    if (picked == null) return null;

    final ext = _extensionOf(picked.path).toLowerCase();
    if (!ImagePickConfig.allowedExtensions.contains(ext)) {
      throw ImagePickError(
        'invalid_format',
        'JPEG, PNG yoki WEBP formatidagi rasm tanlang',
      );
    }
    final file = File(picked.path);
    final bytes = await file.length();
    if (bytes > ImagePickConfig.maxBytes) {
      throw ImagePickError(
        'too_large',
        'Rasm hajmi 10 MB dan oshmasligi kerak',
      );
    }
    return PickedImage(file: file, extension: ext, bytes: bytes);
  }

  String _extensionOf(String path) {
    final dot = path.lastIndexOf('.');
    if (dot < 0 || dot == path.length - 1) return '';
    return path.substring(dot + 1);
  }
}
