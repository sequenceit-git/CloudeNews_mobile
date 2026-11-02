import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';
import '../../theme/app_theme.dart';

class MeetingTopBar extends StatelessWidget {
  const MeetingTopBar({
    super.key,
    required this.meetingCode,
    required this.elapsedFormatted,
    required this.isSpeakerPhone,
    required this.isCameraOff,
    required this.hasSubstream,
    required this.isScreenShareFit,
    required this.onCopyMeetingCode,
    required this.onToggleAudioRoute,
    required this.onFlipCamera,
    required this.onToggleScreenShareFit,
    required this.onPromptLeaveOrEnd,
    required this.strings,
  });

  final String meetingCode;
  final String elapsedFormatted;
  final bool isSpeakerPhone;
  final bool isCameraOff;
  final bool hasSubstream;
  final bool isScreenShareFit;
  final VoidCallback onCopyMeetingCode;
  final VoidCallback onToggleAudioRoute;
  final VoidCallback onFlipCamera;
  final VoidCallback onToggleScreenShareFit;
  final VoidCallback onPromptLeaveOrEnd;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.background.withValues(alpha: 0.95),
        border: const Border(bottom: BorderSide(color: AppColors.cardBorder, width: 0.5)),
      ),
      child: Row(
        children: [
          // Live status indicator dot
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: AppColors.cyan,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          // Elapsed meeting duration timer
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
                  elapsedFormatted,
                  style: const TextStyle(
                    color: AppColors.text,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          // Meeting code (1-tap copy)
          InkWell(
            onTap: onCopyMeetingCode,
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
                    meetingCode,
                    style: const TextStyle(
                      color: AppColors.primaryLight,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'monospace',
                    ),
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
            icon: Icon(isSpeakerPhone ? Icons.volume_up : Icons.phone_in_talk, color: Colors.white, size: 20),
            onPressed: onToggleAudioRoute,
            tooltip: isSpeakerPhone ? strings.speakerOn : strings.earpieceOn,
          ),
          // Flip Camera
          if (!isCameraOff)
            IconButton(
              icon: const Icon(Icons.cameraswitch, color: Colors.white, size: 20),
              onPressed: onFlipCamera,
              tooltip: strings.switchCamera,
            ),
          // Fit / Fill toggle during screen share
          if (hasSubstream)
            IconButton(
              icon: Icon(
                isScreenShareFit ? Icons.fit_screen : Icons.fullscreen,
                color: Colors.white,
                size: 20,
              ),
              onPressed: onToggleScreenShareFit,
              tooltip: isScreenShareFit ? 'Fit to Screen' : 'Fill Screen',
            ),
          // Leave / End button
          IconButton(
            icon: const Icon(Icons.call_end, color: AppColors.danger, size: 24),
            onPressed: onPromptLeaveOrEnd,
          ),
        ],
      ),
    );
  }
}
