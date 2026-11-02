import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tencent_rtc_sdk/trtc_cloud.dart';
import 'package:tencent_rtc_sdk/trtc_cloud_def.dart';
import 'package:tencent_rtc_sdk/trtc_cloud_listener.dart';
import 'package:tencent_rtc_sdk/tx_device_manager.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../config/env.dart';
import '../l10n/app_strings.dart';
import '../l10n/language_scope.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import '../widgets/meeting_chat_sheet.dart';
import '../widgets/meeting/meeting_bottom_bar.dart';
import '../widgets/meeting/meeting_carousel_view.dart';
import '../widgets/meeting/meeting_dialogs.dart';
import '../widgets/meeting/meeting_top_bar.dart';
import '../widgets/meeting/meeting_video_tile.dart';

class MeetingRoomScreen extends StatefulWidget {
  const MeetingRoomScreen({
    super.key,
    required this.ticket,
    required this.displayName,
    this.microphoneOn = true,
    this.cameraOn = true,
  });

  final MeetingTicket ticket;
  final String displayName;
  final bool microphoneOn;
  final bool cameraOn;

  @override
  State<MeetingRoomScreen> createState() => _MeetingRoomScreenState();
}

class _MeetingRoomScreenState extends State<MeetingRoomScreen> {
  TRTCCloud? _trtcCloud;
  TRTCCloudListener? _listener;
  int? _localViewId;
  final Map<String, int> _remoteUserViews = {};

  bool _isInRoom = false;
  bool _isMicMuted = false;
  bool _isCameraOff = false;
  bool _isFrontCamera = true;
  bool _isSpeakerPhone = true;
  bool _isSharingScreen = false;
  bool _isStartingScreenShare = false;
  bool _wasCameraOnBeforeScreenShare = false;
  bool _isChatOpen = false;
  bool _isScreenShareFit = true;
  String? _activeScreenSharerName;
  bool _isExiting = false;
  bool _isCleanedUp = false;

  late final PageController _carouselController;
  int _currentCarouselPage = 0;

  late bool _isHost;
  late String _currentHostUserId;
  bool _hasExited = false;

  WebSocketChannel? _roomWsChannel;
  StreamSubscription<dynamic>? _roomWsSub;
  Timer? _roomValidationTimer;

  final Set<String> _videoAvailableUsers = {};
  final Set<String> _audioAvailableUsers = {};
  final Set<String> _subStreamUsers = {};
  final Set<String> _remoteParticipants = {};
  final Map<String, int> _userVolumeMap = {};
  final Map<String, String> _userDisplayNameMap = {};
  final List<MeetingChatMessage> _meetingChatMessages = [];
  int _unreadChatCount = 0;

  Timer? _meetingTimer;
  Timer? _soloHostTimer;
  int _elapsedSeconds = 0;

  @override
  void initState() {
    super.initState();
    _carouselController = PageController();
    _isMicMuted = !widget.microphoneOn;
    _isCameraOff = !widget.cameraOn;
    _isHost = widget.ticket.trtc.isHost;
    _currentHostUserId = (widget.ticket.meeting.hostUserId ?? '').replaceAll('-', '');
    if (_isHost && _currentHostUserId.isEmpty) {
      _currentHostUserId = widget.ticket.trtc.userId.replaceAll('-', '');
    }

    _startMeetingTimer();
    _fetchParticipants();
    _connectRoomWebSocket();
    _startValidationPolling();
    _initTRTC();
  }

  void _connectRoomWebSocket() {
    final baseUri = Uri.parse(Env.apiBaseUrl);
    final wsScheme = baseUri.scheme == 'https' ? 'wss' : 'ws';
    final wsUri = baseUri.replace(
      scheme: wsScheme,
      path: '${baseUri.path}/meetings/${Uri.encodeComponent(widget.ticket.meeting.meetingCode)}/chat',
    );

    try {
      final channel = WebSocketChannel.connect(wsUri);
      _roomWsChannel = channel;

      channel.sink.add(jsonEncode({
        'type': 'join',
        'userId': widget.ticket.trtc.userId,
        'displayName': widget.displayName,
      }));

      _roomWsSub = channel.stream.listen(
        (data) {
          if (!mounted) return;
          try {
            final json = jsonDecode(data.toString());
            if (json is Map<String, dynamic>) {
              final type = json['type'] as String?;
              if (type == 'ended') {
                _onMeetingEndedByHost();
              } else if (type == 'host_transferred') {
                _onHostTransferred(json['userId'] as String? ?? '', json['displayName'] as String?);
              } else if (type == 'text' || type == 'image' || type == 'file') {
                final msg = MeetingChatMessage.fromJson(json);
                if (!_meetingChatMessages.any((m) => m.id == msg.id)) {
                  setState(() {
                    _meetingChatMessages.add(msg);
                    final myCleanId = widget.ticket.trtc.userId.replaceAll('-', '');
                    final senderCleanId = msg.userId.replaceAll('-', '');
                    if (!_isChatOpen && senderCleanId != myCleanId) {
                      _unreadChatCount++;
                    }
                  });
                }
              }
            }
          } catch (_) {}
        },
        onError: (_) {},
      );
    } catch (_) {}
  }

  void _startValidationPolling() {
    _roomValidationTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
      if (!_isInRoom || _hasExited || !mounted) return;
      try {
        final res = await ApiService.instance.validateMeeting(widget.ticket.meeting.meetingCode);
        if (!res.valid) {
          _onMeetingEndedByHost();
        }
      } catch (_) {}
    });
  }

  void _onMeetingEndedByHost() {
    if (_isExiting || !mounted) return;
    final strings = context.strings;
    showWarningSnack(context, strings.hostEndedMeetingNotice);
    _exitAndNotify(isHostEnding: false);
  }

  void _onHostTransferred(String newHostUserId, String? newHostName) {
    if (!mounted) return;
    final cleanNew = newHostUserId.replaceAll('-', '');
    final cleanMe = widget.ticket.trtc.userId.replaceAll('-', '');
    final wasHost = _isHost;
    final isNowHost = (cleanNew == cleanMe);

    setState(() {
      _currentHostUserId = cleanNew;
      _isHost = isNowHost;
    });

    if (!wasHost && isNowHost) {
      showSuccessSnack(context, context.strings.youAreNowHost);
    }
    _fetchParticipants();
  }

  Future<void> _fetchParticipants() async {
    try {
      final list = await ApiService.instance.getParticipants(widget.ticket.meeting.meetingCode);
      if (!mounted) return;
      final map = <String, String>{};
      for (final p in list) {
        final uid = (p['userId'] as String? ?? '').replaceAll('-', '');
        final name = p['displayName'] as String? ?? '';
        if (uid.isNotEmpty && name.isNotEmpty) {
          map[uid] = name;
        }
      }
      setState(() => _userDisplayNameMap.addAll(map));
    } catch (_) {}
  }

  String _getDisplayNameForUser(String userId) {
    final cleanId = userId.replaceAll('-', '');
    if (_userDisplayNameMap.containsKey(cleanId) && _userDisplayNameMap[cleanId]!.isNotEmpty) {
      return _userDisplayNameMap[cleanId]!;
    }
    final hostCleanId = (widget.ticket.meeting.hostUserId ?? '').replaceAll('-', '');
    if (hostCleanId.isNotEmpty && cleanId == hostCleanId && widget.ticket.meeting.hostName.isNotEmpty) {
      return widget.ticket.meeting.hostName;
    }
    return cleanId.length >= 8 ? 'Guest ${cleanId.substring(cleanId.length - 4).toUpperCase()}' : userId;
  }

  @override
  void dispose() {
    _meetingTimer?.cancel();
    _soloHostTimer?.cancel();
    _roomValidationTimer?.cancel();
    _roomWsSub?.cancel();
    _roomWsChannel?.sink.close();
    _cleanUpTRTC();
    _carouselController.dispose();
    super.dispose();
  }

  void _startMeetingTimer() {
    _meetingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsedSeconds++);
    });
  }

  String _formatElapsed() {
    final h = _elapsedSeconds ~/ 3600;
    final m = (_elapsedSeconds % 3600) ~/ 60;
    final s = _elapsedSeconds % 60;
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Future<void> _initTRTC() async {
    try {
      final cloud = await TRTCCloud.sharedInstance();
      _trtcCloud = cloud;

      // Start local audio capture immediately
      cloud.startLocalAudio(TRTCAudioQuality.speech);
      if (_isMicMuted) {
        cloud.muteLocalAudio(true);
      }
      cloud.getDeviceManager().setAudioRoute(_isSpeakerPhone ? TXAudioRoute.speakerPhone : TXAudioRoute.earpiece);

      // Start local preview immediately if view was already created
      if (_localViewId != null) {
        cloud.startLocalPreview(_isFrontCamera, _localViewId!);
        cloud.muteLocalVideo(TRTCVideoStreamType.big, _isCameraOff);
      }

      // 1. Register event listener BEFORE enterRoom
      _listener = TRTCCloudListener(
        onError: (errCode, errMsg) {
          debugPrint('[TRTC] onError: $errCode, $errMsg');
          if (mounted) {
            showErrorSnack(context, 'TRTC Error $errCode: $errMsg');
          }
        },
        onEnterRoom: (result) {
          if (result > 0) {
            _handleEnterRoomSuccess();
          } else {
            debugPrint('[TRTC] onEnterRoom failed: $result');
            if (mounted) {
              if (result == -3301) {
                showErrorSnack(
                  context,
                  'Enter room failed (-3301). Please activate TRTC service for SDKAppID in Tencent Cloud Console.',
                );
              } else {
                showErrorSnack(context, 'Enter room failed: $result');
              }
            }
          }
        },
        onExitRoom: (reason) {
          _isInRoom = false;
        },
        onUserVideoAvailable: (userId, available) {
          if (!mounted) return;
          setState(() {
            if (available) {
              _videoAvailableUsers.add(userId);
              final viewId = _remoteUserViews[userId];
              if (viewId != null) {
                _trtcCloud?.startRemoteView(userId, TRTCVideoStreamType.big, viewId);
              }
            } else {
              _videoAvailableUsers.remove(userId);
              _trtcCloud?.stopRemoteView(userId, TRTCVideoStreamType.big);
            }
          });
        },
        onUserSubStreamAvailable: (userId, available) {
          if (!mounted) return;
          setState(() {
            if (available) {
              _subStreamUsers.add(userId);
              _activeScreenSharerName = _getDisplayNameForUser(userId);
              _trtcCloud?.setRemoteRenderParams(
                userId,
                TRTCVideoStreamType.sub,
                TRTCRenderParams(
                  fillMode: _isScreenShareFit ? TRTCVideoFillMode.fit : TRTCVideoFillMode.fill,
                  rotation: TRTCVideoRotation.rotation0,
                ),
              );
              if (_carouselController.hasClients && _currentCarouselPage != 0) {
                _carouselController.animateToPage(0, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
              }
            } else {
              _subStreamUsers.remove(userId);
              if (_subStreamUsers.isEmpty) {
                _activeScreenSharerName = null;
              }
              _trtcCloud?.stopRemoteView(userId, TRTCVideoStreamType.sub);
            }
          });
        },
        onUserAudioAvailable: (userId, available) {
          if (!mounted) return;
          setState(() {
            if (available) {
              _audioAvailableUsers.add(userId);
            } else {
              _audioAvailableUsers.remove(userId);
            }
          });
        },
        onRemoteUserEnterRoom: (userId) {
          if (!mounted) return;
          setState(() {
            _remoteParticipants.add(userId);
          });
          _fetchParticipants();
          _checkSoloHost();
        },
        onRemoteUserLeaveRoom: (userId, reason) {
          if (!mounted) return;
          setState(() {
            _remoteParticipants.remove(userId);
            _videoAvailableUsers.remove(userId);
            _audioAvailableUsers.remove(userId);
            _subStreamUsers.remove(userId);
            if (_subStreamUsers.isEmpty) {
              _activeScreenSharerName = null;
            }
            _userVolumeMap.remove(userId);
            _remoteUserViews.remove(userId);
          });
          _checkSoloHost();
        },
        onScreenCaptureStarted: () {
          if (!mounted) return;
          setState(() => _isSharingScreen = true);
      if (_carouselController.hasClients && _currentCarouselPage != 0) {
        _carouselController.animateToPage(0, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
      }
          _broadcastTrtcCommand({
            'action': 'screen_share_started',
            'sharerId': widget.ticket.trtc.userId,
            'sharerName': widget.displayName,
          });
          if (_carouselController.hasClients && _currentCarouselPage != 0) {
            _carouselController.animateToPage(0, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
          }
        },
        onScreenCaptureStopped: (reason) {
          if (!mounted) return;
          setState(() {
            _isSharingScreen = false;
            if (_wasCameraOnBeforeScreenShare) {
              _wasCameraOnBeforeScreenShare = false;
              _isCameraOff = false;
              _trtcCloud?.muteLocalVideo(TRTCVideoStreamType.big, false);
            }
          });
          _broadcastTrtcCommand({
            'action': 'screen_share_stopped',
            'sharerId': widget.ticket.trtc.userId,
          });
        },
        onUserVoiceVolume: (userVolumes, totalVolume) {
          if (!mounted) return;
          final updated = <String, int>{};
          for (final item in userVolumes) {
            final uid = item.userId.isNotEmpty ? item.userId : widget.ticket.trtc.userId;
            updated[uid] = item.volume;
          }
          setState(() => _userVolumeMap.addAll(updated));
        },
        onRecvCustomCmdMsg: (userId, cmdId, seq, message) {
          if (!mounted) return;
          try {
            final data = jsonDecode(message);
            if (data is Map<String, dynamic>) {
              final action = data['action'] as String?;
              if (action == 'ended') {
                _onMeetingEndedByHost();
              } else if (action == 'transfer_host') {
                _onHostTransferred(data['newHostUserId'] as String? ?? '', data['newHostName'] as String?);
              } else if (action == 'screen_share_started') {
                final name = data['sharerName'] as String? ?? 'Someone';
                final id = data['sharerId'] as String? ?? '';
                final myCleanId = widget.ticket.trtc.userId.replaceAll('-', '');
                final sharerCleanId = id.replaceAll('-', '');
                setState(() {
                  _activeScreenSharerName = name;
                  if (sharerCleanId.isNotEmpty && sharerCleanId != myCleanId) {
                    _subStreamUsers.add(id);
                  }
                });
              } else if (action == 'screen_share_stopped') {
                final id = data['sharerId'] as String?;
                setState(() {
                  _activeScreenSharerName = null;
                  if (id != null && id.isNotEmpty) {
                    _subStreamUsers.remove(id);
                  } else {
                    _subStreamUsers.clear();
                  }
                });
              } else if (action == 'mic_state') {
                final isMuted = data['isMuted'] as bool? ?? false;
                final uid = data['userId'] as String? ?? userId;
                setState(() {
                  if (isMuted) {
                    _audioAvailableUsers.remove(uid);
                  } else {
                    _audioAvailableUsers.add(uid);
                  }
                });
              }
            }
          } catch (_) {}
        },
      );
      cloud.registerListener(_listener!);

      // 2. Video encoding settings (640x360 portrait, 15fps, 600kbps)
      cloud.setVideoEncoderParam(TRTCVideoEncParam(
        videoResolution: TRTCVideoResolution.res_640_360,
        videoFps: 15,
        videoBitrate: 600,
        videoResolutionMode: TRTCVideoResolutionMode.portrait,
      ));

      // 3. Audio volume evaluation (active speaker detection every 300ms)
      cloud.enableAudioVolumeEvaluation(true, TRTCAudioVolumeEvaluateParams(interval: 300));

      // 4. Enter room with uint32 numeric roomId
      final rawRoomId = widget.ticket.trtc.roomId.replaceAll(RegExp(r'[^0-9]'), '');
      final numericRoomId = int.tryParse(rawRoomId) ?? int.parse(widget.ticket.meeting.meetingCode.replaceAll('-', ''));

      final params = TRTCParams(
        sdkAppId: widget.ticket.trtc.sdkAppId != 0 ? widget.ticket.trtc.sdkAppId : Env.trtcSdkAppId,
        userId: widget.ticket.trtc.userId,
        userSig: widget.ticket.trtc.userSig,
        roomId: numericRoomId,
        role: TRTCRoleType.anchor,
      );

      cloud.enterRoom(params, TRTCAppScene.videoCall);
    } catch (e) {
      debugPrint('[TRTC] init error: $e');
    }
  }

  void _broadcastTrtcCommand(Map<String, dynamic> data) {
    try {
      final str = jsonEncode(data);
      _trtcCloud?.sendCustomCmdMsg(1, str, true, true);
    } catch (e) {
      debugPrint('[TRTC] sendCustomCmdMsg error: $e');
    }
  }

  void _handleEnterRoomSuccess() {
    _isInRoom = true;
    _checkSoloHost();
    if (mounted) setState(() {});
  }

  void _checkSoloHost() {
    if (!_isHost) return;

    if (_remoteParticipants.isEmpty) {
      _soloHostTimer ??= Timer(Env.soloMeetingTimeout, _onSoloHostTimeout);
    } else {
      _soloHostTimer?.cancel();
      _soloHostTimer = null;
    }
  }

  Future<void> _onSoloHostTimeout() async {
    _soloHostTimer = null;
    if (_remoteParticipants.isNotEmpty || !mounted) return;

    final strings = context.strings;
    showWarningSnack(context, strings.soloTimeoutNotice);
    await _exitAndNotify(isHostEnding: true);
  }

  void _cleanUpTRTC() {
    if (_isCleanedUp) return;
    _isCleanedUp = true;
    try {
      if (_isSharingScreen) {
        _trtcCloud?.stopScreenCapture();
        _broadcastTrtcCommand({
          'action': 'screen_share_stopped',
          'sharerId': widget.ticket.trtc.userId,
        });
        _isSharingScreen = false;
      }
      _trtcCloud?.stopLocalPreview();
      _trtcCloud?.stopLocalAudio();
      _trtcCloud?.exitRoom();
      if (_listener != null) {
        _trtcCloud?.unRegisterListener(_listener!);
        _listener = null;
      }
      _localViewId = null;
      _remoteUserViews.clear();
      _trtcCloud = null;
    } catch (_) {}
  }

  void _toggleMic() {
    final next = !_isMicMuted;
    _trtcCloud?.muteLocalAudio(next);
    _broadcastTrtcCommand({
      'action': 'mic_state',
      'userId': widget.ticket.trtc.userId,
      'isMuted': next,
    });
    setState(() => _isMicMuted = next);
  }

  void _toggleCamera() {
    final next = !_isCameraOff;
    _trtcCloud?.muteLocalVideo(TRTCVideoStreamType.big, next);
    setState(() => _isCameraOff = next);
  }

  void _flipCamera() {
    final next = !_isFrontCamera;
    _trtcCloud?.getDeviceManager().switchCamera(next);
    setState(() => _isFrontCamera = next);
  }

  void _toggleAudioRoute() {
    final next = !_isSpeakerPhone;
    _trtcCloud?.getDeviceManager().setAudioRoute(next ? TXAudioRoute.speakerPhone : TXAudioRoute.earpiece);
    setState(() => _isSpeakerPhone = next);
  }

  void _toggleScreenShare() {
    if (_isSharingScreen) {
      _trtcCloud?.stopScreenCapture();
      _broadcastTrtcCommand({
        'action': 'screen_share_stopped',
        'sharerId': widget.ticket.trtc.userId,
      });
      setState(() {
        _isSharingScreen = false;
        if (_wasCameraOnBeforeScreenShare) {
          _wasCameraOnBeforeScreenShare = false;
          _isCameraOff = false;
          _trtcCloud?.muteLocalVideo(TRTCVideoStreamType.big, false);
        }
      });
      return;
    }

    _confirmAndStartScreenShare();
  }

  Future<void> _confirmAndStartScreenShare() async {
    if (_isStartingScreenShare) return;

    // Check if another participant is currently sharing the screen
    final myCleanId = widget.ticket.trtc.userId.replaceAll('-', '');
    final remoteSubStreamUsers = _subStreamUsers.where((uid) => uid.replaceAll('-', '') != myCleanId).toList();

    String? activeSharerName;
    if (remoteSubStreamUsers.isNotEmpty) {
      activeSharerName = _getDisplayNameForUser(remoteSubStreamUsers.first);
    } else if (_activeScreenSharerName != null &&
               _activeScreenSharerName!.isNotEmpty &&
               _activeScreenSharerName != widget.displayName) {
      activeSharerName = _activeScreenSharerName;
    }

    if (activeSharerName != null) {
      showWarningSnack(context, context.strings.otherUserSharingScreen(activeSharerName));
      return;
    }

    final strings = context.strings;
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        decoration: const BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.textDim.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.cyan.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.screen_share, size: 36, color: AppColors.cyan),
              ),
              const SizedBox(height: 16),
              Text(
                strings.confirmStartScreenShareTitle,
                style: const TextStyle(color: AppColors.text, fontSize: 17, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                strings.confirmStartScreenShareDesc,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.text,
                        side: const BorderSide(color: AppColors.cardBorder),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () => Navigator.of(sheetContext).pop(false),
                      child: Text(strings.cancel),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.cyan,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () => Navigator.of(sheetContext).pop(true),
                      child: Text(strings.startSharingAction, style: const TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed != true || !mounted) return;

    _startScreenShareCapture();
  }

  void _startScreenShareCapture() {
    if (_isStartingScreenShare) return;
    _isStartingScreenShare = true;

    // Cooldown debouncer
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) _isStartingScreenShare = false;
    });

    // Seamlessly pause camera preview while sharing screen to avoid OS hardware contention
    if (!_isCameraOff) {
      _wasCameraOnBeforeScreenShare = true;
      _trtcCloud?.muteLocalVideo(TRTCVideoStreamType.big, true);
      setState(() => _isCameraOff = true);
    }

    try {
      final encParams = TRTCVideoEncParam(
        videoResolution: TRTCVideoResolution.res_1280_720,
        videoFps: 10,
        videoBitrate: 1200,
        videoResolutionMode: TRTCVideoResolutionMode.portrait,
      );
      if (Platform.isIOS) {
        _trtcCloud?.startScreenCaptureByReplaykit(TRTCVideoStreamType.sub, encParams, 'group.com.cloudnews.app.ios');
      } else {
        _trtcCloud?.startScreenCapture(0, TRTCVideoStreamType.sub, encParams);
      }
      _trtcCloud?.setSubStreamEncoderParam(encParams);
      // Note: _isSharingScreen will be set to true when onScreenCaptureStarted fires
    } catch (e) {
      debugPrint('[TRTC] startScreenCapture error: $e');
      if (mounted) showErrorSnack(context, 'Screen share error: $e');
      if (_wasCameraOnBeforeScreenShare) {
        _wasCameraOnBeforeScreenShare = false;
        _isCameraOff = false;
        _trtcCloud?.muteLocalVideo(TRTCVideoStreamType.big, false);
        if (mounted) setState(() {});
      }
    }
  }

  void _copyMeetingCode() {
    Clipboard.setData(ClipboardData(text: widget.ticket.meeting.meetingCode));
    showSuccessSnack(context, context.strings.codeCopied);
  }

  Future<void> _openChatSheet() async {
    setState(() {
      _isChatOpen = true;
      _unreadChatCount = 0;
    });
    try {
      if (Platform.isIOS) {
        // On iOS, open as a fullscreen modal dialog to prevent native UiKitView video tiles from overlapping
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            fullscreenDialog: true,
            builder: (_) => Scaffold(
              backgroundColor: AppColors.background,
              body: SafeArea(
                child: MeetingChatSheet(
                  meetingCode: widget.ticket.meeting.meetingCode,
                  userId: widget.ticket.trtc.userId,
                  displayName: widget.displayName,
                  initialMessages: _meetingChatMessages,
                  onMessageReceived: (msg) {
                    if (!_meetingChatMessages.any((m) => m.id == msg.id)) {
                      _meetingChatMessages.add(msg);
                    }
                  },
                  isFullScreen: true,
                  onUserIdentified: (uid, name) {
                    final clean = uid.replaceAll('-', '');
                    if (clean.isNotEmpty && name.isNotEmpty && _userDisplayNameMap[clean] != name) {
                      setState(() => _userDisplayNameMap[clean] = name);
                    }
                  },
                  onRoomEnded: () {
                    Navigator.of(context).pop();
                    _exitAndNotify(isHostEnding: false);
                  },
                ),
              ),
            ),
          ),
        );
      } else {
        await showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          backgroundColor: Colors.transparent,
          builder: (_) => MeetingChatSheet(
            meetingCode: widget.ticket.meeting.meetingCode,
            userId: widget.ticket.trtc.userId,
            displayName: widget.displayName,
            initialMessages: _meetingChatMessages,
            onMessageReceived: (msg) {
              if (!_meetingChatMessages.any((m) => m.id == msg.id)) {
                _meetingChatMessages.add(msg);
              }
            },
            onUserIdentified: (uid, name) {
              final clean = uid.replaceAll('-', '');
              if (clean.isNotEmpty && name.isNotEmpty && _userDisplayNameMap[clean] != name) {
                setState(() => _userDisplayNameMap[clean] = name);
              }
            },
            onRoomEnded: () {
              Navigator.of(context).pop(); // Dismiss sheet
              _exitAndNotify(isHostEnding: false);
            },
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isChatOpen = false;
          _unreadChatCount = 0;
        });
      }
    }
  }

  void _showMembersList() {
    final strings = context.strings;
    final members = [
      MeetingMemberItem(
        name: '${widget.displayName} (${strings.meBadge})',
        isHost: _isHost,
        isMuted: _isMicMuted,
      ),
      ..._remoteParticipants.map((id) {
        final cleanId = id.replaceAll('-', '');
        return MeetingMemberItem(
          name: _getDisplayNameForUser(id),
          isHost: cleanId == _currentHostUserId,
          isMuted: !_audioAvailableUsers.contains(id),
        );
      }),
    ];

    showMeetingMembersSheet(
      context: context,
      members: members,
      strings: strings,
    );
  }

  void _promptLeaveOrEnd() {
    final strings = context.strings;
    showLeaveOrEndMeetingDialog(
      context: context,
      isHost: _isHost,
      hasRemoteParticipants: _remoteParticipants.isNotEmpty,
      onGuestLeave: () => _exitAndNotify(isHostEnding: false),
      onHostEndForAll: _endMeetingForAll,
      onHostTransferAndLeave: () => _showHostTransferSheet(strings),
      onHostAloneLeave: () => _confirmAloneLeave(strings),
      strings: strings,
    );
  }

  Future<void> _endMeetingForAll() async {
    _broadcastTrtcCommand({'action': 'ended'});
    await _exitAndNotify(isHostEnding: true);
  }

  void _confirmAloneLeave(AppStrings strings) {
    showConfirmAloneLeaveDialog(
      context: context,
      onConfirmEnd: _endMeetingForAll,
      strings: strings,
    );
  }

  void _showHostTransferSheet(AppStrings strings) {
    showHostTransferSheet(
      context: context,
      candidateUserIds: _remoteParticipants.toList(),
      getDisplayName: _getDisplayNameForUser,
      onTransferAndLeave: (targetId) async {
        try {
          await ApiService.instance.transferHost(
            widget.ticket.meeting.id,
            widget.ticket.trtc.userId,
            targetId,
          );
          _broadcastTrtcCommand({
            'action': 'transfer_host',
            'newHostUserId': targetId,
            'newHostName': _getDisplayNameForUser(targetId),
          });
          await _exitAndNotify(isHostEnding: false);
        } catch (e) {
          if (mounted) showErrorSnack(context, 'Transfer host error: $e');
        }
      },
      strings: strings,
    );
  }

  Future<void> _exitAndNotify({required bool isHostEnding}) async {
    if (_isExiting) return;
    _isExiting = true;
    _hasExited = true;

    if (mounted) {
      setState(() {
        _isInRoom = false;
      });
    }

    _roomWsSub?.cancel();
    _roomWsSub = null;
    _roomWsChannel?.sink.close();
    _roomWsChannel = null;
    _roomValidationTimer?.cancel();
    _roomValidationTimer = null;
    _meetingTimer?.cancel();
    _meetingTimer = null;
    _soloHostTimer?.cancel();
    _soloHostTimer = null;

    _cleanUpTRTC();

    final api = ApiService.instance;
    final meetingId = widget.ticket.meeting.id;
    try {
      if (isHostEnding && _isHost) {
        await api.endMeeting(meetingId, userId: widget.ticket.trtc.userId);
      } else {
        await api.leaveMeeting(meetingId, widget.ticket.trtc.userId);
      }
    } catch (_) {}

    if (mounted) {
      final nav = Navigator.of(context);
      if (nav.canPop()) {
        nav.popUntil((route) => route.isFirst);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final isSharing = _subStreamUsers.isNotEmpty || _isSharingScreen;
    final sharerId = _subStreamUsers.isNotEmpty ? _subStreamUsers.first : null;

    final myVol = _userVolumeMap[widget.ticket.trtc.userId] ?? 0;
    final allMemberTiles = <Widget>[
      MeetingLocalTile(
        displayName: widget.displayName,
        isHost: _isHost,
        isMicMuted: _isMicMuted,
        isCameraOff: _isCameraOff,
        isChatOpen: _isChatOpen,
        isExiting: _isExiting,
        isSpeaking: myVol > 20,
        onViewCreated: (viewId) {
          _localViewId = viewId;
          if (_trtcCloud != null) {
            _trtcCloud?.startLocalPreview(_isFrontCamera, viewId);
            _trtcCloud?.muteLocalVideo(TRTCVideoStreamType.big, false);
          }
        },
        strings: strings,
      ),
      ..._remoteParticipants.map((uid) {
        final hasVideo = _videoAvailableUsers.contains(uid);
        final isRemoteMicMuted = !_audioAvailableUsers.contains(uid);
        final vol = _userVolumeMap[uid] ?? 0;
        final cleanRemote = uid.replaceAll('-', '');
        final isRemoteHost = cleanRemote == _currentHostUserId;

        return MeetingRemoteTile(
          userId: uid,
          displayName: _getDisplayNameForUser(uid),
          isHost: isRemoteHost,
          isRemoteMicMuted: isRemoteMicMuted,
          hasVideo: hasVideo,
          isChatOpen: _isChatOpen,
          isExiting: _isExiting,
          isSpeaking: vol > 20,
          onViewCreated: (viewId) {
            _remoteUserViews[uid] = viewId;
            _trtcCloud?.startRemoteView(uid, TRTCVideoStreamType.big, viewId);
          },
          strings: strings,
        );
      }),
    ];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _promptLeaveOrEnd();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Column(
            children: [
              MeetingTopBar(
                meetingCode: widget.ticket.meeting.meetingCode,
                elapsedFormatted: _formatElapsed(),
                isSpeakerPhone: _isSpeakerPhone,
                isCameraOff: _isCameraOff,
                hasSubstream: _subStreamUsers.isNotEmpty,
                isScreenShareFit: _isScreenShareFit,
                onCopyMeetingCode: _copyMeetingCode,
                onToggleAudioRoute: _toggleAudioRoute,
                onFlipCamera: _flipCamera,
                onToggleScreenShareFit: () {
                  final sId = _subStreamUsers.first;
                  setState(() {
                    _isScreenShareFit = !_isScreenShareFit;
                    _trtcCloud?.setRemoteRenderParams(
                      sId,
                      TRTCVideoStreamType.sub,
                      TRTCRenderParams(
                        fillMode: _isScreenShareFit ? TRTCVideoFillMode.fit : TRTCVideoFillMode.fill,
                        rotation: TRTCVideoRotation.rotation0,
                      ),
                    );
                  });
                },
                onPromptLeaveOrEnd: _promptLeaveOrEnd,
                strings: strings,
              ),
              Expanded(
                child: MeetingCarouselView(
                  controller: _carouselController,
                  currentPage: _currentCarouselPage,
                  onPageChanged: (page) => setState(() => _currentCarouselPage = page),
                  isSharing: isSharing,
                  sharerId: sharerId,
                  isExiting: _isExiting,
                  isScreenShareFit: _isScreenShareFit,
                  onSubstreamViewCreated: (viewId) {
                    if (sharerId != null) {
                      _trtcCloud?.startRemoteView(sharerId, TRTCVideoStreamType.sub, viewId);
                      _trtcCloud?.setRemoteRenderParams(
                        sharerId,
                        TRTCVideoStreamType.sub,
                        TRTCRenderParams(
                          fillMode: _isScreenShareFit ? TRTCVideoFillMode.fit : TRTCVideoFillMode.fill,
                          rotation: TRTCVideoRotation.rotation0,
                        ),
                      );
                    }
                  },
                  onStopScreenShare: _toggleScreenShare,
                  participantTiles: allMemberTiles,
                  strings: strings,
                ),
              ),
              MeetingBottomBar(
                isMicMuted: _isMicMuted,
                isCameraOff: _isCameraOff,
                isSharingScreen: _isSharingScreen,
                hasUnreadChat: _unreadChatCount > 0,
                unreadChatCount: _unreadChatCount,
                participantCount: _remoteParticipants.length + 1,
                onToggleMic: _toggleMic,
                onToggleCamera: _toggleCamera,
                onToggleScreenShare: _toggleScreenShare,
                onOpenChat: _openChatSheet,
                onShowMembers: _showMembersList,
                strings: strings,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

