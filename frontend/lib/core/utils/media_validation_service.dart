import 'package:file_picker/file_picker.dart';

class MediaValidationService {
  static const int maxVideoBytes = 25 * 1024 * 1024; // 25MB
  static const int maxImageBytes = 10 * 1024 * 1024; // 10MB

  static const List<String> allowedVideoExtensions = ['mp4', 'mov', 'webm'];
  static const List<String> allowedImageExtensions = ['jpg', 'jpeg', 'png', 'webp'];

  /// Validates a file based on its extension and size.
  /// Returns a null String if valid, otherwise returns an error message.
  static String? validateFile(PlatformFile file) {
    final extension = file.extension?.toLowerCase();
    
    if (extension == null) {
      return 'Unknown file type';
    }

    if (allowedVideoExtensions.contains(extension)) {
      if (file.size > maxVideoBytes) {
        return 'Video is too large. Max limit is 25MB.';
      }
      return null;
    }

    if (allowedImageExtensions.contains(extension)) {
      if (file.size > maxImageBytes) {
        return 'Image is too large. Max limit is 10MB.';
      }
      return null;
    }

    return 'Invalid file type. Allowed: ${[...allowedImageExtensions, ...allowedVideoExtensions].join(", ")}';
  }

  /// Helper to check if a file is an image
  static bool isImage(String? extension) {
    return allowedImageExtensions.contains(extension?.toLowerCase());
  }

  /// Helper to check if a file is a video
  static bool isVideo(String? extension) {
    return allowedVideoExtensions.contains(extension?.toLowerCase());
  }
}
