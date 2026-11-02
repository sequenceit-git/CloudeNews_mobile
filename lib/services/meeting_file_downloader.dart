import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

class MeetingFileDownloader {
  MeetingFileDownloader._();

  static final MeetingFileDownloader instance = MeetingFileDownloader._();

  /// Gets the appropriate storage directory for downloads.
  /// On Android, prefers the standard user-visible `/storage/emulated/0/Download`.
  /// On iOS, uses application documents directory.
  Future<Directory> getDownloadDirectory() async {
    if (Platform.isAndroid) {
      try {
        final publicDownloadDir = Directory('/storage/emulated/0/Download');
        if (await publicDownloadDir.exists()) {
          return publicDownloadDir;
        }
      } catch (_) {}

      try {
        final extDirs = await getExternalStorageDirectories(type: StorageDirectory.downloads);
        if (extDirs != null && extDirs.isNotEmpty) {
          return extDirs.first;
        }
      } catch (_) {}
    }

    return await getApplicationDocumentsDirectory();
  }

  /// Resolves the full target file path for a given filename.
  Future<String> resolveLocalPath(String filename) async {
    final cleanName = filename.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
    final name = cleanName.isEmpty ? 'meeting_file_${DateTime.now().millisecondsSinceEpoch}' : cleanName;
    final dir = await getDownloadDirectory();
    return '${dir.path}/$name';
  }

  /// Checks if the file is already downloaded and present on disk.
  bool isFileDownloaded(String localPath) {
    if (localPath.isEmpty) return false;
    final file = File(localPath);
    return file.existsSync() && file.lengthSync() > 0;
  }

  /// Downloads a file from [url] to [localPath] with progress notifications.
  Future<File> downloadFile({
    required String url,
    required String localPath,
    void Function(double progress)? onProgress,
  }) async {
    final uri = Uri.parse(url);
    final request = http.Request('GET', uri);
    final response = await request.send();

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException('Failed to download file (${response.statusCode})', uri: uri);
    }

    final totalBytes = response.contentLength ?? 0;
    int receivedBytes = 0;

    final file = File(localPath);
    final sink = file.openWrite();

    try {
      await response.stream.listen(
        (chunk) {
          sink.add(chunk);
          receivedBytes += chunk.length;
          if (totalBytes > 0 && onProgress != null) {
            final progress = (receivedBytes / totalBytes).clamp(0.0, 1.0);
            onProgress(progress);
          }
        },
      ).asFuture();
      await sink.flush();
    } catch (e) {
      try {
        if (await file.exists()) await file.delete();
      } catch (_) {}
      rethrow;
    } finally {
      await sink.close();
    }

    return file;
  }

  /// Opens the downloaded file in the native system viewer or file manager.
  Future<OpenResult> openFile(String localPath) async {
    try {
      return await OpenFilex.open(localPath);
    } catch (e) {
      debugPrint('[MeetingFileDownloader] Failed to open file: $e');
      return OpenResult(type: ResultType.error, message: e.toString());
    }
  }
}

