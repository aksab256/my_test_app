// lib/utils/whatsapp_consent_state.dart
//
// Pure, dependency-free helpers for the «WhatsApp order notifications» card
// on the «My Account» screen (SellerSettingsScreen).
//
// Storage contract (existing mechanism ONLY — same `sellers/{sellerId}`
// document updated by `_updateSettings`, no new API or collection):
//   - `whatsappNumber`   : normalized E.164-like string (always with `+`).
//   - `whatsappOptIn`    : bool, true only after explicit consent + save.
//   - `whatsappOptInAt`  : server timestamp of the last enable (kept on
//                          disable so the consent history is auditable).
//
// The card must NEVER present notifications as active before a reliable
// save: [isWhatsappActive] reads the persisted document only, never the
// local draft toggle.

/// Normalizes a merchant-entered WhatsApp number to E.164-like `+...`,
/// or null when unusable. Accepts `+`, `00`, Egyptian local `01…`, and
/// bare digit strings (country code is then required to already be part
/// of the digits — the stored value always starts with `+`).
String? normalizeWhatsappNumber(dynamic raw) {
  if (raw == null) return null;
  var p = raw.toString().trim().replaceAll(RegExp(r'[\s\-().]'), '');
  if (p.isEmpty) return null;
  if (p.startsWith('+')) {
    final rest = p.substring(1);
    if (!RegExp(r'^\d{7,15}$').hasMatch(rest)) return null;
    return '+$rest';
  }
  if (p.startsWith('00')) {
    final rest = p.substring(2);
    if (!RegExp(r'^\d{7,15}$').hasMatch(rest)) return null;
    return '+$rest';
  }
  if (!RegExp(r'^\d+$').hasMatch(p)) return null;
  // Egyptian local forms → +20… (mirrors the pairing gateway).
  var local = p;
  if (local.startsWith('20') && local.length > 10) {
    local = '0${local.substring(2)}';
  }
  if (RegExp(r'^1\d{9}$').hasMatch(local)) local = '0$local';
  if (RegExp(r'^01\d{9}$').hasMatch(local)) {
    return '+20${local.substring(1)}';
  }
  if (local.length >= 7 && local.length <= 15) return '+$local';
  return null;
}

/// Server-truth check: notifications count as active ONLY when the persisted
/// seller document carries opt-in == true AND a valid stored number.
bool isWhatsappActive(Map<String, dynamic>? docData) {
  final data = docData ?? {};
  if (data['whatsappOptIn'] != true) return false;
  return normalizeWhatsappNumber(data['whatsappNumber']) != null;
}
