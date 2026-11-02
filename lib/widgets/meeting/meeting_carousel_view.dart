import 'package:flutter/material.dart';
import 'package:tencent_rtc_sdk/trtc_cloud_video_view.dart';

import '../../l10n/app_strings.dart';
import '../../theme/app_theme.dart';

class MeetingCarouselView extends StatelessWidget {
  const MeetingCarouselView({
    super.key,
    required this.controller,
    required this.currentPage,
    required this.onPageChanged,
    required this.isSharing,
    required this.sharerId,
    required this.isExiting,
    required this.isScreenShareFit,
    required this.onSubstreamViewCreated,
    required this.onStopScreenShare,
    required this.participantTiles,
    required this.strings,
  });

  final PageController controller;
  final int currentPage;
  final ValueChanged<int> onPageChanged;
  final bool isSharing;
  final String? sharerId;
  final bool isExiting;
  final bool isScreenShareFit;
  final void Function(int viewId) onSubstreamViewCreated;
  final VoidCallback onStopScreenShare;
  final List<Widget> participantTiles;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    const pageSize = 6;
    final participantPages = <Widget>[];

    for (int i = 0; i < participantTiles.length; i += pageSize) {
      final end = (i + pageSize).clamp(0, participantTiles.length);
      final chunk = participantTiles.sublist(i, end);
      participantPages.add(MeetingParticipantGridPage(tiles: chunk));
    }

    if (participantPages.isEmpty) {
      participantPages.add(MeetingParticipantGridPage(tiles: participantTiles));
    }

    final pages = <Widget>[
      if (isSharing)
        MeetingPresentationView(
          sharerId: sharerId,
          isExiting: isExiting,
          isScreenShareFit: isScreenShareFit,
          onSubstreamViewCreated: onSubstreamViewCreated,
          onStopScreenShare: onStopScreenShare,
          strings: strings,
        ),
      ...participantPages,
    ];

    return Column(
      children: [
        Expanded(
          child: PageView(
            controller: controller,
            onPageChanged: onPageChanged,
            children: pages,
          ),
        ),
        MeetingPageIndicator(
          totalPages: pages.length,
          currentPage: currentPage,
        ),
      ],
    );
  }
}

class MeetingPresentationView extends StatelessWidget {
  const MeetingPresentationView({
    super.key,
    required this.sharerId,
    required this.isExiting,
    required this.isScreenShareFit,
    required this.onSubstreamViewCreated,
    required this.onStopScreenShare,
    required this.strings,
  });

  final String? sharerId;
  final bool isExiting;
  final bool isScreenShareFit;
  final void Function(int viewId) onSubstreamViewCreated;
  final VoidCallback onStopScreenShare;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: (sharerId != null && !isExiting)
          ? TRTCCloudVideoView(
              key: ValueKey('substream_$sharerId'),
              onViewCreated: onSubstreamViewCreated,
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
                    strings.screenShareActive,
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.danger,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    ),
                    onPressed: onStopScreenShare,
                    icon: const Icon(Icons.stop_screen_share, size: 18),
                    label: Text(strings.stopScreenShare, style: const TextStyle(fontSize: 14)),
                  ),
                ],
              ),
            ),
    );
  }
}

class MeetingParticipantGridPage extends StatelessWidget {
  const MeetingParticipantGridPage({
    super.key,
    required this.tiles,
  });

  final List<Widget> tiles;

  @override
  Widget build(BuildContext context) {
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
}

class MeetingPageIndicator extends StatelessWidget {
  const MeetingPageIndicator({
    super.key,
    required this.totalPages,
    required this.currentPage,
  });

  final int totalPages;
  final int currentPage;

  @override
  Widget build(BuildContext context) {
    if (totalPages <= 1) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(totalPages, (i) {
          final isActive = i == currentPage;
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
}
