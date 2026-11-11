import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_test_app/services/gift_eligibility_service.dart';

Map<String, dynamic> promo({
  String status = 'active',
  Object? expiry = '2099-12-31T00:00:00.000',
  int maxQuantity = 10,
  int usedQuantity = 0,
  Map<String, dynamic>? trigger,
  List<Map<String, dynamic>>? triggers,
}) {
  return {
    'sellerId': 's1',
    'promoName': 'عرض اختبار',
    'giftOfferId': 'g1',
    'giftProductName': 'زجاجة',
    'giftUnitName': 'زجاجة',
    'giftQuantityPerBase': 1,
    if (expiry != null) 'expiryDate': expiry,
    'maxQuantity': maxQuantity,
    'usedQuantity': usedQuantity,
    'status': status,
    if (trigger != null) 'trigger': trigger,
    if (triggers != null) 'triggers': triggers,
  };
}

void main() {
  group('parseGiftExpiry', () {
    test('parses Timestamp and ISO string', () {
      final ts = Timestamp.fromDate(DateTime(2099, 1, 1));
      expect(parseGiftExpiry(ts), DateTime(2099, 1, 1));
      expect(parseGiftExpiry('2099-06-15T10:30:00.000'),
          DateTime(2099, 6, 15, 10, 30));
    });

    test('null and garbage yield null', () {
      expect(parseGiftExpiry(null), isNull);
      expect(parseGiftExpiry('not-a-date'), isNull);
      expect(parseGiftExpiry(123), isNull);
    });
  });

  group('isGiftPromoLive', () {
    test('active + future expiry + budget grants live', () {
      expect(isGiftPromoLive(promo(), DateTime(2026, 1, 1)), isTrue);
    });

    test('disabled or expired never live', () {
      expect(isGiftPromoLive(promo(status: 'disabled'), DateTime(2026, 1, 1)),
          isFalse);
      expect(
          isGiftPromoLive(
              promo(expiry: '2020-01-01T00:00:00.000'), DateTime(2026, 1, 1)),
          isFalse);
    });

    test('exhausted budget not live', () {
      expect(
          isGiftPromoLive(
              promo(maxQuantity: 5, usedQuantity: 5), DateTime(2026, 1, 1)),
          isFalse);
    });

    test('legacy promo without expiry stays live', () {
      final p = promo();
      p.remove('expiryDate');
      expect(isGiftPromoLive(p, DateTime(2026, 1, 1)), isTrue);
    });

    test('unparseable expiry fails closed', () {
      expect(isGiftPromoLive(promo(expiry: 'garbage'), DateTime(2026, 1, 1)),
          isFalse);
    });
  });

  group('giftTriggerLines', () {
    test('AND triggers preserved in order', () {
      final p = promo(triggers: [
        {
          'type': 'specific_item',
          'offerId': 'oA',
          'unitName': 'كرتونة',
          'triggerQuantityBase': 1
        },
        {
          'type': 'specific_item',
          'offerId': 'oB',
          'unitName': 'كرتونة',
          'triggerQuantityBase': 1
        },
      ]);
      final lines = giftTriggerLines(p);
      expect(lines.length, 2);
      expect(lines[0]['offerId'], 'oA');
      expect(lines[1]['offerId'], 'oB');
    });

    test('legacy single trigger wrapped', () {
      final p = promo(trigger: {
        'type': 'specific_item',
        'offerId': 'o1',
        'unitName': 'كرتونة',
        'triggerQuantityBase': 5,
      });
      final lines = giftTriggerLines(p);
      expect(lines.length, 1);
      expect(lines.single['triggerQuantityBase'], 5);
    });

    test('min_order has no item lines', () {
      final p = promo(trigger: {'type': 'min_order', 'value': 100});
      expect(giftTriggerLines(p), isEmpty);
    });
  });

  group('giftConditionText — mandatory scenarios', () {
    test('scenario A: 5 cartons of one product', () {
      final p = promo(trigger: {
        'type': 'specific_item',
        'offerId': 'o1',
        'productName': 'منتج محدد',
        'unitName': 'كرتونة',
        'triggerQuantityBase': 5,
      });
      final text = giftConditionText(p);
      expect(text, contains('5'));
      expect(text, contains('منتج محدد'));
      expect(text, contains('كرتونة'));
    });

    test('scenario B: AND two products joined without shortening', () {
      final p = promo(
        trigger: {
          'type': 'specific_item',
          'offerId': 'oA',
          'productName': 'المنتج الأول',
          'unitName': 'كرتونة',
          'triggerQuantityBase': 1,
        },
        triggers: [
          {
            'type': 'specific_item',
            'offerId': 'oA',
            'productName': 'المنتج الأول',
            'unitName': 'كرتونة',
            'triggerQuantityBase': 1
          },
          {
            'type': 'specific_item',
            'offerId': 'oB',
            'productName': 'المنتج الثاني',
            'unitName': 'كرتونة',
            'triggerQuantityBase': 1
          },
        ],
      );
      final text = giftConditionText(p);
      expect(text, contains('المنتج الأول'));
      expect(text, contains('المنتج الثاني'));
      expect(text, contains('+'));
    });
  });

  group('GiftEligibilityService.sellerCoversBuyer', () {
    test('global seller covers everyone; zoned needs overlap', () {
      expect(
          GiftEligibilityService.sellerCoversBuyer(const [], ['المنطقة أ']),
          isTrue);
      expect(
          GiftEligibilityService.sellerCoversBuyer(
              ['المنطقة أ'], ['المنطقة أ']),
          isTrue);
      expect(
          GiftEligibilityService.sellerCoversBuyer(
              ['المنطقة ب'], ['المنطقة أ']),
          isFalse);
    });

    test('unknown buyer location sees global only', () {
      expect(GiftEligibilityService.sellerCoversBuyer(const [], const []),
          isTrue);
      expect(
          GiftEligibilityService.sellerCoversBuyer(
              ['المنطقة أ'], const []),
          isFalse);
    });
  });
}
