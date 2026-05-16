import 'package:image_picker/image_picker.dart';

/// Testable seam over the `image_picker` plugin (ROADMAP B.5).
///
/// Callers (`ImageUploadHelper` and friends) depend on this interface rather
/// than the concrete `ImagePicker`, so a unit test can supply a fake without
/// a live platform channel. [ImageSource] is a plain enum from the plugin and
/// is re-used as-is — only the channel-backed `pickImage` call needs wrapping.
abstract class ImagePickerFacade {
  /// Opens the gallery/camera and returns the picked file path, or `null`
  /// when the user cancels.
  Future<String?> pickImagePath({
    required ImageSource source,
    double? maxWidth,
    int? imageQuality,
  });
}

/// Production implementation — delegates to the real `image_picker` plugin.
class SystemImagePickerFacade implements ImagePickerFacade {
  SystemImagePickerFacade({ImagePicker? picker})
      : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  @override
  Future<String?> pickImagePath({
    required ImageSource source,
    double? maxWidth,
    int? imageQuality,
  }) async {
    final picked = await _picker.pickImage(
      source: source,
      maxWidth: maxWidth,
      imageQuality: imageQuality,
    );
    return picked?.path;
  }
}
