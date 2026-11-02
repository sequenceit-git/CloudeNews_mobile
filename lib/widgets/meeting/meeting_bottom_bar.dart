import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';
import '../../theme/app_theme.dart';
import 'meeting_control_button.dart';

class MeetingBottomBar extends StatelessWidget {
  const MeetingBottomBar({
    super.key,
    required this.isMicMuted,
    required this.isCameraOff,
    required this.isSharingScreen,
    required this.hasUnreadChat,
    required this.unreadChatCount,
    required this.participantCount,
    required this.onToggleMic,
    required this.onToggleCamera,
    required this.onToggleScreenShare,
    required this.onOpenChat,
    required this.onShowMembers,
    required this.strings,
  });

  final bool isMicMuted;
  final bool isCameraOff;
  final bool isSharingScreen;
  final bool hasUnreadChat;
  final int unreadChatCount;
  final int participantCount;
  final VoidCallback onToggleMic;
  final VoidCallback onToggleCamera;
  final VoidCallback onToggleScreenShare;
  final VoidCallback onOpenChat;
  final VoidCallback onShowMembers;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      color: Colors.black.withValues(alpha: 0.85),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Mic Button
          Expanded(
            child: MeetingControlButton(
              icon: isMicMuted ? Icons.mic_off : Icons.mic,
              label: isMicMuted ? strings.micOff : strings.micOn,
              isActive: !isMicMuted,
              onPressed: onToggleMic,
            ),
          ),
          // Camera Button
          Expanded(
            child: MeetingControlButton(
              icon: isCameraOff ? Icons.videocam_off : Icons.videocam,
              label: isCameraOff ? strings.videoOff : strings.videoOn,
              isActive: !isCameraOff,
              onPressed: onToggleCamera,
            ),
          ),
          // Screen Share Button
          Expanded(
            child: MeetingControlButton(
              icon: isSharingScreen ? Icons.stop_screen_share : Icons.screen_share,
              label: isSharingScreen ? strings.stopScreenShare : strings.startScreenShare,
              isActive: isSharingScreen,
              activeColor: AppColors.cyan,
              onPressed: onToggleScreenShare,
            ),
          ),
          // Chat Button
          Expanded(
            child: MeetingControlButton(
              icon: Icons.chat_bubble_outline,
              label: strings.chatTitle,
              onPressed: onOpenChat,
              hasBadge: hasUnreadChat,
              badgeCount: unreadChatCount,
            ),
          ),
          // Members List Button
          Expanded(
            child: MeetingControlButton(
              icon: Icons.people_outline,
              label: '${strings.membersTitle} ($participantCount)',
              onPressed: onShowMembers,
            ),
          ),
        ],
      ),
    );
  }
}
