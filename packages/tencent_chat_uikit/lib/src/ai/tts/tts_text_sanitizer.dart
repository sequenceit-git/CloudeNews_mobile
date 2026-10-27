import '../../emoji_picker/emoji_manager.dart';

/// Removes emoji from [text] so they are not spoken by TTS.
///
/// Handles both IM custom emoji tokens (e.g. `[微笑]`) and universal unicode
/// emoji, reusing [EmojiManager.findEmojiKeyListFromText] (regex-based, no
/// async/asset dependency).
String sanitizeTextForTts(String text) {
  if (text.isEmpty) return text;
  var result = text;
  for (final key in EmojiManager.findEmojiKeyListFromText(text)) {
    if (key.isEmpty) continue;
    result = result.replaceAll(key, '');
  }
  // Collapse whitespace left behind by removed emoji.
  result = result.replaceAll(RegExp(r'\s+'), ' ').trim();
  return result;
}
