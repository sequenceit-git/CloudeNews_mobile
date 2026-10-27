/// Build-time configuration. Override with
/// `--dart-define=API_BASE_URL=https://example.com/api/v1`.
class Env {
  Env._();

  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://cloudmeet.sequenceit.software/api/v1',
  );

  /// Public web origin used in invite links.
  static const String webOrigin = String.fromEnvironment(
    'WEB_ORIGIN',
    defaultValue: 'https://cloudmeet.sequenceit.software',
  );

  /// Fallback only; the server returns the SDKAppID with every UserSig.
  static const int trtcSdkAppId = int.fromEnvironment(
    'TRTC_SDK_APP_ID',
    defaultValue: 1600168815,
  );

  /// A host who stays alone in a meeting this long has it ended automatically.
  static const Duration soloMeetingTimeout = Duration(minutes: 20);
}
