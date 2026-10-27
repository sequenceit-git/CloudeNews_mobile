import 'package:tuikit_atomic_x/album_picker/album_picker.dart';

typedef ImagePickerModel = AlbumMedia;
typedef ImagePickerConfig = AlbumPickerConfig;

class ImagePicker {
  static Future<void> pickImages({
    ImagePickerConfig? config,
    AlbumPickerTheme? theme,
    Function(List<AlbumMedia> pickedAlbumMedias, String? textMessage)?
        onPickConfirm,
    Function(AlbumMedia albumMedia, double progress, bool error)?
        onMediaProcessing,
    Function()? onMediaProcessed,
    Function()? onCancel,
  }) async {
    final effectiveConfig = AlbumPickerConfig(
      mediaFilter: config?.mediaFilter ?? AlbumPickerMediaFilter.imageOnly,
      maxSelectionCount: config?.maxSelectionCount,
      itemsPerRow: config?.itemsPerRow,
      showsCameraItem: config?.showsCameraItem ?? false,
      style: config?.style ?? AlbumPickerStyle.likeWeChat,
      language: config?.language,
      compressQuality: config?.compressQuality,
      maxVideoDurationInSeconds: config?.maxVideoDurationInSeconds,
      maxOutputFileSizeInMB: config?.maxOutputFileSizeInMB,
    );
    return AlbumPicker.pickMedia(
      config: effectiveConfig,
      theme: theme,
      onPickConfirm: onPickConfirm,
      onMediaProcessing: onMediaProcessing,
      onMediaProcessed: onMediaProcessed,
      onCancel: onCancel,
    );
  }
}
