/// Firestore document ids cannot contain arbitrary path chars.
String firestoreSafeDocId(String raw) {
  var s = raw.replaceAll(RegExp(r'[/\\]'), '_');
  s = s.replaceAll(RegExp(r'[#?.${}]'), '_');
  const maxLen = 700;
  if (s.length > maxLen) {
    return s.substring(0, maxLen);
  }
  return s.isEmpty ? 'unknown' : s;
}
