// lib/utils/seller_geo.dart
//
// عقد التوصيل القديم: مطابقة إحداثيات فقط — بلا أسماء في القرار.
// نقطة المشتري (GPS: effectiveLat/effectiveLng) تُطابَق ضد مضلعات
// ملفات الـGeoJSON المجمّعة. أسماء المناطق المخزنة عند التاجر/العرض
// ليست سوى مفاتيح لاستخراج المضلعات، وليست طرفاً في المقارنة.
//
// القواعد:
// - أسماء فارغة = عام (ظاهر للجميع)، كما كان.
// - مشترٍ بلا إحداثيات = لا يرى إلا العام.
// - اسم بلا مضلع معروف يُتجاهل مع سجل تشخيصي (لا يساوي مطابقة).
// - التحميل مرة واحدة مع cache، ورفض سريع بصناديق الإحاطة قبل
//   اختبار النقطة-في-المضلع.

import 'package:flutter/foundation.dart';

import 'package:my_test_app/services/buyer_area_resolver.dart';
import 'package:my_test_app/utils/offer_geo_filter.dart';

class SellerGeo {
  SellerGeo._();

  static Map<String, List<GeoPoint>>? _polys;
  static Map<String, GeoBBox>? _boxes;

  /// للاختبار/إعادة التحميل فقط.
  static void clearCache() {
    _polys = null;
    _boxes = null;
  }

  /// حقن مضلعات في الاختبارات فقط (يغني عن ملفات الـGeoJSON).
  @visibleForTesting
  static void setPolygonsForTest(Map<String, List<GeoPoint>> polys) {
    _polys = polys;
    _boxes = buildAreaBBoxes(polys);
  }

  static Future<void> ensureLoaded() async {
    if (_polys != null) return;
    final loaded = await BuyerAreaResolver.loadAreaPolygons();
    _polys = loaded;
    _boxes = buildAreaBBoxes(loaded);
  }

  static List<String> namesOf(dynamic raw) {
    if (raw is List) {
      return raw
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    return const [];
  }

  /// نقطة المشتري كسجل — تُمرر مباشرة لواجهات الإحداثيات.
  static ({double? lat, double? lng}) buyerPoint(
          {double? lat, double? lng}) =>
      (lat: lat, lng: lng);

  /// هل نقطة المشتري داخل أي مضلع من مضلعات هذه الأسماء؟
  /// نسخة متزامنة: تعمل بعد ensureLoaded (تجهزها الشاشة قبل العرض).
  /// بلا كاش محمل = false (مع سجل تشخيصي).
  static bool pointServesNamesSync(
    double? lat,
    double? lng,
    List<String> names,
  ) {
    final trimmed =
        names.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    if (trimmed.isEmpty) return true;
    if (lat == null || lng == null || _polys == null || _boxes == null) {
      debugPrint('SellerGeo: sync check before cache ready — treated as no-match.');
      return false;
    }
    final point = GeoPoint(lat: lat, lng: lng);
    for (final name in trimmed) {
      final poly = _polys![name];
      if (poly == null || poly.length < 3) continue;
      final box = _boxes![name];
      if (box != null && !box.contains(point)) continue;
      if (isPointInPolygon(point, poly)) return true;
    }
    return false;
  }

  static bool isOfferVisibleSync({
    required Map<String, dynamic> offerData,
    required double? buyerLat,
    required double? buyerLng,
    required OfferListContext context,
  }) {
    if (context == OfferListContext.sellerStore) return true;
    return pointServesNamesSync(buyerLat, buyerLng, readOfferZones(offerData));
  }

  static Future<bool> pointServesNames(
    double? lat,
    double? lng,
    List<String> names,
  ) async {
    final trimmed =
        names.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    if (trimmed.isEmpty) return true;
    if (lat == null || lng == null) return false;
    try {
      await ensureLoaded();
    } catch (e) {
      debugPrint('SellerGeo: polygon cache unavailable: $e');
      return false;
    }
    final polys = _polys!;
    final boxes = _boxes!;
    final point = GeoPoint(lat: lat, lng: lng);
    for (final name in trimmed) {
      final poly = polys[name];
      if (poly == null || poly.length < 3) {
        debugPrint('SellerGeo: no polygon for "$name" — skipped.');
        continue;
      }
      final box = boxes[name];
      if (box != null && !box.contains(point)) continue;
      if (isPointInPolygon(point, poly)) return true;
    }
    return false;
  }

  /// قرار الظهور لعرض واحد (مسار المشتري): Global أو داخل المضلعات.
  static Future<bool> isOfferVisibleByCoords({
    required Map<String, dynamic> offerData,
    required double? buyerLat,
    required double? buyerLng,
    required OfferListContext context,
  }) async {
    if (context == OfferListContext.sellerStore) return true;
    return pointServesNames(buyerLat, buyerLng, readOfferZones(offerData));
  }

  static Future<bool> isOfferDocDeliverableByCoords({
    required Map<String, dynamic> offerData,
    required double? buyerLat,
    required double? buyerLng,
  }) {
    return isOfferVisibleByCoords(
      offerData: offerData,
      buyerLat: buyerLat,
      buyerLng: buyerLng,
      context: OfferListContext.productOffers,
    );
  }

  static Future<bool> hasDeliverableOfferByCoords({
    required Iterable<Map<String, dynamic>> offers,
    required double? buyerLat,
    required double? buyerLng,
  }) async {
    for (final o in offers) {
      if (await isOfferDocDeliverableByCoords(
          offerData: o, buyerLat: buyerLat, buyerLng: buyerLng)) {
        return true;
      }
    }
    return false;
  }

  /// كل العروض الظاهرة (ترشيح بعد الجلب — المضلعات محلية ورخيصة).
  static Future<List<Map<String, dynamic>>> filterOfferDocsByCoords(
    List<Map<String, dynamic>> docs,
    double? buyerLat,
    double? buyerLng,
    OfferListContext context,
  ) async {
    final out = <Map<String, dynamic>>[];
    for (final doc in docs) {
      if (await isOfferVisibleByCoords(
        offerData: doc,
        buyerLat: buyerLat,
        buyerLng: buyerLng,
        context: context,
      )) {
        out.add(doc);
      }
    }
    return out;
  }

  /// معرفات البائعين الذين لديهم عرض ظاهر واحد على الأقل.
  static Future<Set<String>> visibleOfferSellerIdsByCoords({
    required Iterable<Map<String, dynamic>> offerDocs,
    required double? buyerLat,
    required double? buyerLng,
  }) async {
    final ids = <String>{};
    for (final data in offerDocs) {
      final sellerId = data['sellerId']?.toString();
      if (sellerId == null || sellerId.isEmpty || ids.contains(sellerId)) {
        continue;
      }
      if (!isOfferActive(data)) continue;
      if (await isOfferVisibleByCoords(
        offerData: data,
        buyerLat: buyerLat,
        buyerLng: buyerLng,
        context: OfferListContext.productOffers,
      )) {
        ids.add(sellerId);
      }
    }
    return ids;
  }

  /// تغطية التاجر لنقطة المشتري (وثيقة sellers).
  static Future<bool> sellerServesPoint({
    required Map<String, dynamic> sellerData,
    required double? buyerLat,
    required double? buyerLng,
  }) {
    return pointServesNames(buyerLat, buyerLng, namesOf(sellerData['deliveryAreas']));
  }
}
