import 'package:flutter_test/flutter_test.dart';

import 'package:my_test_app/utils/gift_value.dart';

void main() {
  group('quoteSingleGiftValue', () {
    test('computes the documented example: 5 cartons x 500, 1 bottle (500/12)', () {
      final q = quoteSingleGiftValue(
        triggerUnitPrice: 500,
        triggerQty: 5,
        giftUnitPrice: 500 / 12,
        giftQty: 1,
      );
      expect(q.available, isTrue);
      expect(q.requiredPurchaseValue, 2500);
      expect(q.giftValue, closeTo(41.67, 0.01));
      expect(q.percentage, closeTo(1.67, 0.01));
    });

    test('same-product gift uses its own unit price', () {
      final q = quoteSingleGiftValue(
        triggerUnitPrice: 100,
        triggerQty: 10,
        giftUnitPrice: 10,
        giftQty: 2,
      );
      expect(q.available, isTrue);
      expect(q.requiredPurchaseValue, 1000);
      expect(q.giftValue, 20);
      expect(q.percentage, 2.0);
    });

    test('missing price is unavailable, never zero', () {
      expect(
        quoteSingleGiftValue(
          triggerUnitPrice: null,
          triggerQty: 10,
          giftUnitPrice: 5,
          giftQty: 1,
        ).available,
        isFalse,
      );
      expect(
        quoteSingleGiftValue(
          triggerUnitPrice: 100,
          triggerQty: 10,
          giftUnitPrice: null,
          giftQty: 1,
        ).available,
        isFalse,
      );
    });

    test('non-positive quantities are unavailable', () {
      expect(
        quoteSingleGiftValue(
          triggerUnitPrice: 100,
          triggerQty: 0,
          giftUnitPrice: 5,
          giftQty: 1,
        ).available,
        isFalse,
      );
    });
  });

  group('quoteAndGiftValue', () {
    test('sums trigger lines: 5xA(500) + 3xB(200), gift 1xC(30)', () {
      final q = quoteAndGiftValue(
        triggerLines: [(unitPrice: 500.0, qty: 5), (unitPrice: 200.0, qty: 3)],
        giftUnitPrice: 30,
        giftQty: 1,
      );
      expect(q.available, isTrue);
      expect(q.requiredPurchaseValue, 3100);
      expect(q.giftValue, 30);
      expect(q.percentage, closeTo(0.967, 0.001));
    });

    test('one missing line price poisons the whole quote', () {
      final q = quoteAndGiftValue(
        triggerLines: [(unitPrice: 500.0, qty: 5), (unitPrice: null, qty: 3)],
        giftUnitPrice: 30,
        giftQty: 1,
      );
      expect(q.available, isFalse);
      expect(q.percentage, isNull);
    });
  });
}
