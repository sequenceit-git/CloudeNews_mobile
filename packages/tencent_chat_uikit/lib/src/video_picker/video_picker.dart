import 'package:tuikit_atomic_x/album_picker/album_picker.dart';

typedef VideoPickerModel = AlbumMedia;
typedef VideoPickerConfig = AlbumPickerConfig;

class VideoPicker {
  static Future<void> pickVideos({
    VideoPickerConfig? config,
    AlbumPickerTheme? theme,
    Function(List<AlbumMedia> pickedAlbumMedias, String? textMessage)?
        onPickConfirm,
    Function(AlbumMedia albumMedia, double progress, bool error)?
        onMediaProcessing,
    Function()? onMediaProcessed,
    Function()? onCancel,
  }) async {
    return AlbumPicker.pickMedia(
      config: config,
      theme: theme,
      onPickConfirm: onPickConfirm,
      onMediaProcessing: onMediaProcessing,
      onMediaProcessed: onMediaProcessed,
      onCancel: onCancel,
    );
  }
}
