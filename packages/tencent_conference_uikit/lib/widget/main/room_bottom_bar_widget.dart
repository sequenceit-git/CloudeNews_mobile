import 'dart:io';

import 'package:tuikit_atomic_x/atomicx.dart';
import 'package:flutter/material.dart' hide AlertDialog;
import 'package:tencent_conference_uikit/base/index.dart';

import 'room_widget/room_button_item_widget.dart';
import 'room_participant_list_widget.dart';
import 'ai_transcription/ai_action_sheet_widget/ai_action_sheet_widget.dart';

class RoomBottomBarWidget extends StatefulWidget {
  final String roomId;
  final Orientation orientation;
  final bool isAISubtitleVisible;
  final VoidCallback onEnableAISubtitle;
  final VoidCallback onDisableAISubtitle;
  final VoidCallback onOpenMinutes;
  final RoomChatPageBuilder? chatPageBuilder;

  const RoomBottomBarWidget({
    super.key,
    required this.roomId,
    required this.orientation,
    required this.isAISubtitleVisible,
    required this.onEnableAISubtitle,
    required this.onDisableAISubtitle,
    required this.onOpenMinutes,
    this.chatPageBuilder,
  });

  @override
  State<RoomBottomBarWidget> createState() => _RoomBottomBarWidgetState();
}

class _RoomBottomBarWidgetState extends State<RoomBottomBarWidget> {
  final _roomStore = RoomStore.shared;
  late final RoomParticipantStore _roomParticipantStore;

  @override
  void initState() {
    super.initState();
    _roomParticipantStore = RoomParticipantStore.create(widget.roomId);
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.roomId.isWebinar ? _buildWebinarContent() : _buildStandardContent();
  }

  double _bottomSafeSpacer() {
    final inset = MediaQuery.viewPaddingOf(context).bottom;
    if (widget.orientation == Orientation.landscape) {
      return 6 + inset;
    }
    // Keep Tencent's 24px gap when there is no system nav bar; otherwise
    // sit the buttons just above the 3-button / gesture inset.
    return inset > 0 ? inset + 8 : 24;
  }

  Widget _buildStandardContent() {
    final spacer = _bottomSafeSpacer();
    return Stack(
      children: [
        const Positioned.fill(child: ColoredBox(color: RoomColors.darkBlack)),
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildMemberButton(),
                    _buildMicrophoneButton(),
                    _buildCameraButton(),
                    _buildScreenShareButton(),
                    _buildAIToolsButton(),
                    if (widget.chatPageBuilder != null) _buildChatButton(),
                  ],
                ),
              ),
              SizedBox(height: spacer),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWebinarContent() {
    final localUserId = LoginStore.shared.loginState.loginUserInfo?.userID;
    return Row(
      children: [
        ValueListenableBuilder(
            valueListenable: _roomParticipantStore.state.participantList,
            builder: (context, participantList, child) {
              final isSelfInList = participantList.any((p) => p.userID == localUserId);
              if (isSelfInList) {
                return _buildMicrophoneButton();
              }
              return const SizedBox.shrink();
            }),
        SizedBox(width: 8.width),
        _buildMemberButton(),
      ],
    );
  }

  Widget _buildMemberButton() {
    return ValueListenableBuilder(
      valueListenable: _roomStore.state.currentRoom,
      builder: (context, currentRoom, _) {
        return RoomButtonItemWidget(
          iconPath: RoomImages.roomMember,
          text: widget.roomId.isWebinar
              ? RoomLocalizations.of(context)!.roomkit_member
              : RoomLocalizations.of(context)!
                  .roomkit_member_count
                  .replaceAll("xxx", (currentRoom?.participantCount ?? 0).toString()),
          onPressed: _handleMembersPressed,
          isWebinar: widget.roomId.isWebinar,
        );
      },
    );
  }

  Widget _buildMicrophoneButton() {
    return ListenableBuilder(
      listenable: Listenable.merge([
        _roomParticipantStore.state.localParticipant,
        _roomStore.state.currentRoom,
      ]),
      builder: (context, _) {
        final localParticipant = _roomParticipantStore.state.localParticipant.value;
        final isAllMicrophoneDisabled = _roomStore.state.currentRoom.value?.isAllMicrophoneDisabled;
        return RoomButtonItemWidget(
          iconPath: RoomImages.roomMicOff,
          selectedIconPath: RoomImages.roomMicOnEmpty,
          text: localParticipant?.microphoneStatus == DeviceStatus.on
              ? RoomLocalizations.of(context)!.roomkit_mute
              : RoomLocalizations.of(context)!.roomkit_unmute,
          isSelected: ValueNotifier(localParticipant?.microphoneStatus == DeviceStatus.on),
          onPressed: _handleMicToggle,
          opacity: isAllMicrophoneDisabled == true &&
                  localParticipant?.role == ParticipantRole.generalUser &&
                  localParticipant?.microphoneStatus == DeviceStatus.off
              ? 0.5
              : 1,
          isWebinar: widget.roomId.isWebinar,
        );
      },
    );
  }

  Widget _buildCameraButton() {
    return ListenableBuilder(
      listenable: Listenable.merge([
        _roomParticipantStore.state.localParticipant,
        _roomStore.state.currentRoom,
      ]),
      builder: (context, _) {
        final localParticipant = _roomParticipantStore.state.localParticipant.value;
        final isAllCameraDisabled = _roomStore.state.currentRoom.value?.isAllCameraDisabled;
        return RoomButtonItemWidget(
          iconPath: RoomImages.roomCameraOff,
          selectedIconPath: RoomImages.roomCameraOn,
          text: localParticipant?.cameraStatus == DeviceStatus.on
              ? RoomLocalizations.of(context)!.roomkit_stop_video
              : RoomLocalizations.of(context)!.roomkit_start_video,
          isSelected: ValueNotifier(localParticipant?.cameraStatus == DeviceStatus.on),
          onPressed: _handleCameraToggle,
          opacity: isAllCameraDisabled == true &&
                  localParticipant?.role == ParticipantRole.generalUser &&
                  localParticipant?.cameraStatus == DeviceStatus.off
              ? 0.5
              : 1,
        );
      },
    );
  }

  Widget _buildScreenShareButton() {
    final screenStatus = DeviceStore.shared.state.screenStatus;
    return ValueListenableBuilder<DeviceStatus>(
      valueListenable: screenStatus,
      builder: (context, status, _) {
        return RoomButtonItemWidget(
          iconPath: RoomImages.screenShare,
          text: status == DeviceStatus.on
              ? RoomLocalizations.of(context)!.roomkit_stop_screen_share
              : RoomLocalizations.of(context)!.roomkit_start_screen_share,
          onPressed: _handleScreenShareToggle,
        );
      },
    );
  }

  Future<void> _handleScreenShareToggle() async {
    final deviceStore = DeviceStore.shared;
    if (deviceStore.state.screenStatus.value == DeviceStatus.on) {
      deviceStore.stopScreenShare();
      return;
    }

    final localizations = RoomLocalizations.of(context)!;
    final localParticipant = _roomParticipantStore.state.localParticipant.value;
    final sharer = _roomParticipantStore.state.participantWithScreen.value;
    if (sharer != null && sharer.userID != localParticipant?.userID) {
      Toast.warning(context, localizations.roomkit_err_n1109_screen_share_start_failed, useRootOverlay: true);
      return;
    }
    if (_roomStore.state.currentRoom.value?.isAllScreenShareDisabled == true &&
        localParticipant?.role == ParticipantRole.generalUser) {
      Toast.warning(context, localizations.roomkit_err_n2373_screen_share_need_permission, useRootOverlay: true);
      return;
    }
    if (deviceStore.state.cameraStatus.value == DeviceStatus.on) {
      Toast.warning(context, localizations.roomkit_screen_share_blocked_by_camera, useRootOverlay: true);
      return;
    }
    deviceStore.startScreenShare(
      iOSAppGroup: Platform.isIOS ? 'group.com.cloudnews.app.ios' : '',
    );
    final pickerShown = await TencentConferenceUikitPlatform.instance.showScreenSharePicker();
    if (!pickerShown) {
      deviceStore.stopScreenShare();
      if (mounted) {
        Toast.warning(context, localizations.roomkit_err_n1109_screen_share_start_failed, useRootOverlay: true);
      }
    }
  }

  Widget _buildAIToolsButton() {
    return RoomButtonItemWidget(
      iconPath: RoomImages.aiTools,
      text: RoomLocalizations.of(context)!.roomkit_transcription_ai_tools,
      onPressed: _handleAIToggle,
    );
  }

  Widget _buildChatButton() {
    return RoomButtonItemWidget(
      iconPath: RoomImages.roomChat,
      text: RoomLocalizations.of(context)!.roomkit_chat,
      onPressed: _handleChatPressed,
    );
  }

  void _handleMembersPressed() {
    popupWidget(RoomParticipantListWidget(roomId: widget.roomId), backgroundColor: RoomColors.g2);
  }

  void _handleChatPressed() {
    final builder = widget.chatPageBuilder;
    if (builder == null) return;
    final media = MediaQuery.of(context);
    popupWidget(
      SizedBox(
        height: media.size.height,
        width: media.size.width,
        child: Padding(
          padding: EdgeInsets.only(top: media.padding.top),
          child: builder(widget.roomId),
        ),
      ),
      backgroundColor: RoomColors.darkBlack,
    );
  }

  void _handleCameraToggle() async {
    final currentStatus = _roomParticipantStore.state.localParticipant.value?.cameraStatus;

    if (currentStatus == DeviceStatus.on) {
      DeviceOperator.closeCamera();
    } else {
      DeviceOperator.openCamera(context);
    }
  }

  void _handleMicToggle() async {
    final currentStatus = _roomParticipantStore.state.localParticipant.value?.microphoneStatus;

    if (currentStatus == DeviceStatus.on) {
      DeviceOperator.muteMicrophone(_roomParticipantStore);
    } else {
      DeviceOperator.unmuteMicrophone(context: context, participantStore: _roomParticipantStore);
    }
  }

  void _handleAIToggle() async {
    popupWidget(
      AIActionSheetWidget(
        isAISubtitleVisible: widget.isAISubtitleVisible,
        onEnableAISubtitle: () {
          widget.onEnableAISubtitle();
        },
        onDisableAISubtitle: () {
          widget.onDisableAISubtitle();
        },
        onOpenMinutes: () {
          widget.onOpenMinutes();
        },
      ),
    );
  }
}
