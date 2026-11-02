import 'package:flutter/material.dart';
import 'package:tencent_rtc_sdk/trtc_cloud_video_view.dart';

import '../../l10n/app_strings.dart';
import '../../theme/app_theme.dart';

class MeetingLocalTile extends StatelessWidget {
  const MeetingLocalTile({
    super.key,
    required this.displayName,
    required this.isHost,
    required this.isMicMuted,
    required this.isCameraOff,
    required this.isChatOpen,
    required this.isExiting,
    required this.isSpeaking,
    this.isCompact = false,
    required this.onViewCreated,
    required this.strings,
  });

  final String displayName;
  final bool isHost;
  final bool isMicMuted;
  final bool isCameraOff;
  final bool isChatOpen;
  final bool isExiting;
  final bool isSpeaking;
  final bool isCompact;
  final void Function(int viewId) onViewCreated;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
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
          if (!isCameraOff && !isChatOpen && !isExiting)
            Positioned.fill(
              child: TRTCCloudVideoView(
                key: ValueKey('local_camera_view_${isCompact ? "compact" : "grid"}'),
                onViewCreated: onViewCreated,
              ),
            ),
          // When camera is muted, chat is open, or exiting, show avatar
          if (isCameraOff || isChatOpen || isExiting)
            Positioned.fill(
              child: Container(
                color: const Color(0xFF131826),
                child: Center(
                  child: CircleAvatar(
                    radius: isCompact ? 18 : 36,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                    child: Text(
                      displayName.isNotEmpty ? displayName.characters.first.toUpperCase() : '?',
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
                    isMicMuted ? Icons.mic_off : Icons.mic,
                    size: isCompact ? 10 : 12,
                    color: isMicMuted ? AppColors.danger : AppColors.cyan,
                  ),
                  const SizedBox(width: 3),
                  Flexible(
                    child: Text(
                      '$displayName (${strings.meBadge})${isHost ? " • ${strings.hostBadge}" : ""}',
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
}

class MeetingRemoteTile extends StatelessWidget {
  const MeetingRemoteTile({
    super.key,
    required this.userId,
    required this.displayName,
    required this.isHost,
    required this.isRemoteMicMuted,
    required this.hasVideo,
    required this.isChatOpen,
    required this.isExiting,
    required this.isSpeaking,
    this.isCompact = false,
    required this.onViewCreated,
    required this.strings,
  });

  final String userId;
  final String displayName;
  final bool isHost;
  final bool isRemoteMicMuted;
  final bool hasVideo;
  final bool isChatOpen;
  final bool isExiting;
  final bool isSpeaking;
  final bool isCompact;
  final void Function(int viewId) onViewCreated;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final initial = displayName.isNotEmpty ? displayName.characters.first.toUpperCase() : '?';

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
          if (hasVideo && !isChatOpen && !isExiting)
            Positioned.fill(
              child: TRTCCloudVideoView(
                key: ValueKey('remote_video_${userId}_${isCompact ? "compact" : "grid"}'),
                onViewCreated: onViewCreated,
              ),
            ),
          if (!hasVideo || isChatOpen || isExiting)
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
                      '$displayName${isHost ? " • ${strings.hostBadge}" : ""}',
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
}

