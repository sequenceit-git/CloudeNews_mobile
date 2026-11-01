import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/models.dart';
import '../screens/meeting_room_screen.dart';
import 'api_service.dart';

class MeetingLaunchException implements Exception {
  final int code;
  final String? detail;

  const MeetingLaunchException(this.code, this.detail);

  @override
  String toString() => 'MeetingLaunchException($code, $detail)';
}

/// Opens the plain TRTC room and reports leave / end back to the CloudNews server.
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
      final camera = await Permission.camera.request();
      final microphone = await Permission.microphone.request();
      if (!camera.isGranted || !microphone.isGranted) {
        throw const MeetingLaunchException(0, 'Camera and microphone permission are required');
      }
      if (!context.mounted) return;

      final exit = await Navigator.of(context).push<MeetingExit>(MaterialPageRoute<MeetingExit>(
        settings: const RouteSettings(name: roomRouteName),
        builder: (_) => MeetingRoomScreen(
          ticket: ticket,
          displayName: displayName,
          microphoneOn: microphoneOn,
          cameraOn: cameraOn,
        ),
      ));

      final api = ApiService.instance;
      final meetingId = ticket.meeting.id;
      try {
        if (exit == MeetingExit.hostEnded && ticket.trtc.isHost && api.isHostSignedIn) {
          await api.endMeeting(meetingId);
        } else if (exit != MeetingExit.hostEnded) {
          await api.leaveMeeting(meetingId, ticket.trtc.userId);
        }
      } on ApiException catch (error) {
        debugPrint('[Meeting] server update failed: $error');
      }
    } finally {
      _inMeeting = false;
    }
  }
}
