import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class MeetingBackgroundService {
  MeetingBackgroundService._();

  static const _channel = MethodChannel('com.cloudnews.app/meeting_service');

  /// Starts the native foreground service so Android OS does not mute
  /// or terminate the microphone when the app is in the background.
  static Future<void> start({
    required String meetingCode,
    bool isScreenSharing = false,
  }) async {
    if (!Platform.isAndroid) return;
    try {
      final title = 'CloudNews Meeting: $meetingCode';
      final body = isScreenSharing
          ? 'Screen sharing and audio active in background'
          : 'Meeting audio active in background';
      await _channel.invokeMethod('startService', {
        'title': title,
        'body': body,
        'isScreenSharing': isScreenSharing,
      });
    } catch (e) {
      debugPrint('[MeetingBackgroundService] Failed to start service: $e');
    }
  }

  /// Updates the native foreground service notification text and flags
  /// (e.g. when screen sharing starts or stops).
  static Future<void> update({
    required String meetingCode,
    bool isScreenSharing = false,
  }) async {
    if (!Platform.isAndroid) return;
    try {
      final title = 'CloudNews Meeting: $meetingCode';
      final body = isScreenSharing
          ? 'Screen sharing and audio active in background'
          : 'Meeting audio active in background';
      await _channel.invokeMethod('updateService', {
        'title': title,
        'body': body,
        'isScreenSharing': isScreenSharing,
      });
    } catch (e) {
      debugPrint('[MeetingBackgroundService] Failed to update service: $e');
    }
  }

  /// Stops the native foreground service and removes the ongoing notification.
  static Future<void> stop() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('stopService');
    } catch (e) {
      debugPrint('[MeetingBackgroundService] Failed to stop service: $e');
    }
  }

  /// Displays the iOS system ReplayKit broadcast picker dialog.
  /// Returns `true` if the system picker was successfully triggered.
  static Future<bool> showScreenSharePicker() async {
    if (!Platform.isIOS) return false;
    try {
      final result = await _channel.invokeMethod<bool>('showScreenSharePicker');
      return result ?? false;
    } catch (e) {
      debugPrint('[MeetingBackgroundService] Failed to show screen share picker: $e');
      return false;
    }
  }
}

