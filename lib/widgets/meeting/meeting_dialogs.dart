import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';
import '../../theme/app_theme.dart';

class MeetingMemberItem {
  const MeetingMemberItem({
    required this.name,
    required this.isHost,
    required this.isMuted,
  });

  final String name;
  final bool isHost;
  final bool isMuted;
}

void showMeetingMembersSheet({
  required BuildContext context,
  required List<MeetingMemberItem> members,
  required AppStrings strings,
}) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.card,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (ctx) {
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
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
              ],
            ),
            const Divider(color: AppColors.cardBorder),
            ...members.map((m) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                      child: Text(
                        m.name.characters.first.toUpperCase(),
                        style: const TextStyle(color: AppColors.primaryLight, fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(
                              m.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: AppColors.text, fontSize: 14),
                            ),
                          ),
                          if (m.isHost) ...[
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
                      m.isMuted ? Icons.mic_off : Icons.mic,
                      size: 18,
                      color: m.isMuted ? AppColors.danger : AppColors.cyan,
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

void showLeaveOrEndMeetingDialog({
  required BuildContext context,
  required bool isHost,
  required bool hasRemoteParticipants,
  required VoidCallback onGuestLeave,
  required VoidCallback onHostEndForAll,
  required VoidCallback onHostTransferAndLeave,
  required VoidCallback onHostAloneLeave,
  required AppStrings strings,
}) {
  if (!isHost) {
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
              onGuestLeave();
            },
            child: Text(strings.leaveMeeting),
          ),
        ],
      ),
    );
    return;
  }

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
                  onHostEndForAll();
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
                  if (hasRemoteParticipants) {
                    onHostTransferAndLeave();
                  } else {
                    onHostAloneLeave();
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

void showConfirmAloneLeaveDialog({
  required BuildContext context,
  required VoidCallback onConfirmEnd,
  required AppStrings strings,
}) {
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
            onConfirmEnd();
          },
          child: Text(strings.leaveAndEnd),
        ),
      ],
    ),
  );
}

void showHostTransferSheet({
  required BuildContext context,
  required List<String> candidateUserIds,
  required String Function(String userId) getDisplayName,
  required Future<void> Function(String selectedUserId) onTransferAndLeave,
  required AppStrings strings,
}) {
  String? selectedUserId = candidateUserIds.firstOrNull;

  showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.card,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (ctx) => StatefulBuilder(
      builder: (context, setModalState) {
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
                    itemCount: candidateUserIds.length,
                    separatorBuilder: (_, __) => const Divider(color: AppColors.cardBorder, height: 1),
                    itemBuilder: (context, index) {
                      final uid = candidateUserIds[index];
                      final name = getDisplayName(uid);
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
                            await onTransferAndLeave(targetId);
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

