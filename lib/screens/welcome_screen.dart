import 'package:flutter/material.dart';

import '../l10n/language_scope.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../utils/meeting_code.dart';
import '../widgets/common_widgets.dart';
import 'host_login_screen.dart';
import 'pre_join_lobby_screen.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final _codeController = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    final strings = context.strings;
    final code = normalizeMeetingCode(_codeController.text);
    if (code.isEmpty) {
      setState(() => _error = strings.inputRequiredError);
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await ApiService.instance.validateMeeting(code);
      if (!result.valid) {
        if (mounted) setState(() => _error = result.reason ?? strings.roomNotFound);
        return;
      }
    } on ApiException {
      // Offline or a server hiccup: still let the guest try to join.
    } finally {
      if (mounted) setState(() => _loading = false);
    }

    if (!mounted) return;
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => PreJoinLobbyScreen(meetingCode: code)));
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const ScreenHeader(),
            Expanded(
              child: ScreenBody(
                children: [
                  const Center(child: BrandMark()),
                  const SizedBox(height: 12),
                  Text(
                    strings.appName,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.text, fontSize: 26, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    strings.tagline,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.35),
                  ),
                  const SizedBox(height: 24),
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        CardHeading(title: strings.joinMeetingTitle, description: strings.joinMeetingDesc),
                        LabeledField(
                          label: strings.meetingCodeLabel,
                          hint: strings.meetingCodeHint,
                          controller: _codeController,
                          textInputAction: TextInputAction.go,
                          onChanged: (_) {
                            if (_error != null) setState(() => _error = null);
                          },
                          onSubmitted: (_) => _continue(),
                        ),
                        ErrorText(_error),
                        PrimaryButton(
                          label: '${strings.nextStepBtn} →',
                          loading: _loading,
                          loadingLabel: strings.roomValidating,
                          onPressed: _continue,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 6,
                    children: [
                      Text(strings.hostPrompt, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                      TextButton(
                        onPressed: () => Navigator.of(context)
                            .push(MaterialPageRoute<void>(builder: (_) => const HostLoginScreen())),
                        child: Text(
                          strings.hostSignInLink,
                          style: const TextStyle(color: AppColors.cyan, fontSize: 13, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    strings.termsNotice,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.textDim, fontSize: 11, height: 1.45),
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
