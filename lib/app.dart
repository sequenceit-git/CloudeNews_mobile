import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:tencent_chat_uikit/tencent_chat_uikit.dart' show ChatLocalizations;
import 'package:tencent_conference_uikit/tencent_conference_uikit.dart';
import 'package:tuikit_atomic_x/atomicx.dart'
    show AtomicLocalizations, ComponentTheme, LocaleProvider, ThemeState, ThemeType;

import 'l10n/app_strings.dart';
import 'l10n/language_scope.dart';
import 'screens/pre_join_lobby_screen.dart';
import 'screens/welcome_screen.dart';
import 'services/meeting_launcher.dart';
import 'theme/app_theme.dart';
import 'utils/meeting_code.dart';

class CloudNewsApp extends StatefulWidget {
  const CloudNewsApp({super.key});

  @override
  State<CloudNewsApp> createState() => _CloudNewsAppState();
}

class _CloudNewsAppState extends State<CloudNewsApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  final _language = LanguageController();
  final _themeState = ThemeState();
  final _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSubscription;

  @override
  void initState() {
    super.initState();
    _themeState.setThemeMode(ThemeType.dark);
    _linkSubscription = _appLinks.uriLinkStream.listen(_openInviteLink);
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    _language.dispose();
    super.dispose();
  }

  /// Invite links (`cloudmeet://join/<code>` or `https://<web>/join/<code>`)
  /// go straight to the pre-join lobby for that meeting.
  void _openInviteLink(Uri uri) {
    final code = meetingCodeFromLink(uri.toString());
    final navigator = _navigatorKey.currentState;
    if (code == null || navigator == null || MeetingLauncher.isInMeeting) return;
    navigator.popUntil((route) => route.isFirst);
    navigator.push(MaterialPageRoute<void>(
      builder: (_) => PreJoinLobbyScreen(meetingCode: code, fromInviteLink: true),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return LanguageScope(
      controller: _language,
      child: ChangeNotifierProvider(
        create: (_) => LocaleProvider(),
        child: ValueListenableBuilder<AppLanguage>(
          valueListenable: _language,
          builder: (context, language, _) => ComponentTheme(
            themeState: _themeState,
            child: MaterialApp(
              title: AppStrings.of(language).appName,
              debugShowCheckedModeBanner: false,
              navigatorKey: _navigatorKey,
              navigatorObservers: [RoomNavigatorObserver.instance],
              theme: AppTheme.dark,
              locale: language.locale,
              supportedLocales: const [Locale('en'), Locale('zh')],
              localizationsDelegates: const [
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
                ...RoomLocalizations.localizationsDelegates,
                ...BarrageLocalizations.localizationsDelegates,
                ChatLocalizations.delegate,
                AtomicLocalizations.delegate,
              ],
              builder: (context, child) => GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
                child: child,
              ),
              home: const WelcomeScreen(),
            ),
          ),
        ),
      ),
    );
  }
}
