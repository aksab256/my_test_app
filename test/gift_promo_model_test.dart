import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_test_app/models/gift_promo_model.dart';

Map<String, dynamic> testMap({
  Object? expiryDate,
  Object? trigger = const {'type': 'min_order', 'value': 100.0},
}) {
  return {
    'sellerId': 'seller-1',
    'promoName': 'Buy more, get a gift',
    'giftOfferId': 'gift-offer-1',
    'giftProductName': 'Free sample',
    'giftUnitName': 'piece',
    'giftOfferPriceSnapshot': 15.0,
    'giftQuantityPerBase': 2,
    if (trigger != null) 'trigger': trigger,
    if (expiryDate != null) 'expiryDate': expiryDate,
    'maxQuantity': 50,
    'usedQuantity': 5,
    'status': 'active',
  };
}

void main() {
  group('GiftPromoModel.fromMap', () {
    test('reads all fields and the document id', () {
      final expiry = DateTime(2026, 12, 31);
      final model = GiftPromoModel.fromMap(
        testMap(expiryDate: Timestamp.fromDate(expiry)),
        'doc-1',
      );

      expect(model.id, 'doc-1');
      expect(model.sellerId, 'seller-1');
      expect(model.giftQuantityPerBase, 2);
      expect(model.maxQuantity, 50);
      expect(model.usedQuantity, 5);
      expect(model.status, 'active');
      expect(model.expiryDate, expiry);
      expect(model.trigger['type'], 'min_order');
    });

    test('parses ISO-8601 string dates', () {
      final model = GiftPromoModel.fromMap(
        testMap(expiryDate: '2026-06-15T10:30:00.000'),
        'doc-2',
      );

      expect(model.expiryDate, DateTime(2026, 6, 15, 10, 30));
    });

    test('missing dates default to now instead of throwing', () {
      final before = DateTime.now();
      final model = GiftPromoModel.fromMap(testMap(), 'doc-3');
      final after = DateTime.now();

      // Coarse platform clocks may return the same value for consecutive
      // DateTime.now() calls, so assert a range instead of strict ordering.
      expect(model.expiryDate.isBefore(before), isFalse);
      expect(model.expiryDate.isBefore(after.add(const Duration(seconds: 1))),
          isTrue);
      expect(model.createdAt, isA<DateTime>());
    });

    test('non-map trigger degrades to an empty map', () {
      final model = GiftPromoModel.fromMap(
        testMap(trigger: ['not', 'a', 'map']),
        'doc-4',
      );

      expect(model.trigger, isEmpty);
    });

    test('missing fields yield safe defaults', () {
      final model = GiftPromoModel.fromMap({}, 'doc-5');

      expect(model.sellerId, '');
      expect(model.giftQuantityPerBase, 1);
      expect(model.maxQuantity, 0);
      expect(model.usedQuantity, 0);
      expect(model.status, 'active');
      expect(model.trigger, isEmpty);
    });
  });

  group('GiftPromoModel serialization', () {
    test('toJson stores the expiry as ISO string and drops createdAt', () {
      final model = GiftPromoModel.fromMap(
        testMap(expiryDate: Timestamp.fromDate(DateTime(2026, 1, 1))),
        'doc-6',
      );
      final json = model.toJson();

      expect(json['expiryDate'], '2026-01-01T00:00:00.000');
      expect(json.containsKey('createdAt'), isFalse);
      expect(json['trigger'], model.trigger);
      expect(json['giftQuantityPerBase'], 2);
    });

    test('toMap stays an alias of toJson', () {
      final model = GiftPromoModel.fromMap(
        testMap(expiryDate: '2026-01-01T00:00:00.000'),
        'doc-7',
      );

      expect(model.toMap(), model.toJson());
    });
  });
}
