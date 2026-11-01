import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tencent_rtc_sdk/trtc_cloud.dart';
import 'package:tencent_rtc_sdk/trtc_cloud_def.dart';
import 'package:tencent_rtc_sdk/trtc_cloud_listener.dart';
import 'package:tencent_rtc_sdk/trtc_cloud_video_view.dart';
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
                  setState(() => _meetingChatMessages.add(msg));
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
    showErrorSnack(context, strings.hostEndedMeetingNotice);
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
      showErrorSnack(context, context.strings.youAreNowHost);
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
          setState(() => _isSharingScreen = false);
          _broadcastTrtcCommand({'action': 'screen_share_stopped'});
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
                setState(() {
                  _activeScreenSharerName = name;
                  if (id.isNotEmpty && id != widget.ticket.trtc.userId) {
                    _subStreamUsers.add(id);
                  }
                });
              } else if (action == 'screen_share_stopped') {
                setState(() {
                  _activeScreenSharerName = null;
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
    showErrorSnack(context, strings.soloTimeoutNotice);
    await _exitAndNotify(isHostEnding: true);
  }

  void _cleanUpTRTC() {
    if (_isCleanedUp) return;
    _isCleanedUp = true;
    try {
      if (_isSharingScreen) {
        _trtcCloud?.stopScreenCapture();
        _broadcastTrtcCommand({'action': 'screen_share_stopped'});
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
      _broadcastTrtcCommand({'action': 'screen_share_stopped'});
      setState(() => _isSharingScreen = false);
      return;
    }

    // Check if another participant is currently sharing the screen
    String? activeSharerName;
    if (_subStreamUsers.isNotEmpty) {
      activeSharerName = _getDisplayNameForUser(_subStreamUsers.first);
    } else if (_activeScreenSharerName != null && _activeScreenSharerName!.isNotEmpty) {
      activeSharerName = _activeScreenSharerName;
    }

    if (activeSharerName != null) {
      showErrorSnack(context, context.strings.otherUserSharingScreen(activeSharerName));
      return;
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
      _broadcastTrtcCommand({
        'action': 'screen_share_started',
        'sharerId': widget.ticket.trtc.userId,
        'sharerName': widget.displayName,
      });
      setState(() => _isSharingScreen = true);
      if (_carouselController.hasClients && _currentCarouselPage != 0) {
        _carouselController.animateToPage(0, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
      }
    } catch (e) {
      debugPrint('[TRTC] startScreenCapture error: $e');
      if (mounted) showErrorSnack(context, 'Screen share error: $e');
    }
  }

  void _copyMeetingCode() {
    Clipboard.setData(ClipboardData(text: widget.ticket.meeting.meetingCode));
    showErrorSnack(context, context.strings.codeCopied);
  }

  Future<void> _openChatSheet() async {
    setState(() => _isChatOpen = true);
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
        setState(() => _isChatOpen = false);
      }
    }
  }

  void _showMembersList() {
    final strings = context.strings;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        final members = [
          {
            'name': '${widget.displayName} (${strings.meBadge})',
            'isHost': _isHost,
            'isMuted': _isMicMuted,
          },
          ..._remoteParticipants.map((id) {
            final cleanId = id.replaceAll('-', '');
            return {
              'name': _getDisplayNameForUser(id),
              'isHost': cleanId == _currentHostUserId,
              'isMuted': !_audioAvailableUsers.contains(id),
            };
          }),
        ];
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    '${strings.membersTitle} (${members.length})',
                    style: const TextStyle(color: AppColors.text, fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppColors.textSecondary, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Divider(color: AppColors.cardBorder),
              ...members.map((m) {
                final isMuted = m['isMuted'] == true;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                        child: Text(
                          (m['name'] as String).characters.first.toUpperCase(),
                          style: const TextStyle(color: AppColors.primaryLight, fontSize: 12, fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Row(
                          children: [
                            Flexible(
                              child: Text(
                                m['name'] as String,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: AppColors.text, fontSize: 14),
                              ),
                            ),
                            if (m['isHost'] == true) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  strings.hostBadge,
                                  style: const TextStyle(color: AppColors.primaryLight, fontSize: 10, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Icon(
                        isMuted ? Icons.mic_off : Icons.mic,
                        size: 18,
                        color: isMuted ? AppColors.danger : AppColors.cyan,
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  void _promptLeaveOrEnd() {
    final strings = context.strings;

    if (!_isHost) {
      // Guest only has a single option: Leave Meeting
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.card,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(strings.leaveMeeting, style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.w700)),
          content: Text(strings.confirmLeave, style: const TextStyle(color: AppColors.textSecondary)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(strings.cancel, style: const TextStyle(color: AppColors.textDim)),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
              onPressed: () {
                Navigator.of(ctx).pop();
                _exitAndNotify(isHostEnding: false);
              },
              child: Text(strings.leaveMeeting),
            ),
          ],
        ),
      );
      return;
    }

    // Host has 2 options: End Meeting for All OR Leave Meeting (with Host Transfer)
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(2)),
              ),
              // Option 1: End Meeting for All
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.danger,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    _endMeetingForAll();
                  },
                  child: Text(strings.endMeetingForAll, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(height: 10),
              // Option 2: Leave Meeting
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.text,
                    side: const BorderSide(color: AppColors.cardBorder),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    if (_remoteParticipants.isEmpty) {
                      _confirmAloneLeave(strings);
                    } else {
                      _showHostTransferSheet(strings);
                    }
                  },
                  child: Text(strings.leaveMeeting, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(strings.cancel, style: const TextStyle(color: AppColors.textDim)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _endMeetingForAll() async {
    _broadcastTrtcCommand({'action': 'ended'});
    await _exitAndNotify(isHostEnding: true);
  }

  void _confirmAloneLeave(AppStrings strings) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(strings.leaveMeeting, style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.w700)),
        content: Text(strings.aloneInMeeting, style: const TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(strings.cancel, style: const TextStyle(color: AppColors.textDim)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () {
              Navigator.of(ctx).pop();
              _endMeetingForAll();
            },
            child: Text(strings.leaveAndEnd),
          ),
        ],
      ),
    );
  }

  void _showHostTransferSheet(AppStrings strings) {
    String? selectedUserId = _remoteParticipants.firstOrNull;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.card,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final candidates = _remoteParticipants.toList();

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  Text(
                    strings.transferHostTitle,
                    style: const TextStyle(color: AppColors.text, fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    strings.transferHostSubtitle,
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.4),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: candidates.length,
                      separatorBuilder: (_, __) => const Divider(color: AppColors.cardBorder, height: 1),
                      itemBuilder: (context, index) {
                        final uid = candidates[index];
                        final name = _getDisplayNameForUser(uid);
                        final initial = name.isNotEmpty ? name.characters.first.toUpperCase() : '?';
                        final isSelected = selectedUserId == uid;

                        return InkWell(
                          onTap: () => setModalState(() => selectedUserId = uid),
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 18,
                                  backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                                  child: Text(
                                    initial,
                                    style: const TextStyle(color: AppColors.primaryLight, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    name,
                                    style: const TextStyle(color: AppColors.text, fontSize: 15, fontWeight: FontWeight.w600),
                                  ),
                                ),
                                Icon(
                                  isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                                  color: isSelected ? AppColors.cyan : AppColors.textDim,
                                  size: 22,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.3),
                      ),
                      onPressed: selectedUserId == null
                          ? null
                          : () async {
                              final targetId = selectedUserId!;
                              Navigator.of(ctx).pop();
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
                                if (mounted) showErrorSnack(this.context, 'Transfer host error: $e');
                              }
                            },
                      child: Text(
                        strings.transferAndLeave,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Center(
                    child: TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: Text(strings.cancel, style: const TextStyle(color: AppColors.textDim)),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
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
              // Top Bar (Fixed at top, never covering screen share)
              _buildTopBar(strings),
              // Main Video or Screen Share Carousel with dynamic page indicator
              Expanded(
                child: _buildCarouselBody(),
              ),
              // Bottom Controls (Fixed at bottom, never covering screen share)
              _buildBottomControls(strings),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(AppStrings strings) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: Colors.black.withValues(alpha: 0.8),
      child: Row(
        children: [
          // Connection status indicator
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: _isInRoom ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
              shape: BoxShape.circle,
            ),
          ),
          // Elapsed time
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.timer_outlined, size: 13, color: AppColors.cyan),
                const SizedBox(width: 4),
                Text(
                  _formatElapsed(),
                  style: const TextStyle(color: AppColors.text, fontSize: 12, fontWeight: FontWeight.w600, fontFamily: 'monospace'),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          // Meeting code (1-tap copy)
          InkWell(
            onTap: _copyMeetingCode,
            borderRadius: BorderRadius.circular(6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.ticket.meeting.meetingCode,
                    style: const TextStyle(color: AppColors.primaryLight, fontSize: 12, fontWeight: FontWeight.w700, fontFamily: 'monospace'),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.copy, size: 12, color: AppColors.primaryLight),
                ],
              ),
            ),
          ),
          const Spacer(),
          // Audio Route Toggle
          IconButton(
            icon: Icon(_isSpeakerPhone ? Icons.volume_up : Icons.phone_in_talk, color: Colors.white, size: 20),
            onPressed: _toggleAudioRoute,
            tooltip: _isSpeakerPhone ? strings.speakerOn : strings.earpieceOn,
          ),
          // Flip Camera
          if (!_isCameraOff)
            IconButton(
              icon: const Icon(Icons.cameraswitch, color: Colors.white, size: 20),
              onPressed: _flipCamera,
              tooltip: strings.switchCamera,
            ),
          // Fit / Fill toggle during screen share
          if (_subStreamUsers.isNotEmpty)
            IconButton(
              icon: Icon(
                _isScreenShareFit ? Icons.fit_screen : Icons.fullscreen,
                color: Colors.white,
                size: 20,
              ),
              onPressed: () {
                final sharerId = _subStreamUsers.first;
                setState(() {
                  _isScreenShareFit = !_isScreenShareFit;
                  _trtcCloud?.setRemoteRenderParams(
                    sharerId,
                    TRTCVideoStreamType.sub,
                    TRTCRenderParams(
                      fillMode: _isScreenShareFit ? TRTCVideoFillMode.fit : TRTCVideoFillMode.fill,
                      rotation: TRTCVideoRotation.rotation0,
                    ),
                  );
                });
              },
              tooltip: _isScreenShareFit ? 'Fit to Screen' : 'Fill Screen',
            ),
          // Leave / End button
          IconButton(
            icon: const Icon(Icons.call_end, color: AppColors.danger, size: 24),
            onPressed: _promptLeaveOrEnd,
          ),
        ],
      ),
    );
  }

  Widget _buildCarouselBody() {
    final isSharing = _subStreamUsers.isNotEmpty || _isSharingScreen;
    final sharerId = _subStreamUsers.isNotEmpty ? _subStreamUsers.first : null;

    final allMemberTiles = <Widget>[
      _buildLocalTile(),
      ..._remoteParticipants.map((uid) => _buildRemoteTile(uid)),
    ];

    // Chunk participants into pages of at most 6 (2x3 grid)
    const pageSize = 6;
    final participantPages = <Widget>[];
    for (int i = 0; i < allMemberTiles.length; i += pageSize) {
      final end = (i + pageSize).clamp(0, allMemberTiles.length);
      final chunk = allMemberTiles.sublist(i, end);
      participantPages.add(_buildParticipantGridPage(chunk));
    }
    if (participantPages.isEmpty) {
      participantPages.add(_buildParticipantGridPage(allMemberTiles));
    }

    final pages = <Widget>[
      if (isSharing) _buildFullScreenSharePage(sharerId),
      ...participantPages,
    ];

    return Column(
      children: [
        Expanded(
          child: PageView(
            controller: _carouselController,
            onPageChanged: (page) => setState(() => _currentCarouselPage = page),
            children: pages,
          ),
        ),
        _buildPageIndicator(pages.length),
      ],
    );
  }

  Widget _buildFullScreenSharePage(String? sharerId) {
    return Container(
      color: Colors.black,
      child: (sharerId != null && !_isExiting)
          ? TRTCCloudVideoView(
              key: ValueKey('substream_$sharerId'),
              onViewCreated: (viewId) {
                _trtcCloud?.startRemoteView(sharerId, TRTCVideoStreamType.sub, viewId);
                _trtcCloud?.setRemoteRenderParams(
                  sharerId,
                  TRTCVideoStreamType.sub,
                  TRTCRenderParams(
                    fillMode: _isScreenShareFit ? TRTCVideoFillMode.fit : TRTCVideoFillMode.fill,
                    rotation: TRTCVideoRotation.rotation0,
                  ),
                );
              },
            )
          : Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppColors.cyan.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.screen_share, size: 56, color: AppColors.cyan),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    context.strings.screenShareActive,
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.danger,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    ),
                    onPressed: _toggleScreenShare,
                    icon: const Icon(Icons.stop_screen_share, size: 18),
                    label: Text(context.strings.stopScreenShare, style: const TextStyle(fontSize: 14)),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildParticipantGridPage(List<Widget> tiles) {
    if (tiles.isEmpty) return const SizedBox.shrink();

    if (tiles.length == 1) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: AspectRatio(
            aspectRatio: 9 / 16,
            child: tiles[0],
          ),
        ),
      );
    }

    if (tiles.length == 2) {
      return Padding(
        padding: const EdgeInsets.all(4),
        child: Column(
          children: [
            Expanded(child: tiles[0]),
            const SizedBox(height: 4),
            Expanded(child: tiles[1]),
          ],
        ),
      );
    }

    // 3 to 6 tiles grid (2 columns x up to 3 rows)
    return GridView.builder(
      padding: const EdgeInsets.all(4),
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
        childAspectRatio: tiles.length <= 4 ? 9 / 14 : 9 / 13,
      ),
      itemCount: tiles.length,
      itemBuilder: (context, index) => tiles[index],
    );
  }

  Widget _buildPageIndicator(int totalPages) {
    if (totalPages <= 1) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(totalPages, (i) {
          final isActive = i == _currentCarouselPage;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: isActive ? 16 : 6,
            height: 6,
            decoration: BoxDecoration(
              color: isActive ? AppColors.cyan : Colors.white.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(3),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildLocalTile({bool isCompact = false}) {
    final myVol = _userVolumeMap[widget.ticket.trtc.userId] ?? 0;
    final isSpeaking = myVol > 20;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF131826),
        borderRadius: BorderRadius.circular(isCompact ? 8 : 12),
        border: Border.all(
          color: isSpeaking ? AppColors.cyan : AppColors.cardBorder,
          width: isSpeaking ? 2 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Mount local camera ONLY when camera is ON and chat/exit is NOT open
          if (!_isCameraOff && !_isChatOpen && !_isExiting)
            Positioned.fill(
              child: TRTCCloudVideoView(
                key: ValueKey('local_camera_view_${isCompact ? "compact" : "grid"}'),
                onViewCreated: (viewId) {
                  _localViewId = viewId;
                  if (_trtcCloud != null) {
                    _trtcCloud?.startLocalPreview(_isFrontCamera, viewId);
                    _trtcCloud?.muteLocalVideo(TRTCVideoStreamType.big, false);
                  }
                },
              ),
            ),
          // When camera is muted, chat is open, or exiting, show avatar
          if (_isCameraOff || _isChatOpen || _isExiting)
            Positioned.fill(
              child: Container(
                color: const Color(0xFF131826),
                child: Center(
                  child: CircleAvatar(
                    radius: isCompact ? 18 : 36,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                    child: Text(
                      widget.displayName.characters.first.toUpperCase(),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: isCompact ? 14 : 26,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          // User label badge
          Positioned(
            left: isCompact ? 4 : 8,
            bottom: isCompact ? 4 : 8,
            right: isCompact ? 4 : null,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: isCompact ? 4 : 6, vertical: isCompact ? 2 : 3),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _isMicMuted ? Icons.mic_off : Icons.mic,
                    size: isCompact ? 10 : 12,
                    color: _isMicMuted ? AppColors.danger : AppColors.cyan,
                  ),
                  const SizedBox(width: 3),
                  Flexible(
                    child: Text(
                      '${widget.displayName} (${context.strings.meBadge})${_isHost ? " • ${context.strings.hostBadge}" : ""}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: isCompact ? 9 : 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRemoteTile(String userId, {bool isCompact = false}) {
    final hasVideo = _videoAvailableUsers.contains(userId);
    final isRemoteMicMuted = !_audioAvailableUsers.contains(userId);
    final vol = _userVolumeMap[userId] ?? 0;
    final isSpeaking = vol > 20;
    final displayName = _getDisplayNameForUser(userId);
    final initial = displayName.isNotEmpty ? displayName.characters.first.toUpperCase() : '?';
    final cleanRemote = userId.replaceAll('-', '');
    final isRemoteHost = cleanRemote == _currentHostUserId;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF131826),
        borderRadius: BorderRadius.circular(isCompact ? 8 : 12),
        border: Border.all(
          color: isSpeaking ? AppColors.cyan : AppColors.cardBorder,
          width: isSpeaking ? 2 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Mount remote video view ONLY when video is available and chat/exit is not active
          if (hasVideo && !_isChatOpen && !_isExiting)
            Positioned.fill(
              child: TRTCCloudVideoView(
                key: ValueKey('remote_video_${userId}_${isCompact ? "compact" : "grid"}'),
                onViewCreated: (viewId) {
                  _remoteUserViews[userId] = viewId;
                  _trtcCloud?.startRemoteView(userId, TRTCVideoStreamType.big, viewId);
                },
              ),
            ),
          if (!hasVideo || _isChatOpen || _isExiting)
            Positioned.fill(
              child: Container(
                color: const Color(0xFF131826),
                child: Center(
                  child: CircleAvatar(
                    radius: isCompact ? 18 : 36,
                    backgroundColor: AppColors.cyan.withValues(alpha: 0.15),
                    child: Text(
                      initial,
                      style: TextStyle(
                        color: AppColors.cyan,
                        fontSize: isCompact ? 14 : 26,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          // User label badge
          Positioned(
            left: isCompact ? 4 : 8,
            bottom: isCompact ? 4 : 8,
            right: isCompact ? 4 : null,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: isCompact ? 4 : 6, vertical: isCompact ? 2 : 3),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isRemoteMicMuted ? Icons.mic_off : Icons.mic,
                    size: isCompact ? 10 : 12,
                    color: isRemoteMicMuted ? AppColors.danger : AppColors.cyan,
                  ),
                  const SizedBox(width: 3),
                  Flexible(
                    child: Text(
                      '$displayName${isRemoteHost ? " • ${context.strings.hostBadge}" : ""}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: isCompact ? 9 : 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomControls(AppStrings strings) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      color: Colors.black.withValues(alpha: 0.85),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Mic Button
          Expanded(
            child: _ControlButton(
              icon: _isMicMuted ? Icons.mic_off : Icons.mic,
              label: _isMicMuted ? strings.micOff : strings.micOn,
              isActive: !_isMicMuted,
              onPressed: _toggleMic,
            ),
          ),
          // Camera Button
          Expanded(
            child: _ControlButton(
              icon: _isCameraOff ? Icons.videocam_off : Icons.videocam,
              label: _isCameraOff ? strings.videoOff : strings.videoOn,
              isActive: !_isCameraOff,
              onPressed: _toggleCamera,
            ),
          ),
          // Screen Share Button
          Expanded(
            child: _ControlButton(
              icon: _isSharingScreen ? Icons.stop_screen_share : Icons.screen_share,
              label: _isSharingScreen ? strings.stopScreenShare : strings.startScreenShare,
              isActive: _isSharingScreen,
              activeColor: AppColors.cyan,
              onPressed: _toggleScreenShare,
            ),
          ),
          // Chat Button
          Expanded(
            child: _ControlButton(
              icon: Icons.chat_bubble_outline,
              label: strings.chatTitle,
              onPressed: _openChatSheet,
            ),
          ),
          // Members List Button
          Expanded(
            child: _ControlButton(
              icon: Icons.people_outline,
              label: '${strings.membersTitle} (${_remoteParticipants.length + 1})',
              onPressed: _showMembersList,
            ),
          ),
        ],
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  const _ControlButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.isActive = false,
    this.activeColor = AppColors.primary,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool isActive;
  final Color activeColor;

  @override
  Widget build(BuildContext context) {
    final bg = isActive ? activeColor.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.08);
    final fg = isActive ? activeColor : Colors.white;

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onPressed,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: bg,
                shape: BoxShape.circle,
                border: Border.all(color: isActive ? activeColor.withValues(alpha: 0.5) : Colors.transparent),
              ),
              child: Icon(icon, color: fg, size: 20),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(color: fg, fontSize: 10, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

