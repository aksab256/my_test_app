import 'package:flutter_test/flutter_test.dart';
import 'package:my_test_app/utils/price_display.dart';

// Covers the buyer discount-display contract used by the product details
// rows and the cart item card: discounted surfaces must prefer offerPrice
// (unit then root) and the cart strikes the base only when a stamped
// originalPrice is strictly higher than the charged price.
void main() {
  group('hasOfferDiscount', () {
    test('accepts a positive numeric offerPrice', () {
      expect(hasOfferDiscount(80.0), isTrue);
      expect(hasOfferDiscount(80), isTrue);
    });

    test('rejects null, zero, negative, and non-numeric values', () {
      expect(hasOfferDiscount(null), isFalse);
      expect(hasOfferDiscount(0), isFalse);
      expect(hasOfferDiscount(0.0), isFalse);
      expect(hasOfferDiscount(-5), isFalse);
      expect(hasOfferDiscount('?'), isFalse);
      expect(hasOfferDiscount('80'), isFalse);
    });
  });

  group('payablePrice', () {
    test('prefers the discount over the base price', () {
      expect(
        payablePrice(basePrice: 100.0, offerPrice: 80.0),
        80.0,
      );
    });

    test('falls back to base when no discount exists', () {
      expect(payablePrice(basePrice: 100.0, offerPrice: null), 100.0);
      expect(payablePrice(basePrice: 100.0, offerPrice: 0), 100.0);
    });

    test('coerces non-numeric base to zero', () {
      expect(payablePrice(basePrice: '?', offerPrice: null), 0.0);
    });
  });

  group('hasCartDiscount', () {
    test('true only when stamped original is strictly higher', () {
      expect(
        hasCartDiscount(price: 80.0, originalPrice: 100.0),
        isTrue,
      );
    });

    test('false without a stamp or when prices are equal', () {
      expect(hasCartDiscount(price: 100.0, originalPrice: null), isFalse);
      expect(hasCartDiscount(price: 100.0, originalPrice: 100.0), isFalse);
      expect(hasCartDiscount(price: 100.0, originalPrice: 90.0), isFalse);
    });
  });
}
