// test/rabia_webhook_setup_test.dart
//
// Focused regression tests for the «Rabia orders Webhook» duplicate guard on
// the «My Account» screen: only an ACTIVE webhook pointing at the Rabia
// receiver with EXACTLY order.created + order.status_updated counts, so the
// UI never creates a duplicate and never mistakes another integration's
// webhook for Rabia's.
import 'package:flutter_test/flutter_test.dart';
import 'package:my_test_app/utils/rabia_webhook_setup.dart';

Map<String, dynamic> entry({
  bool active = true,
  String url = kRabiaOrdersReceiverUrl,
  List<String> events = kRabiaOrdersEvents,
  String id = 'wh_1',
}) {
  return <String, dynamic>{
    'webhookId': id,
    'url': url,
    'events': List<String>.from(events),
    'active': active,
  };
}

void main() {
  group('isRabiaOrdersWebhook', () {
    test('exact match counts', () {
      expect(isRabiaOrdersWebhook(entry()), isTrue);
    });

    test('inactive webhook does not count', () {
      expect(isRabiaOrdersWebhook(entry(active: false)), isFalse);
    });

    test('different URL does not count', () {
      expect(
        isRabiaOrdersWebhook(entry(url: 'https://example.com/hook')),
        isFalse,
      );
    });

    test('extra event (offer.updated) does not count', () {
      expect(
        isRabiaOrdersWebhook(
          entry(events: [...kRabiaOrdersEvents, 'offer.updated']),
        ),
        isFalse,
      );
    });

    test('partial events do not count', () {
      expect(isRabiaOrdersWebhook(entry(events: ['order.created'])), isFalse);
    });

    test('missing or malformed events do not count', () {
      expect(isRabiaOrdersWebhook({'active': true, 'url': kRabiaOrdersReceiverUrl}), isFalse);
      expect(
        isRabiaOrdersWebhook({
          'active': true,
          'url': kRabiaOrdersReceiverUrl,
          'events': 'order.created',
        }),
        isFalse,
      );
    });

    test('non-map entry does not count', () {
      expect(isRabiaOrdersWebhook(null), isFalse);
      expect(isRabiaOrdersWebhook('whsec_x'), isFalse);
    });
  });

  group('findRabiaOrdersWebhook', () {
    test('returns first match and ignores others', () {
      final other = entry(url: 'https://third-party.example/hook', id: 'wh_x');
      final rabia = entry(id: 'wh_rabia');
      final found = findRabiaOrdersWebhook([other, rabia]);
      expect(found?['webhookId'], 'wh_rabia');
    });

    test('returns null when list has no match', () {
      expect(findRabiaOrdersWebhook([]), isNull);
      expect(
        findRabiaOrdersWebhook([entry(active: false)]),
        isNull,
      );
    });
  });
}
