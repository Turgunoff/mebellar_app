import 'dart:io';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/platform/image_picker_facade.dart';

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
/// so the upload service can pass it onward to R2 storage.
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
  /// [picker] defaults to the real plugin-backed facade; a test injects a
  /// fake [ImagePickerFacade] so the pick/validate logic runs without a
  /// platform channel (ROADMAP B.5).
  ImageUploadHelper({ImagePickerFacade? picker})
      : _picker = picker ?? SystemImagePickerFacade();

  final ImagePickerFacade _picker;

  /// Picks an image from the gallery (`source: gallery`) or camera, applies
  /// resize/quality limits via image_picker, and validates extension + size.
  /// Throws [ImagePickError] when validation fails so callers can surface a
  /// localised message.
  Future<PickedImage?> pick({required ImageSource source}) async {
    final path = await _picker.pickImagePath(
      source: source,
      maxWidth: ImagePickConfig.maxWidth,
      imageQuality: ImagePickConfig.quality,
    );
    if (path == null) return null;

    final ext = _extensionOf(path).toLowerCase();
    if (!ImagePickConfig.allowedExtensions.contains(ext)) {
      throw ImagePickError(
        'invalid_format',
        'JPEG, PNG yoki WEBP formatidagi rasm tanlang',
      );
    }
    final file = File(path);
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

/// Subfolder under app Documents for mid-flow onboarding KYC images.
const kOnboardingKycDirName = 'onboarding_kyc';

Future<Directory> _onboardingKycDir() async {
  final docs = await getApplicationDocumentsDirectory();
  final dir = Directory('${docs.path}/$kOnboardingKycDirName');
  if (!await dir.exists()) {
    await dir.create(recursive: true);
  }
  return dir;
}

/// Compress a gallery/camera pick to WebP and store it under app Documents.
///
/// Encode runs at pick-time (not contract accept). The file is written to a
/// stable Documents path (`onboarding_kyc/{documentId}.webp`) so Hive can
/// persist the path and the wizard can restore after an app kill — unlike
/// [getTemporaryDirectory], which the OS may clear.
Future<String> compressAndPersistOnboardingKycImage({
  required String sourcePath,
  required String documentId,
}) async {
  final compressed = await FlutterImageCompress.compressWithFile(
    File(sourcePath).absolute.path,
    format: CompressFormat.webp,
    quality: 88,
    keepExif: false,
    minWidth: 1600,
    minHeight: 1600,
  );
  if (compressed == null) {
    throw StateError('image_compress_failed');
  }
  final dir = await _onboardingKycDir();
  final out = File('${dir.path}/$documentId.webp');
  await out.writeAsBytes(compressed, flush: true);
  return out.path;
}

/// Drop one persisted KYC image (user removed the card).
Future<void> deletePersistedOnboardingKycImage(String documentId) async {
  final docs = await getApplicationDocumentsDirectory();
  final file = File('${docs.path}/$kOnboardingKycDirName/$documentId.webp');
  if (await file.exists()) {
    await file.delete();
  }
}

/// Wipe the whole onboarding KYC folder after successful submit / reset.
Future<void> clearPersistedOnboardingKycImages() async {
  final docs = await getApplicationDocumentsDirectory();
  final dir = Directory('${docs.path}/$kOnboardingKycDirName');
  if (await dir.exists()) {
    await dir.delete(recursive: true);
  }
}

/// Keep only paths whose files still exist on disk.
Map<String, String> existingOnboardingKycPaths(Map<String, String> paths) {
  return {
    for (final e in paths.entries)
      if (File(e.value).existsSync()) e.key: e.value,
  };
}
