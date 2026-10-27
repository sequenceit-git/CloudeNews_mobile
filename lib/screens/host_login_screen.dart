import 'package:flutter/material.dart';

import '../l10n/language_scope.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import 'host_dashboard_screen.dart';

class HostLoginScreen extends StatefulWidget {
  const HostLoginScreen({super.key});

  @override
  State<HostLoginScreen> createState() => _HostLoginScreenState();
}

class _HostLoginScreenState extends State<HostLoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    final strings = context.strings;
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();
    if (username.isEmpty || password.isEmpty) {
      setState(() => _error = strings.authMissingFields);
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final host = await ApiService.instance.hostLogin(username, password);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => HostDashboardScreen(host: host)),
      );
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _clearError(String _) {
    if (_error != null) setState(() => _error = null);
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
                  Text(strings.hostLoginTitle,
                      style: const TextStyle(color: AppColors.text, fontSize: 26, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  Text(strings.hostLoginDesc,
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4)),
                  const SizedBox(height: 24),
                  AppCard(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        LabeledField(
                          label: strings.usernameLabel,
                          hint: strings.usernameHint,
                          controller: _usernameController,
                          textInputAction: TextInputAction.next,
                          onChanged: _clearError,
                        ),
                        LabeledField(
                          label: strings.passwordLabel,
                          hint: strings.passwordHint,
                          controller: _passwordController,
                          obscure: true,
                          textInputAction: TextInputAction.go,
                          onChanged: _clearError,
                          onSubmitted: (_) => _signIn(),
                        ),
                        ErrorText(_error),
                        PrimaryButton(label: strings.signInButton, loading: _loading, onPressed: _signIn),
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
