import 'image_picker_stub.dart'
    if (dart.library.html) 'image_picker_web.dart' as impl;

/// Prompts the user to pick an image file and returns its data URL (data:image/...;base64,...).
Future<String?> pickProductImageAsDataUrl() {
  return impl.pickProductImageAsDataUrl();
}
