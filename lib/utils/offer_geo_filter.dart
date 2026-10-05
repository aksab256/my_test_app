// lib/utils/offer_geo_filter.dart
//
// الفصل المعماري بين مساري عروض الموردين:
// - OfferListContext.sellerStore: المشتري داخل متجر Seller تمت فلترته جغرافيًا
//   مسبقًا (TradersScreen). لا تُعَد فلترة جغرافية على مستوى المنتج هنا.
// - OfferListContext.productOffers: قائمة أسعار Sellers لمنتج واحد. تُحافظ
//   على الفلترة الجغرافية: Global (بدون مناطق) يظهر للجميع، وغير ذلك يجب
//   تطابق إحدى مناطق العرض مع المناطق المكتشفة للمشتري عبر GPS.
//
// هذا الملف نقي (pure Dart) بلا Firebase/Flutter لتسهيل اختباره.

/// سياق قائمة العروض. صريح ومقصود — لا يجوز تبديل السلوك بتغيير متغير آخر.
enum OfferListContext {
  /// داخل متجر Seller محدد: بدون إعادة geo-filter على المنتج.
  sellerStore,

  /// عروض عدة Sellers لمنتج واحد: مع geo-filter.
  productOffers,
}

/// نقطة جغرافية بسيطة (lat/lng) بدون اعتمادية على إضافات الخرائط.
class GeoPoint {
  final double lat;
  final double lng;

  const GeoPoint({required this.lat, required this.lng});
}

/// اختبار نقطة-داخل-مضلع (ray casting). نفس الخوارزمية المستخدمة في
/// TradersScreen و RepTradersLiteScreen و rep_products_screen.
bool isPointInPolygon(GeoPoint point, List<GeoPoint> polygon) {
  final x = point.lng;
  final y = point.lat;
  bool inside = false;
  for (int i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
    final xi = polygon[i].lng;
    final yi = polygon[i].lat;
    final xj = polygon[j].lng;
    final yj = polygon[j].lat;
    if (((yi > y) != (yj > y)) &&
        (x < (xj - xi) * (y - yi) / (yj - yi) + xi)) {
      inside = !inside;
    }
  }
  return inside;
}

/// يعيد أسماء المناطق التي تقع فيها النقطة، بناءً على خريطة polygons
/// (اسم المنطقة -> إحداثيات المضلع). تُستخدم لتحويل GPS المشتري إلى
/// أسماء مناطق قابلة للمقارنة مع deliveryAreas/deliveryZones.
List<String> resolveAreasForPoint(
  GeoPoint point,
  Map<String, List<GeoPoint>> areaPolygons,
) {
  final List<String> matched = [];
  areaPolygons.forEach((areaName, polygon) {
    if (polygon.length >= 3 && isPointInPolygon(point, polygon)) {
      matched.add(areaName);
    }
  });
  return matched;
}

/// يقرأ مناطق العرض مع fallback آمن: deliveryZones أولًا ثم deliveryAreas.
/// لا migration ولا تغيير schema — قراءة فقط.
List<String> readOfferZones(Map<String, dynamic> offerData) {
  final dynamic zones = offerData['deliveryZones'];
  if (zones is List && zones.isNotEmpty) {
    return zones.whereType<String>().toList();
  }
  final dynamic areas = offerData['deliveryAreas'];
  if (areas is List && areas.isNotEmpty) {
    return areas.whereType<String>().toList();
  }
  return const [];
}

/// هل العرض Global (متاح للجميع)؟ أي بدون مناطق توصيل في الحقلين.
bool isGlobalOffer(Map<String, dynamic> offerData) {
  return readOfferZones(offerData).isEmpty;
}

/// قرار الظهور لعرض واحد حسب السياق.
///
/// - sellerStore: يظهر دائمًا (الأهلية حُسمت عند مستوى الـSeller).
/// - productOffers: يظهر إذا Global أو إذا تطابقت إحدى مناطقه مع مناطق المشتري.
///   مشترٍ بلا موقع معروف (قائمة فارغة) يرى الـGlobal فقط — نفس قاعدة
///   TradersScreen للموقع المجهول.
bool isOfferVisibleForBuyer({
  required Map<String, dynamic> offerData,
  required List<String> buyerAreas,
  required OfferListContext context,
}) {
  if (context == OfferListContext.sellerStore) return true;
  final zones = readOfferZones(offerData);
  if (zones.isEmpty) return true;
  return zones.any(buyerAreas.contains);
}
