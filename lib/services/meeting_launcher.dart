import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/models.dart';
import '../screens/meeting_room_screen.dart';

class MeetingLaunchException implements Exception {
  final int code;
  final String? detail;

  const MeetingLaunchException(this.code, this.detail);

  @override
  String toString() => 'MeetingLaunchException($code, $detail)';
}

class MeetingLauncher {
  MeetingLauncher._();

  static const roomRouteName = '/meeting-room';

  static bool _inMeeting = false;

  static bool get isInMeeting => _inMeeting;

  static Future<void> enter(
    BuildContext context, {
    required MeetingTicket ticket,
    required String displayName,
    bool microphoneOn = true,
    bool cameraOn = true,
  }) async {
    if (_inMeeting) return;
    _inMeeting = true;
    try {
      // 1. Request microphone and camera permissions
      await [Permission.camera, Permission.microphone].request();
      if (!context.mounted) return;

      final navigator = Navigator.of(context);

      // 2. Launch MeetingRoomScreen
      await navigator.push(MaterialPageRoute<void>(
        settings: const RouteSettings(name: roomRouteName),
        builder: (_) => MeetingRoomScreen(
          ticket: ticket,
          displayName: displayName,
          microphoneOn: microphoneOn,
          cameraOn: cameraOn,
        ),
      ));
    } finally {
      _inMeeting = false;
    }
  }
}
