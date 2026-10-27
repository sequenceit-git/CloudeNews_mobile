import 'dart:async';

import 'package:atomic_x_core/atomicxcore.dart';
import 'package:flutter/material.dart';
import 'package:tencent_conference_uikit/tencent_conference_uikit.dart';
import 'package:tuikit_atomic_x/atomicx.dart' show AtomicAlertDialog, Permission, PermissionType;

import '../config/env.dart';
import '../models/models.dart';
import '../widgets/room_chat_page.dart';
import 'api_service.dart';

class MeetingLaunchException implements Exception {
  final int code;
  final String? detail;

  const MeetingLaunchException(this.code, this.detail);

  @override
  String toString() => 'MeetingLaunchException($code, $detail)';
}

/// Signs into TRTC with the server-issued UserSig, opens TUIRoomKit's
/// [RoomMainWidget], and reports leave / end back to the CloudNews server.
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
      await Permission.request([PermissionType.camera, PermissionType.microphone]);
      await _signIn(ticket.trtc, displayName);
      if (!context.mounted) return;

      final navigator = Navigator.of(context);
      final session = _MeetingSession(ticket, navigator, ModalRoute.of(context));
      session.start();

      final trtc = ticket.trtc;
      await navigator.push(MaterialPageRoute<void>(
        settings: const RouteSettings(name: roomRouteName),
        builder: (_) => RoomMainWidget(
          roomID: trtc.roomId,
          chatPageBuilder: buildRoomChatPage,
          behavior: trtc.isHost
              ? RoomBehavior.create(CreateRoomOptions(roomName: ticket.meeting.title))
              : const RoomBehavior.enter(),
          config: ConnectConfig(
            autoEnableMicrophone: microphoneOn,
            autoEnableCamera: cameraOn,
            autoEnableSpeaker: true,
          ),
        ),
      ));

      await session.finish();
    } finally {
      _inMeeting = false;
    }
  }

  static Future<void> _signIn(TrtcCredentials trtc, String displayName) async {
    final store = LoginStore.shared;
    final state = store.loginState;
    final alreadySignedIn =
        state.loginStatus == LoginStatus.logined && state.loginUserInfo?.userID == trtc.userId;

    if (!alreadySignedIn) {
      if (state.loginStatus == LoginStatus.logined) await store.logout();
      final sdkAppId = trtc.sdkAppId != 0 ? trtc.sdkAppId : Env.trtcSdkAppId;
      final result = await store.login(sdkAppID: sdkAppId, userID: trtc.userId, userSig: trtc.userSig);
      if (!result.isSuccess) throw MeetingLaunchException(result.errorCode, result.errorMessage);
    }

    final name = displayName.trim();
    if (name.isNotEmpty) {
      await store.setSelfInfo(userInfo: UserProfile(userID: trtc.userId, nickname: name));
    }
  }
}

class _MeetingSession {
  _MeetingSession(this.ticket, this.navigator, this.returnRoute);

  final MeetingTicket ticket;
  final NavigatorState navigator;
  final Route<dynamic>? returnRoute;

  late final RoomListener _roomListener = RoomListener(onRoomEnded: (_) => _endedByOthers = true);
  Timer? _soloTimer;
  bool _endedByOthers = false;
  bool _endedBySoloTimeout = false;

  String get _roomId => ticket.trtc.roomId;

  void start() {
    RoomStore.shared.addRoomListener(_roomListener);
    RoomStore.shared.state.currentRoom.addListener(_watchSoloHost);
  }

  Future<void> finish() async {
    RoomStore.shared.removeRoomListener(_roomListener);
    RoomStore.shared.state.currentRoom.removeListener(_watchSoloHost);
    _soloTimer?.cancel();
    _soloTimer = null;

    final api = ApiService.instance;
    final meetingId = ticket.meeting.id;
    try {
      if (ticket.trtc.isHost && api.isHostSignedIn && await _hostEndedMeeting()) {
        await api.endMeeting(meetingId);
      } else {
        await api.leaveMeeting(meetingId, ticket.trtc.userId);
      }
    } on ApiException catch (e) {
      debugPrint('[Meeting] server update failed: $e');
    }
  }

  /// TUIRoomKit's own Leave / End buttons close the room page, so after it
  /// closes the room is checked: if it no longer exists, the host ended it.
  Future<bool> _hostEndedMeeting() async {
    if (_endedBySoloTimeout) return true;
    if (_endedByOthers) return false;
    final result = await RoomStore.shared.getRoomInfo(_roomId);
    final stillExists = result.isSuccess && (result.roomInfo?.roomID.isNotEmpty ?? false);
    return !stillExists;
  }

  bool _isSoloHost() {
    final room = RoomStore.shared.state.currentRoom.value;
    return room != null &&
        room.roomID == _roomId &&
        room.roomOwner.userID == ticket.trtc.userId &&
        room.participantCount <= 1;
  }

  void _watchSoloHost() {
    if (_isSoloHost()) {
      _soloTimer ??= Timer(Env.soloMeetingTimeout, _endSoloMeeting);
    } else {
      _soloTimer?.cancel();
      _soloTimer = null;
    }
  }

  Future<void> _endSoloMeeting() async {
    _soloTimer = null;
    if (!_isSoloHost()) return;
    _endedBySoloTimeout = true;
    await RoomStore.shared.endRoom();
    AtomicAlertDialog.dismissAll();
    final target = returnRoute;
    if (target != null && target.isActive) {
      navigator.popUntil((route) => route == target);
    }
  }
}
