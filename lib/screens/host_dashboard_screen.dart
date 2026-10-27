import 'package:atomic_x_core/atomicxcore.dart';
import 'package:flutter/material.dart';

import '../l10n/language_scope.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/meeting_launcher.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';

class HostDashboardScreen extends StatefulWidget {
  const HostDashboardScreen({super.key, required this.host});

  final HostUser host;

  @override
  State<HostDashboardScreen> createState() => _HostDashboardScreenState();
}

class _HostDashboardScreenState extends State<HostDashboardScreen> {
  bool _loading = false;
  String? _error;

  Future<void> _startMeeting() async {
    final strings = context.strings;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final ticket = await ApiService.instance.createInstantMeeting(strings.meetingTitleFor(widget.host.label));
      if (!mounted) return;
      await MeetingLauncher.enter(context, ticket: ticket, displayName: widget.host.label);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } on MeetingLaunchException catch (e) {
      if (mounted) setState(() => _error = '${strings.roomLoginFailed} (${e.code})');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _signOut() async {
    ApiService.instance.signOut();
    if (LoginStore.shared.loginState.loginStatus == LoginStatus.logined) {
      await LoginStore.shared.logout();
    }
    if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final name = widget.host.label;
    final initials = name.characters.take(2).toString().toUpperCase();

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.cardBorder))),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 21,
                      backgroundColor: AppColors.primary,
                      child: Text(initials,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(strings.welcomeGreeting,
                              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                          Text(name,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: AppColors.text, fontSize: 15, fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                    const LanguageSwitchButton(),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: _signOut,
                      icon: const Icon(Icons.logout, size: 15, color: AppColors.textSecondary),
                      label: Text(strings.signOut,
                          style: const TextStyle(
                              color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: 0.06),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ScreenBody(
                  children: [
                    AppCard(
                      padding: const EdgeInsets.all(28),
                      child: Column(
                        children: [
                          Container(
                            width: 68,
                            height: 68,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.videocam, size: 30, color: AppColors.primary),
                          ),
                          const SizedBox(height: 18),
                          Text(strings.instantMeetingTitle,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: AppColors.text, fontSize: 22, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 8),
                          Text(strings.instantMeetingDesc,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.45)),
                          const SizedBox(height: 24),
                          ErrorText(_error),
                          SizedBox(
                            width: double.infinity,
                            child: PrimaryButton(
                              label: strings.startInstantMeetingBtn,
                              loading: _loading,
                              onPressed: _startMeeting,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.cyan.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.cyan.withValues(alpha: 0.2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(strings.trtcStatusTitle,
                              style: const TextStyle(color: AppColors.cyan, fontSize: 13, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 4),
                          Text(strings.trtcStatusDesc,
                              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.45)),
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
