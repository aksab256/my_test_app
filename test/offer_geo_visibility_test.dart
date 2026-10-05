// test/offer_geo_visibility_test.dart
//
// تغطية الفصل المعماري بين مساري عروض الموردين (pure unit tests):
// - Test 1: Seller Store — منتجات Seller تظهر بعد الفلترة على مستوى Seller.
// - Test 2: Seller Store regression — لا إخفاء بسبب userAddress النصي.
// - Test 3: Product Offers — Seller A يخدم Buyer يظهر، Seller B لا يخدمه يُخفى.
// - Test 4: Product Offers regression — الإصلاح لم يحول المسار إلى "اعرض الكل".
// - Test 5: Global Seller — بدون delivery areas يظهر حسب الـbusiness rule الحالي.
// - Test 6: TradersScreen — الحكم الجغرافي GPS + point-in-polygon / global.

import 'package:flutter_test/flutter_test.dart';
import 'package:my_test_app/utils/offer_geo_filter.dart';
import 'package:my_test_app/services/buyer_area_resolver.dart';

void main() {
  Map<String, dynamic> offer(List<String>? zones, {bool useAreasField = false}) {
    if (zones == null) return {};
    if (useAreasField) return {'deliveryAreas': zones};
    return {'deliveryZones': zones};
  }

  group('Test 1 — Seller Store: منتجات Seller تظهر', () {
    test('عرض Seller محدد يظهر رغم عدم تطابق مناطق المشتري', () {
      final visible = isOfferVisibleForBuyer(
        offerData: offer(['سموحة']),
        buyerAreas: const ['الغربية - طنطا'],
        context: OfferListContext.sellerStore,
      );
      expect(visible, isTrue);
    });

    test('كل عروض Seller تظهر داخل متجره (قائمة كاملة)', () {
      final offers = [
        offer(['سموحة']),
        offer(['المنتزه']),
        offer([]),
        offer(null),
      ];
      final visible = offers
          .where((o) => isOfferVisibleForBuyer(
                offerData: o,
                buyerAreas: const ['Gharbia'],
                context: OfferListContext.sellerStore,
              ))
          .length;
      expect(visible, equals(offers.length));
    });
  });

  group('Test 2 — Seller Store regression: لا مطابقة عنوان حر', () {
    test('userAddress النصي لا يخفي منتج Seller داخل متجره', () {
      // عنوان شارع حر لا يساوي أي اسم منطقة — لم يعد مستخدمًا هنا أصلًا،
      // والسياق يتجاوز الفلترة تمامًا.
      final visible = isOfferVisibleForBuyer(
        offerData: offer(['الإسكندرية-سموحة']),
        buyerAreas: const ['شارع البحر، طنطا، الغربية'],
        context: OfferListContext.sellerStore,
      );
      expect(visible, isTrue);
    });
  });

  group('Test 3 — Product Offers: A يظهر و B يُخفى', () {
    test('Seller A يخدم Buyer -> يظهر سعره', () {
      expect(
        isOfferVisibleForBuyer(
          offerData: offer(['سموحة']),
          buyerAreas: const ['سموحة', 'المنتزه'],
          context: OfferListContext.productOffers,
        ),
        isTrue,
      );
    });

    test('Seller B لا يخدم Buyer -> لا يظهر سعره', () {
      expect(
        isOfferVisibleForBuyer(
          offerData: offer(['المنتزه']),
          buyerAreas: const ['سموحة'],
          context: OfferListContext.productOffers,
        ),
        isFalse,
      );
    });
  });

  group('Test 4 — Product Offers regression: ليس "اعرض الكل"', () {
    test('مسار المنتج ما زال يستبعد Seller غير الخادم', () {
      final offers = [
        offer(['سموحة']), // A يخدم
        offer(['المنتزه']), // B لا يخدم
        offer([]), // Global
      ];
      final visibleCount = offers
          .where((o) => isOfferVisibleForBuyer(
                offerData: o,
                buyerAreas: const ['سموحة'],
                context: OfferListContext.productOffers,
              ))
          .length;
      // A + Global فقط — لو أصبح "اعرض الكل" لكانت 3.
      expect(visibleCount, equals(2));
    });
  });

  group('Test 5 — Global Seller يظهر حسب الـbusiness rule الحالي', () {
    test('عرض بلا مناطق (null) يظهر في مسار المنتج', () {
      expect(
        isOfferVisibleForBuyer(
          offerData: offer(null),
          buyerAreas: const ['Gharbia'],
          context: OfferListContext.productOffers,
        ),
        isTrue,
      );
    });

    test('عرض بلا مناطق (فارغة) يظهر حتى لمشترٍ بلا موقع معروف', () {
      expect(
        isOfferVisibleForBuyer(
          offerData: offer([]),
          buyerAreas: const [],
          context: OfferListContext.productOffers,
        ),
        isTrue,
      );
    });

    test('مشترٍ بلا موقع معروف لا يرى عروض المناطق (مثل TradersScreen)', () {
      expect(
        isOfferVisibleForBuyer(
          offerData: offer(['سموحة']),
          buyerAreas: const [],
          context: OfferListContext.productOffers,
        ),
        isFalse,
      );
    });

    test('fallback: deliveryAreas يُقرأ عند غياب deliveryZones', () {
      expect(
        isOfferVisibleForBuyer(
          offerData: offer(['سموحة'], useAreasField: true),
          buyerAreas: const ['سموحة'],
          context: OfferListContext.productOffers,
        ),
        isTrue,
      );
      expect(readOfferZones(offer(['سموحة'], useAreasField: true)),
          equals(['سموحة']));
    });
  });

  group('Test 6 — الحكم الجغرافي GPS + point-in-polygon', () {
    const square = [
      GeoPoint(lat: 0, lng: 0),
      GeoPoint(lat: 0, lng: 10),
      GeoPoint(lat: 10, lng: 10),
      GeoPoint(lat: 10, lng: 0),
    ];

    test('نقطة الداخل تُطابق المنطقة', () {
      expect(
        resolveAreasForPoint(
          const GeoPoint(lat: 5, lng: 5),
          {'AreaX': square},
        ),
        equals(['AreaX']),
      );
    });

    test('نقطة الخارج (الغربية) لا تُطابق منطقة الإسكندرية', () {
      expect(
        resolveAreasForPoint(
          const GeoPoint(lat: 50, lng: 50),
          {'AreaX': square},
        ),
        isEmpty,
      );
    });

    test('parseGeoJsonAreas يدعم Polygon و MultiPolygon ويتجاهل الفارغ', () {
      final areas = parseGeoJsonAreas({
        'features': [
          {
            'properties': {'name': 'PolyArea'},
            'geometry': {
              'type': 'Polygon',
              'coordinates': [
                [
                  [0, 0],
                  [0, 10],
                  [10, 10],
                  [10, 0],
                  [0, 0],
                ]
              ],
            },
          },
          {
            'properties': {'name': 'MultiArea'},
            'geometry': {
              'type': 'MultiPolygon',
              'coordinates': [
                [
                  [
                    [20, 20],
                    [20, 30],
                    [30, 30],
                    [30, 20],
                    [20, 20],
                  ]
                ]
              ],
            },
          },
          {
            'properties': {'name': ''},
            'geometry': {'type': 'Polygon', 'coordinates': []},
          },
        ],
      });
      expect(areas.keys.toSet(), equals({'PolyArea', 'MultiArea'}));
      expect(
        resolveAreasForPoint(const GeoPoint(lat: 25, lng: 25), areas),
        equals(['MultiArea']),
      );
    });
  });
}
