// lib/utils/rabia_webhook_setup.dart
//
// Pure, dependency-free helpers for the «Rabia orders Webhook» card on the
// «My Account» screen (SellerSettingsScreen).
//
// Contract mirror of the existing gateway
// (cashback/integrations_any_ERP/index.js):
//   - POST /webhooks creates `{sellerId, url, events, secret, active}` and
//     returns `secret` (`whsec_…`) exactly once.
//   - GET /webhooks NEVER returns `secret`.
//   - Only `order.created` and `order.status_updated` are subscribed for
//     Rabia (never `offer.updated`).
//
// The matcher below is the duplicate guard: a webhook counts as «the Rabia
// orders webhook» only when it is active, points at the Rabia receiver URL,
// and carries exactly the two order events.

/// Fixed Rabia receiver (single ingress). Must stay in sync with
/// `DEFAULT_RABIA_WEBHOOK_URL` in cashback/market_palce_intgrition/index.js.
const String kRabiaOrdersReceiverUrl =
    'https://us-central1-elhana3star.cloudfunctions.net/receiveAksabOrderWebhook';

/// Base URL of the existing integrations gateway (codebase `integrations-api`,
/// project `aksab-erp`). Reuses POST/GET/DELETE /webhooks as-is.
const String kIntegrationsApiBase =
    'https://us-central1-aksab-erp.cloudfunctions.net/api';

/// The only events the Rabia orders webhook may subscribe to.
const List<String> kRabiaOrdersEvents = <String>[
  'order.created',
  'order.status_updated',
];

/// Returns true when [entry] (one element of GET /webhooks `data`) is the
/// active Rabia orders webhook: active, correct URL, exactly the two order
/// events — no more, no less.
bool isRabiaOrdersWebhook(
  dynamic entry, {
  String url = kRabiaOrdersReceiverUrl,
  List<String> events = kRabiaOrdersEvents,
}) {
  if (entry is! Map) return false;
  if (entry['active'] != true) return false;
  if (entry['url']?.toString() != url) return false;
  final rawEvents = entry['events'];
  if (rawEvents is! List) return false;
  final actual = rawEvents.map((e) => e.toString()).toSet();
  if (actual.length != events.length) return false;
  return actual.containsAll(events);
}

/// First matching Rabia orders webhook in a GET /webhooks `data` list, or
/// null when none exists (creation is then allowed).
Map<String, dynamic>? findRabiaOrdersWebhook(
  List<dynamic> webhooks, {
  String url = kRabiaOrdersReceiverUrl,
  List<String> events = kRabiaOrdersEvents,
}) {
  for (final entry in webhooks) {
    if (isRabiaOrdersWebhook(entry, url: url, events: events)) {
      return Map<String, dynamic>.from(entry as Map);
    }
  }
  return null;
}
