import 'package:flutter/material.dart';

import '../l10n/language_scope.dart';
import '../services/api_service.dart';
import '../services/meeting_launcher.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';

class PreJoinLobbyScreen extends StatefulWidget {
  const PreJoinLobbyScreen({super.key, required this.meetingCode, this.fromInviteLink = false});

  final String meetingCode;
  final bool fromInviteLink;

  @override
  State<PreJoinLobbyScreen> createState() => _PreJoinLobbyScreenState();
}

class _PreJoinLobbyScreenState extends State<PreJoinLobbyScreen> {
  final _nameController = TextEditingController();
  bool _microphoneOn = true;
  bool _cameraOn = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    final strings = context.strings;
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = strings.nameRequiredError);
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final ticket = await ApiService.instance.joinAsGuest(widget.meetingCode, name);
      if (!mounted) return;
      await MeetingLauncher.enter(
        context,
        ticket: ticket,
        displayName: name,
        microphoneOn: _microphoneOn,
        cameraOn: _cameraOn,
      );
      if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } on MeetingLaunchException catch (e) {
      if (mounted) setState(() => _error = '${strings.roomLoginFailed} (${e.code})');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            ScreenHeader(onBack: () => Navigator.of(context).maybePop()),
            Expanded(
              child: ScreenBody(
                children: [
                  _PreviewBox(
                    name: _nameController.text,
                    cameraOn: _cameraOn,
                    readyText: strings.cameraReady,
                    offText: strings.cameraOffNotice,
                  ),
                  const SizedBox(height: 20),
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: _CodeBadge(
                            label: widget.fromInviteLink ? strings.linkDetectedBadge : strings.roomPrefix,
                            code: widget.meetingCode,
                            fromLink: widget.fromInviteLink,
                          ),
                        ),
                        const SizedBox(height: 14),
                        CardHeading(title: strings.lobbyTitle, description: strings.lobbyDesc),
                        LabeledField(
                          label: strings.displayNameLabel,
                          hint: strings.displayNameHint,
                          controller: _nameController,
                          autofocus: true,
                          textCapitalization: TextCapitalization.words,
                          textInputAction: TextInputAction.go,
                          onChanged: (_) => setState(() => _error = null),
                          onSubmitted: (_) => _join(),
                        ),
                        Row(
                          children: [
                            DeviceToggle(
                              enabled: _microphoneOn,
                              onIcon: Icons.mic,
                              offIcon: Icons.mic_off,
                              onLabel: strings.micOn,
                              offLabel: strings.micOff,
                              onChanged: (value) => setState(() => _microphoneOn = value),
                            ),
                            const SizedBox(width: 10),
                            DeviceToggle(
                              enabled: _cameraOn,
                              onIcon: Icons.videocam,
                              offIcon: Icons.videocam_off,
                              onLabel: strings.videoOn,
                              offLabel: strings.videoOff,
                              onChanged: (value) => setState(() => _cameraOn = value),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        ErrorText(_error),
                        PrimaryButton(
                          label: strings.enterRoomBtn,
                          loading: _loading,
                          loadingLabel: strings.joiningNotice,
                          onPressed: _join,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewBox extends StatelessWidget {
  const _PreviewBox({required this.name, required this.cameraOn, required this.readyText, required this.offText});

  final String name;
  final bool cameraOn;
  final String readyText;
  final String offText;

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isEmpty ? '?' : name.trim().characters.first.toUpperCase();
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: cameraOn ? const Color(0xFF0D1527) : const Color(0xFF171E2E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 34,
            backgroundColor: Colors.white.withValues(alpha: 0.08),
            child: Text(initial,
                style: const TextStyle(color: AppColors.text, fontSize: 26, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(cameraOn ? Icons.videocam : Icons.videocam_off,
                  size: 16, color: cameraOn ? AppColors.cyan : AppColors.textSecondary),
              const SizedBox(width: 6),
              Text(
                cameraOn ? readyText : offText,
                style: TextStyle(
                  color: cameraOn ? AppColors.cyan : AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CodeBadge extends StatelessWidget {
  const _CodeBadge({required this.label, required this.code, required this.fromLink});

  final String label;
  final String code;
  final bool fromLink;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (fromLink) ...[
            const Icon(Icons.link, size: 14, color: AppColors.primaryLight),
            const SizedBox(width: 6),
          ],
          Text('$label: ',
              style: const TextStyle(color: AppColors.primaryLight, fontSize: 11, fontWeight: FontWeight.w600)),
          Text(code,
              style: const TextStyle(
                  color: AppColors.text, fontSize: 12, fontWeight: FontWeight.w700, fontFamily: 'monospace')),
        ],
      ),
    );
  }
}
