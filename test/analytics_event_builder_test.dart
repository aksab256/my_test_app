// Phase 1: unit tests for the pure-Dart analytics payload builder and
// session helper. No Flutter widgets, no Firebase — safe for `flutter test`.
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_test_app/services/analytics_service.dart';

void main() {
  group('AnalyticsEventBuilder', () {
    test('truncateTerm trims and bounds search text (PII/volume guard)', () {
      expect(AnalyticsEventBuilder.truncateTerm('  قهوة  '), 'قهوة');
      final long = List.filled(150, 'x').join();
      final out = AnalyticsEventBuilder.truncateTerm(long);
      expect(out.length, AnalyticsEventBuilder.maxSearchTermLength);
    });

    test('numOrZero/intOrZero coerce defensively', () {
      expect(AnalyticsEventBuilder.numOrZero(5), 5.0);
      expect(AnalyticsEventBuilder.numOrZero('3.5'), 3.5);
      expect(AnalyticsEventBuilder.numOrZero(null), 0.0);
      expect(AnalyticsEventBuilder.numOrZero('abc'), 0.0);
      expect(AnalyticsEventBuilder.intOrZero(7), 7);
      expect(AnalyticsEventBuilder.intOrZero('9'), 9);
      expect(AnalyticsEventBuilder.intOrZero(null), 0);
    });

    test('viewProduct carries product keys, never user identity', () {
      final p = AnalyticsEventBuilder.viewProduct(
        productId: 'p1',
        productName: 'سكر',
        screen: 'product_details',
      );
      expect(p['productId'], 'p1');
      expect(p['productName'], 'سكر');
      expect(p.containsKey('userId'), isFalse);
      expect(p.containsKey('phone'), isFalse);
    });

    test('searchProducts keeps truncated term + resultCount', () {
      final p = AnalyticsEventBuilder.searchProducts(
        searchTerm: 'رز',
        resultCount: 4,
        role: 'buyer',
      );
      expect(p['searchTerm'], 'رز');
      expect(p['resultCount'], 4);
      expect(p['screen'], 'search');
    });

    test('addToCart/checkoutStarted/orderPlaced shapes', () {
      final a = AnalyticsEventBuilder.addToCart(
        productId: 'p1',
        quantity: 2,
        price: 10.5,
      );
      expect(a['quantity'], 2);
      expect(a['price'], 10.5);

      final c = AnalyticsEventBuilder.checkoutStarted(
        itemsCount: 3,
        totalAmount: 100.0,
        sellerIds: const ['s1', 's2'],
      );
      expect(c['itemsCount'], 3);
      expect((c['sellerIds'] as List).length, 2);

      final o = AnalyticsEventBuilder.orderPlaced(
        orderIds: const ['o1', 'o2'],
        itemsCount: 3,
        totalAmount: 100.0,
        role: 'buyer',
      );
      expect(o['ordersCount'], 2);
      expect(o['totalAmount'], 100.0);
    });

    test('orderFailed/login/screenView minimal shapes', () {
      final f = AnalyticsEventBuilder.orderFailed(stage: 'checkout_failed');
      expect(f['stage'], 'checkout_failed');
      expect(f.containsKey('reason'), isFalse);

      final l = AnalyticsEventBuilder.login(method: 'mint', role: 'buyer');
      expect(l['method'], 'mint');

      final s = AnalyticsEventBuilder.screenView(screen: '/cart');
      expect(s['screen'], '/cart');
    });
  });

  group('AnalyticsSession', () {
    test('session ids are unique per call and carry the timestamp', () {
      final a = AnalyticsSession.newSessionId(
        nowMs: 1700000000000,
        random: Random(1),
      );
      final b = AnalyticsSession.newSessionId(
        nowMs: 1700000000000,
        random: Random(2),
      );
      expect(a.startsWith('1700000000000-'), isTrue);
      expect(a, isNot(equals(b)));
      expect(RegExp(r'^[0-9]+-[0-9a-z]{6}$').hasMatch(a), isTrue);
    });
  });
}
