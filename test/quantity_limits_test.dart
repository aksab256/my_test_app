// test/quantity_limits_test.dart
//
// اختبارات القاعدة الموحدة لحدود الكمية (pure unit tests):
// effectiveMin = productMin ?? 1
// effectiveMax = min(availableStock, productMax) — والمخزون سقف إجباري دائمًا.

import 'package:flutter_test/flutter_test.dart';
import 'package:my_test_app/utils/quantity_limits.dart';

void main() {
  group('hard ceiling: availableStock يحكم دائمًا', () {
    test('available=5 بلا max: 5 مقبولة و6 مرفوضة', () {
      final limits =
          resolveQuantityLimits(availableStock: 5, productMax: null);
      expect(limits.effectiveMin, equals(1));
      expect(limits.effectiveMax, equals(5));
      expect(limits.hasValidQuantity, isTrue);
      expect(limits.validate(5), isNull);
      expect(limits.validate(6), equals(QuantityInvalidReason.aboveMax));
    });

    test('available=5 / max=10: الفعلي 5', () {
      final limits =
          resolveQuantityLimits(availableStock: 5, productMax: 10);
      expect(limits.effectiveMax, equals(5));
      expect(limits.validate(5), isNull);
      expect(limits.validate(6), equals(QuantityInvalidReason.aboveMax));
    });

    test('available=10 / max=5: الفعلي 5', () {
      final limits =
          resolveQuantityLimits(availableStock: 10, productMax: 5);
      expect(limits.effectiveMax, equals(5));
      expect(limits.validate(5), isNull);
      expect(limits.validate(6), equals(QuantityInvalidReason.aboveMax));
    });
  });

  group('product minimum', () {
    test('min=3 / available=10: 1 و2 مرفوضان و3 مقبولة', () {
      final limits =
          resolveQuantityLimits(availableStock: 10, productMin: 3);
      expect(limits.effectiveMin, equals(3));
      expect(limits.validate(1), equals(QuantityInvalidReason.belowMin));
      expect(limits.validate(2), equals(QuantityInvalidReason.belowMin));
      expect(limits.validate(3), isNull);
    });

    test('min=3 / available=3: 3 فقط', () {
      final limits =
          resolveQuantityLimits(availableStock: 3, productMin: 3);
      expect(limits.hasValidQuantity, isTrue);
      expect(limits.validate(3), isNull);
      expect(limits.validate(2), equals(QuantityInvalidReason.belowMin));
      expect(limits.validate(4), equals(QuantityInvalidReason.aboveMax));
    });

    test('min=5 / available=3: لا كمية صالحة (unavailable)', () {
      final limits =
          resolveQuantityLimits(availableStock: 5 - 2, productMin: 5);
      expect(limits.hasValidQuantity, isFalse);
      // أي كمية تُرفض بسبب تعارض الحدين، ولا يُقترح 5 ولا تُرسل.
      expect(limits.validate(3), equals(QuantityInvalidReason.minAboveStock));
      expect(limits.validate(5), equals(QuantityInvalidReason.minAboveStock));
    });
  });

  group('open limits: لا نخترع حدودًا ولا 9999 وهميًا', () {
    test('مخزون مجهول بلا max: مفتوح (effectiveMax null)', () {
      final limits = resolveQuantityLimits(availableStock: null);
      expect(limits.effectiveMax, isNull);
      expect(limits.hasValidQuantity, isTrue);
      expect(limits.validate(1000000), isNull);
    });

    test('مخزون مجهول مع max: السقف هو max فقط', () {
      final limits =
          resolveQuantityLimits(availableStock: null, productMax: 5);
      expect(limits.effectiveMax, equals(5));
      expect(limits.validate(6), equals(QuantityInvalidReason.aboveMax));
    });

    test('min/max صفريان يُعاملان كمفتوحين', () {
      final limits = resolveQuantityLimits(
          availableStock: 7, productMin: 0, productMax: 0);
      expect(limits.effectiveMin, equals(1));
      expect(limits.effectiveMax, equals(7));
    });

    test('مخزون صفر معلوم: لا شيء صالح (فوقه مرفوض وتحته مرفوض)', () {
      final limits = resolveQuantityLimits(availableStock: 0);
      expect(limits.effectiveMax, equals(0));
      expect(limits.hasValidQuantity, isFalse);
      expect(limits.validate(1), equals(QuantityInvalidReason.minAboveStock));
    });
  });

  group('رسائل واضحة تتضمن الحدود', () {
    test('aboveMax يذكر الحد الفعلي', () {
      final limits =
          resolveQuantityLimits(availableStock: 7, productMax: 20);
      final msg = quantityErrorMessage(
          QuantityInvalidReason.aboveMax, limits);
      expect(msg, contains('7'));
    });
  });
}
