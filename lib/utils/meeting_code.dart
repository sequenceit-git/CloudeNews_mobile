final _joinPath = RegExp(r'join[/:]([A-Za-z0-9-]+)', caseSensitive: false);
final _codeQuery = RegExp(r'[?&]code=([A-Za-z0-9-]+)', caseSensitive: false);

/// Pulls the meeting code out of an invite link such as
/// `https://cloudmeet.sequenceit.software/join/849-210-994` or
/// `cloudmeet://join/849-210-994`. Returns null when [input] is not a link.
String? meetingCodeFromLink(String? input) {
  if (input == null) return null;
  final text = input.trim();
  final match = _joinPath.firstMatch(text) ?? _codeQuery.firstMatch(text);
  return match?.group(1);
}

/// Accepts either a bare meeting code or a pasted invite link.
String normalizeMeetingCode(String input) => meetingCodeFromLink(input) ?? input.trim();
