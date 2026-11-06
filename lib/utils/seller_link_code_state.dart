// lib/utils/seller_link_code_state.dart
//
// Pure, dependency-free classifier for the Rabia link code shown on the
// «My Account» screen. Mirrors the gateway contract
// (cashback/market_palce_intgrition/index.js `classifyLinkCodeState`):
// the canonical identity is the normalized phone, and the ONLY code field
// ever written by the gateway is `temp_link_code` (the legacy
// `integrationCode` fallback was removed: nothing ever writes it).
//
// States:
//   - available: a code exists and its 10-minute window is still valid.
//   - expired: a code exists but its window passed, or its expiry is
//     missing/unparseable (fail closed: force a fresh code).
//   - linkedConsumed: no code and the seller already verified the link
//     (the gateway deletes the code after a successful verify).
//   - unavailable: no code and no verified link.

enum SellerLinkCodeState {
  available,
  expired,
  linkedConsumed,
  unavailable,
}

class SellerLinkCodeView {
  final SellerLinkCodeState state;
  final String code;

  const SellerLinkCodeView(this.state, this.code);
}

/// Parses gateway expiry shapes (Firestore Timestamp, epoch millis, DateTime,
/// ISO-8601 string) to epoch millis, or null when unusable.
int? parseSellerLinkExpiryMs(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is double && value.isFinite) return value.toInt();
  if (value is DateTime) return value.millisecondsSinceEpoch;
  if (value is String) {
    final parsed = DateTime.tryParse(value);
    return parsed?.millisecondsSinceEpoch;
  }
  try {
    final dynamic millis = (value as dynamic).toMillis();
    if (millis is int) return millis;
    if (millis is double && millis.isFinite) return millis.toInt();
  } catch (_) {
    // Not a Timestamp-like object.
  }
  try {
    final dynamic date = (value as dynamic).toDate();
    if (date is DateTime) return date.millisecondsSinceEpoch;
  } catch (_) {
    // Not a Timestamp-like object.
  }
  if (value is Map) {
    final seconds = value['seconds'] ?? value['_seconds'];
    if (seconds is int) return seconds * 1000;
    if (seconds is double && seconds.isFinite) return (seconds * 1000).toInt();
  }
  return null;
}

/// Classifies the link-code display state for one `sellers` document snapshot.
/// Reads ONLY `temp_link_code` from the authorized session document.
SellerLinkCodeView classifySellerLinkCode(Map<String, dynamic>? docData, {DateTime? now}) {
  final data = docData ?? {};
  final rawValue = data['temp_link_code'];
  final raw = rawValue is String ? rawValue.trim() : '';
  if (raw.isEmpty) {
    if (data['erp_link_verified'] == true) {
      return const SellerLinkCodeView(SellerLinkCodeState.linkedConsumed, '');
    }
    return const SellerLinkCodeView(SellerLinkCodeState.unavailable, '');
  }
  final current = (now ?? DateTime.now()).millisecondsSinceEpoch;
  final expiryMs = parseSellerLinkExpiryMs(data['link_code_expires_at']);
  if (expiryMs == null || current > expiryMs) {
    return SellerLinkCodeView(SellerLinkCodeState.expired, raw);
  }
  return SellerLinkCodeView(SellerLinkCodeState.available, raw);
}
