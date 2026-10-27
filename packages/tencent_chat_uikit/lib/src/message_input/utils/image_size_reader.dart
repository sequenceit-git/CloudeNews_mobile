import 'dart:io';
import 'dart:ui' as ui;

/// Raw pixel dimensions of an image.
class ImageSize {
  final int width;
  final int height;
  const ImageSize(this.width, this.height);
}

/// Decodes a local image file and returns its width / height in pixels.
///
/// Used by the message-input send pipeline to populate
/// [ImageMessagePayload.originalImageWidth] / `originalImageHeight` BEFORE the
/// message is dispatched, so the in-flight (sending) bubble in `MessageList`
/// renders with the correct aspect ratio instead of falling back to a
/// 1:1 square placeholder.
class ImageSizeReader {
  static Future<ImageSize?> read(String filePath) async {
    if (filePath.isEmpty) return null;
    try {
      final bytes = await File(filePath).readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;
      final size = ImageSize(image.width, image.height);
      image.dispose();
      codec.dispose();
      return size;
    } catch (_) {
      return null;
    }
  }
}
