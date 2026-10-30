// lib/utils/phone_format.dart
// Pure-Dart Egyptian mobile → Akedly 20-form for /send, tx binding and
// identity lookup. Canonical rule — mirrors backend akedly.js normalizePhone:
//   1. trim + strip whitespace, strip ONE leading '+' (+20… → 20…);
//   2. strip non-digits, strip ONE leading '00' (0020… → 20…);
//   3. local '0…' → '20' + rest; '20…' stays; anything else gets '20' + digits
//      (backend length/regex gates still apply server-side).
// Pure Dart, no Flutter dependency — unit-testable.
String formatPhoneToAkedly20(String phone) {
  var cleaned = phone.trim().replaceAll(RegExp(r'\s+'), '');
  if (cleaned.startsWith('+')) cleaned = cleaned.substring(1);
  var digits = cleaned.replaceAll(RegExp(r'\D'), '');
  if (digits.startsWith('00')) digits = digits.substring(2);
  if (digits.startsWith('0')) {
    return '20${digits.substring(1)}';
  }
  if (digits.startsWith('20')) return digits;
  return '20$digits';
}
