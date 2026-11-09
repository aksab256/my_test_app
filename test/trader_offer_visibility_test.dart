// test/trader_offer_visibility_test.dart
//
// يثبت أن التاجر الذي تظهر عروضه في صفحة المنتجات لا يُحجب من شاشة التجار:
// visibleOfferSellerIds تطبق نفس قرار الظهور (سياق productOffers) على
// مستندات productOffers الخام، وشاشة التجار تضم هؤلاء التجار أياً كان
// شرط المنطقة على مستوى التاجر.

import 'package:flutter_test/flutter_test.dart';
import 'package:my_test_app/utils/offer_geo_filter.dart';

void main() {
  group('trader visibility follows visible offers', () {
    test('تاجر محجوب جغرافياً لكن عرضه Global يدخل القائمة', () {
      final ids = visibleOfferSellerIds(
        offerDocs: [
          {'sellerId': 's1'},
        ],
        buyerAreas: const ['منطقة-أخرى'],
      );
      expect(ids, contains('s1'));
    });

    test('تاجر عرضه مطابق لمنطقة المشتري يدخل القائمة', () {
      final ids = visibleOfferSellerIds(
        offerDocs: [
          {'sellerId': 's1', 'deliveryZones': ['سموحة']},
        ],
        buyerAreas: const ['سموحة'],
      );
      expect(ids, contains('s1'));
    });

    test('تاجر كل عروضه خارج مناطق المشتري يُستبعد', () {
      final ids = visibleOfferSellerIds(
        offerDocs: [
          {'sellerId': 's1', 'deliveryZones': ['بعيدة']},
        ],
        buyerAreas: const ['قريبة'],
      );
      expect(ids, isEmpty);
    });

    test('عروض بلا sellerId تُتجاهل دون كسر', () {
      final ids = visibleOfferSellerIds(
        offerDocs: [
          {'deliveryZones': []},
          {'sellerId': '', 'deliveryZones': []},
        ],
        buyerAreas: const [],
      );
      expect(ids, isEmpty);
    });

    test('التاجر يظهر مرة واحدة مهما تعددت عروضه الظاهرة', () {
      final ids = visibleOfferSellerIds(
        offerDocs: [
          {'sellerId': 's1'},
          {'sellerId': 's1', 'deliveryZones': ['سموحة']},
          {'sellerId': 's2', 'deliveryZones': ['بعيدة']},
        ],
        buyerAreas: const ['سموحة'],
      );
      expect(ids, equals({'s1'}));
    });
  });
}
