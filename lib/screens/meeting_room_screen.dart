import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:tencent_rtc_sdk/trtc_cloud.dart';
import 'package:tencent_rtc_sdk/trtc_cloud_def.dart';
import 'package:tencent_rtc_sdk/trtc_cloud_listener.dart';
import 'package:tencent_rtc_sdk/trtc_cloud_video_view.dart';
import 'package:tencent_rtc_sdk/tx_device_manager.dart';

import '../config/env.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../widgets/room_chat_page.dart';

enum MeetingExit { left, hostEnded, remoteEnded }

class MeetingRoomScreen extends StatefulWidget {
  const MeetingRoomScreen({
    super.key,
    required this.ticket,
    required this.displayName,
    required this.microphoneOn,
    required this.cameraOn,
  });

  final MeetingTicket ticket;
  final String displayName;
  final bool microphoneOn;
  final bool cameraOn;

  @override
  State<MeetingRoomScreen> createState() => _MeetingRoomScreenState();
}

class _RemoteSeat {
  bool video = false;
}

class _MeetingRoomScreenState extends State<MeetingRoomScreen> {
  static const _pageSize = 6;

  TRTCCloud? _cloud;
  TRTCCloudListener? _listener;
  Timer? _soloTimer;
  MeetingChatController? _chat;
  Completer<void>? _leftRoom;
  var _entered = false;
  var _closing = false;
  var _micOn = false;
  var _cameraOn = false;
  var _sharing = false;
  var _page = 0;
  int? _localViewId;
  String? _screenUserId;
  String? _error;
  final _remotes = <String, _RemoteSeat>{};

  String get _roomDigits => widget.ticket.trtc.roomId;
  bool get _isHost => widget.ticket.trtc.isHost;

  @override
  void initState() {
    super.initState();
    _micOn = widget.microphoneOn;
    _cameraOn = widget.cameraOn;
    _chat = MeetingChatController(
      ticket: widget.ticket,
      displayName: widget.displayName,
      onMeetingEnded: () => _finish(MeetingExit.remoteEnded),
    )..connect();
    _join();
  }

  Future<void> _join() async {
    final cloud = await TRTCCloud.sharedInstance();
    final listener = TRTCCloudListener(
      onEnterRoom: (result) {
        if (!mounted) return;
        if (result <= 0) {
          setState(() => _error = 'Could not enter the room ($result)');
          return;
        }
        setState(() => _entered = true);
        _applyDevices();
        _armSoloTimer();
      },
      onExitRoom: (_) {
        final pending = _leftRoom;
        if (pending != null && !pending.isCompleted) pending.complete();
      },
      onError: (code, message) {
        if (mounted && code < 0) setState(() => _error = message);
      },
      onRemoteUserEnterRoom: (userId) {
        if (!mounted) return;
        setState(() => _remotes.putIfAbsent(userId, () => _RemoteSeat()));
        _armSoloTimer();
      },
      onRemoteUserLeaveRoom: (userId, reason) {
        if (!mounted) return;
        setState(() {
          _remotes.remove(userId);
          if (_screenUserId == userId) _screenUserId = null;
        });
        _armSoloTimer();
      },
      onUserVideoAvailable: (userId, available) {
        if (!mounted) return;
        setState(() {
          _remotes.putIfAbsent(userId, () => _RemoteSeat()).video = available;
        });
      },
      onUserSubStreamAvailable: (userId, available) {
        if (!mounted) return;
        setState(() => _screenUserId = available ? userId : (_screenUserId == userId ? null : _screenUserId));
      },
    );
    cloud.registerListener(listener);
    cloud.enterRoom(
      TRTCParams(
        sdkAppId: widget.ticket.trtc.sdkAppId != 0 ? widget.ticket.trtc.sdkAppId : Env.trtcSdkAppId,
        userId: widget.ticket.trtc.userId,
        userSig: widget.ticket.trtc.userSig,
        roomId: int.tryParse(_roomDigits) ?? 0,
        role: TRTCRoleType.anchor,
      ),
      TRTCAppScene.videoCall,
    );
    if (!mounted) return;
    setState(() {
      _cloud = cloud;
      _listener = listener;
    });
  }

  void _applyDevices() {
    final cloud = _cloud;
    if (cloud == null || !_entered) return;
    cloud.getDeviceManager().setAudioRoute(TXAudioRoute.speakerPhone);
    if (_micOn) {
      cloud.startLocalAudio(TRTCAudioQuality.speech);
    }
    _publishLocalPreview();
  }

  void _publishLocalPreview() {
    final cloud = _cloud;
    final viewId = _localViewId;
    if (cloud == null || !_entered || viewId == null) return;
    cloud.setLocalRenderParams(TRTCRenderParams(
      fillMode: TRTCVideoFillMode.fill,
      mirrorType: TRTCVideoMirrorType.auto,
    ));
    if (_cameraOn && !_sharing) {
      cloud.startLocalPreview(true, viewId);
    }
  }

  void _armSoloTimer() {
    _soloTimer?.cancel();
    _soloTimer = null;
    if (!_isHost || _remotes.isNotEmpty) return;
    _soloTimer = Timer(Env.soloMeetingTimeout, () {
      _finish(MeetingExit.hostEnded);
    });
  }

  Future<void> _toggleMic() async {
    final cloud = _cloud;
    if (cloud == null) return;
    final next = !_micOn;
    if (next) {
      cloud.startLocalAudio(TRTCAudioQuality.speech);
    } else {
      cloud.stopLocalAudio();
    }
    setState(() => _micOn = next);
  }

  Future<void> _toggleCamera() async {
    final cloud = _cloud;
    if (cloud == null || _sharing) return;
    final next = !_cameraOn;
    if (next) {
      final viewId = _localViewId;
      if (viewId != null) cloud.startLocalPreview(true, viewId);
    } else {
      cloud.stopLocalPreview();
    }
    setState(() => _cameraOn = next);
  }

  Future<void> _toggleShare() async {
    final cloud = _cloud;
    if (cloud == null) return;
    if (_sharing) {
      cloud.stopScreenCapture();
      setState(() => _sharing = false);
      if (_cameraOn) _publishLocalPreview();
      return;
    }
    if (_screenUserId != null && _screenUserId != widget.ticket.trtc.userId) {
      setState(() => _error = 'Someone else is sharing');
      return;
    }
    if (_cameraOn) {
      cloud.stopLocalPreview();
      setState(() => _cameraOn = false);
    }
    final enc = TRTCVideoEncParam(
      videoResolution: TRTCVideoResolution.res_1280_720,
      videoResolutionMode: TRTCVideoResolutionMode.landscape,
      videoFps: 10,
      videoBitrate: 1600,
    );
    if (Platform.isIOS) {
      cloud.startScreenCaptureByReplaykit(TRTCVideoStreamType.sub, enc, 'group.com.cloudnews.app.ios');
    } else {
      cloud.startScreenCapture(null, TRTCVideoStreamType.sub, enc);
    }
    setState(() => _sharing = true);
  }

  List<String> get _pageIds {
    final ids = _remotes.keys.toList();
    final start = _page * _pageSize;
    if (start >= ids.length) return const [];
    final end = start + _pageSize;
    return ids.sublist(start, end > ids.length ? ids.length : end);
  }

  int get _pageCount {
    final count = (_remotes.length / _pageSize).ceil();
    return count < 1 ? 1 : count;
  }

  Future<void> _finish(MeetingExit reason) async {
    if (_closing) return;
    _closing = true;
    _soloTimer?.cancel();
    final cloud = _cloud;
    if (cloud != null && _entered) {
      final left = Completer<void>();
      _leftRoom = left;
      cloud.exitRoom();
      await left.future.timeout(const Duration(seconds: 3), onTimeout: () {});
    }
    final listener = _listener;
    if (cloud != null && listener != null) cloud.unRegisterListener(listener);
    _chat?.dispose();
    _chat = null;
    if (!mounted) return;
    final navigator = Navigator.of(context);
    navigator.popUntil((route) => route.settings.name == '/meeting-room' || route.isFirst);
    if (navigator.canPop()) navigator.pop(reason);
  }

  Future<void> _askLeave() async {
    final end = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_isHost ? 'Leave meeting?' : 'Leave meeting?'),
        content: Text(_isHost ? 'End the meeting for everyone, or just leave.' : 'You can rejoin with the meeting code.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Leave')),
          if (_isHost) TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('End')),
        ],
      ),
    );
    if (end == null) return;
    await _finish(end ? MeetingExit.hostEnded : MeetingExit.left);
  }

  void _openChat() {
    final chat = _chat;
    if (chat == null) return;
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => RoomChatPage(chat: chat),
    ));
  }

  void _showMembers() {
    final names = [widget.displayName, ..._remotes.keys];
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.card,
      builder: (context) => ListView(
        children: [
          const ListTile(title: Text('Members')),
          for (final name in names) ListTile(title: Text(name)),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _soloTimer?.cancel();
    _chat?.dispose();
    final cloud = _cloud;
    final listener = _listener;
    if (cloud != null && listener != null) cloud.unRegisterListener(listener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tiles = _pageIds;
    final sharing = _screenUserId != null && _page == 0;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _askLeave();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0F1014),
        body: SafeArea(
          child: Column(
            children: [
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(_error!, style: const TextStyle(color: AppColors.danger)),
                ),
              Expanded(
                child: sharing
                    ? _RemoteView(userId: _screenUserId!, stream: TRTCVideoStreamType.sub, cloud: _cloud)
                    : GridView.count(
                        crossAxisCount: 2,
                        children: [
                          for (final userId in tiles)
                            _RemoteView(
                              userId: userId,
                              stream: TRTCVideoStreamType.big,
                              cloud: _cloud,
                              active: _remotes[userId]?.video == true,
                            ),
                        ],
                      ),
              ),
              if (_pageCount > 1)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      onPressed: _page > 0 ? () => setState(() => _page -= 1) : null,
                      icon: const Icon(Icons.chevron_left),
                    ),
                    Text('${_page + 1} / $_pageCount'),
                    IconButton(
                      onPressed: _page < _pageCount - 1 ? () => setState(() => _page += 1) : null,
                      icon: const Icon(Icons.chevron_right),
                    ),
                  ],
                ),
              SizedBox(
                height: 120,
                child: TRTCCloudVideoView(
                  onViewCreated: (viewId) {
                    _localViewId = viewId;
                    _publishLocalPreview();
                  },
                ),
              ),
              _Bar(
                micOn: _micOn,
                cameraOn: _cameraOn,
                sharing: _sharing,
                onMembers: _showMembers,
                onMic: _toggleMic,
                onCamera: _toggleCamera,
                onShare: _toggleShare,
                onChat: _openChat,
                onLeave: _askLeave,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RemoteView extends StatefulWidget {
  const _RemoteView({
    required this.userId,
    required this.stream,
    required this.cloud,
    this.active = true,
  });

  final String userId;
  final TRTCVideoStreamType stream;
  final TRTCCloud? cloud;
  final bool active;

  @override
  State<_RemoteView> createState() => _RemoteViewState();
}

class _RemoteViewState extends State<_RemoteView> {
  int? _viewId;

  void _bind() {
    final cloud = widget.cloud;
    final viewId = _viewId;
    if (cloud == null || viewId == null || !widget.active) return;
    cloud.startRemoteView(widget.userId, widget.stream, viewId);
  }

  @override
  void didUpdateWidget(covariant _RemoteView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId || oldWidget.active != widget.active) _bind();
  }

  @override
  void dispose() {
    widget.cloud?.stopRemoteView(widget.userId, widget.stream);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active) {
      return ColoredBox(
        color: AppColors.card,
        child: Center(child: Text(widget.userId, style: const TextStyle(color: AppColors.textSecondary))),
      );
    }
    return TRTCCloudVideoView(onViewCreated: (viewId) {
      _viewId = viewId;
      _bind();
    });
  }
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.micOn,
    required this.cameraOn,
    required this.sharing,
    required this.onMembers,
    required this.onMic,
    required this.onCamera,
    required this.onShare,
    required this.onChat,
    required this.onLeave,
  });

  final bool micOn;
  final bool cameraOn;
  final bool sharing;
  final VoidCallback onMembers;
  final VoidCallback onMic;
  final VoidCallback onCamera;
  final VoidCallback onShare;
  final VoidCallback onChat;
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFF0F1014),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _Button(icon: Icons.people_outline, label: 'Members', onPressed: onMembers),
          _Button(icon: micOn ? Icons.mic : Icons.mic_off, label: 'Mic', onPressed: onMic),
          _Button(icon: cameraOn ? Icons.videocam : Icons.videocam_off, label: 'Camera', onPressed: onCamera),
          _Button(icon: sharing ? Icons.stop_screen_share : Icons.screen_share, label: 'Share', onPressed: onShare),
          _Button(icon: Icons.chat_bubble_outline, label: 'Chat', onPressed: onChat),
          _Button(icon: Icons.call_end, label: 'Leave', onPressed: onLeave, color: AppColors.danger),
        ],
      ),
    );
  }
}

class _Button extends StatelessWidget {
  const _Button({required this.icon, required this.label, required this.onPressed, this.color});

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tint = color ?? AppColors.text;
    return InkWell(
      onTap: onPressed,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: tint, size: 22),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(color: tint, fontSize: 10)),
          ],
        ),
      ),
    );
  }
}
