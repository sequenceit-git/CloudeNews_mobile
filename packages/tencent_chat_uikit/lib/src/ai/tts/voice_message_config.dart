import 'package:tuikit_atomic_x/atomicx.dart';

/// Minimal key-value backend used by [VoiceMessageConfig].
///
/// Abstracted so tests can inject an in-memory fake instead of the
/// SharedPreferences-backed [StorageUtil].
abstract class VoiceConfigStore {
  Future<Object?> get(String key);
  Future<bool> set<T>(String key, T value);
  Future<bool> remove(String key);
}

class _StorageUtilStore implements VoiceConfigStore {
  const _StorageUtilStore();

  @override
  Future<Object?> get(String key) => StorageUtil.get(key);

  @override
  Future<bool> set<T>(String key, T value) => StorageUtil.set<T>(key, value);

  @override
  Future<bool> remove(String key) => StorageUtil.remove(key);
}

String _currentLoginUserId() {
  try {
    return LoginStore.shared.loginState.loginUserInfo?.userID ?? '';
  } catch (_) {
    return '';
  }
}

/// Per-user persisted configuration for the chat TTS suite.
///
/// Stores the record-translation target language (independent from the global
/// message translate target) and the selected TTS voice. Keys are namespaced
/// by the current login user id, mirroring iOS `TUITextToVoiceConfig`.
class VoiceMessageConfig {
  VoiceMessageConfig({
    VoiceConfigStore? store,
    String Function()? userIdProvider,
  })  : _store = store ?? const _StorageUtilStore(),
        _userIdProvider = userIdProvider ?? _currentLoginUserId;

  /// Shared instance used by the UI layer.
  static final VoiceMessageConfig instance = VoiceMessageConfig();

  final VoiceConfigStore _store;
  final String Function() _userIdProvider;

  static const String _kRecordTranslateLang =
      'voice_record_translate_target_language';
  static const String _kSelectedVoiceId = 'voice_selected_voice_id';
  static const String _kSelectedVoiceName = 'voice_selected_voice_name';

  String _recordTranslateTargetLanguage = '';
  String _selectedVoiceId = '';
  String _selectedVoiceName = '';

  String _userKey(String base) {
    final uid = _userIdProvider();
    return uid.isEmpty ? base : '${uid}_$base';
  }

  /// Load the current user's persisted values into memory. Call after login
  /// (or user switch) before reading the synchronous getters.
  Future<void> load() async {
    final lang = await _store.get(_userKey(_kRecordTranslateLang));
    final voiceId = await _store.get(_userKey(_kSelectedVoiceId));
    final voiceName = await _store.get(_userKey(_kSelectedVoiceName));
    _recordTranslateTargetLanguage = lang is String ? lang : '';
    _selectedVoiceId = voiceId is String ? voiceId : '';
    _selectedVoiceName = voiceName is String ? voiceName : '';
  }

  /// Record-translation target language code (empty when never set).
  String get recordTranslateTargetLanguage => _recordTranslateTargetLanguage;

  /// Selected TTS voice id (empty means the built-in "default" voice).
  String get selectedVoiceId => _selectedVoiceId;

  /// Selected TTS voice display name (empty when using the default voice).
  String get selectedVoiceName => _selectedVoiceName;

  Future<bool> setRecordTranslateTargetLanguage(String languageCode) async {
    _recordTranslateTargetLanguage = languageCode;
    return _store.set<String>(_userKey(_kRecordTranslateLang), languageCode);
  }

  Future<bool> setSelectedVoice({
    required String voiceId,
    required String name,
  }) async {
    _selectedVoiceId = voiceId;
    _selectedVoiceName = name;
    final ok1 = await _store.set<String>(_userKey(_kSelectedVoiceId), voiceId);
    final ok2 = await _store.set<String>(_userKey(_kSelectedVoiceName), name);
    return ok1 && ok2;
  }
}
