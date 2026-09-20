// test/analytics_event_builder_test.dart
//
// Pure-Dart unit tests for AnalyticsEventBuilder (no Firebase/Flutter
// bindings). NOTE: not executed in this session (no toolchain access);
// run with `flutter test test/analytics_event_builder_test.dart`.
import 'package:flutter_test/flutter_test.dart';
import 'package:my_test_app/services/analytics_service.dart';

void main() {
  group('AnalyticsEventBuilder', () {
    test('truncateTerm keeps short terms intact', () {
      expect(AnalyticsEventBuilder.truncateTerm('  سكر  '), 'سكر');
    });

    test('truncateTerm caps at 100 chars', () {
      final long = List.filled(150, 'a').join();
      expect(AnalyticsEventBuilder.truncateTerm(long).length, 100);
    });

    test('viewProduct carries product identity + screen', () {
      final p = AnalyticsEventBuilder.viewProduct(
        productId: 'p1',
        productName: 'سكر',
        role: 'buyer',
      );
      expect(p['productId'], 'p1');
      expect(p['screen'], 'product_details');
      expect(p['role'], 'buyer');
    });

    test('searchProducts truncates term and keeps count', () {
      final long = List.filled(150, 'b').join();
      final p = AnalyticsEventBuilder.searchProducts(
        searchTerm: long,
        resultCount: 7,
        role: 'consumer',
      );
      expect((p['searchTerm'] as String).length, 100);
      expect(p['resultCount'], 7);
    });

    test('addToCart carries commerce keys', () {
      final p = AnalyticsEventBuilder.addToCart(
        productId: 'p1',
        offerId: 'o1',
        sellerId: 's1',
        quantity: 2,
        price: 10.5,
        role: 'buyer',
        screen: 'buyer_product_card',
      );
      expect(p['quantity'], 2);
      expect(p['price'], 10.5);
      expect(p['sellerId'], 's1');
    });

    test('checkoutStarted carries totals + sellers', () {
      final p = AnalyticsEventBuilder.checkoutStarted(
        itemsCount: 3,
        totalAmount: 99.0,
        sellerIds: ['s1', 's2'],
        role: 'consumer',
      );
      expect(p['itemsCount'], 3);
      expect((p['sellerIds'] as List).length, 2);
    });

    test('numOrZero coerces defensively', () {
      expect(AnalyticsEventBuilder.numOrZero('12.5'), 12.5);
      expect(AnalyticsEventBuilder.numOrZero(null), 0.0);
      expect(AnalyticsEventBuilder.intOrZero('x'), 0);
    });
  });
}
