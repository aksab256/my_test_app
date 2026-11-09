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

// Bounding box for one area polygon: fast pre-filter before ray casting.
// seller-to-buyer only: never changes the decision, only speeds up zone unpack.
class GeoBBox {
  final double minLat;
  final double maxLat;
  final double minLng;
  final double maxLng;
  const GeoBBox({required this.minLat, required this.maxLat, required this.minLng, required this.maxLng});
  bool contains(GeoPoint point) {
    return point.lat >= minLat && point.lat <= maxLat && point.lng >= minLng && point.lng <= maxLng;
  }
}

// Builds one bounding box per area from a ready polygons map.
Map<String, GeoBBox> buildAreaBBoxes(Map<String, List<GeoPoint>> areaPolygons) {
  final Map<String, GeoBBox> result = {};
  areaPolygons.forEach((areaName, polygon) {
    if (polygon.isEmpty) return;
    double minLat = polygon.first.lat;
    double maxLat = polygon.first.lat;
    double minLng = polygon.first.lng;
    double maxLng = polygon.first.lng;
    for (final p in polygon.skip(1)) {
      if (p.lat < minLat) minLat = p.lat;
      if (p.lat > maxLat) maxLat = p.lat;
      if (p.lng < minLng) minLng = p.lng;
      if (p.lng > maxLng) maxLng = p.lng;
    }
    result[areaName] = GeoBBox(minLat: minLat, maxLat: maxLat, minLng: minLng, maxLng: maxLng);
  });
  return result;
}

// Same decision as resolveAreasForPoint, but skips ray casting for polygons
// whose bounding box cannot contain the point. Pass a prebuilt bboxes map
// (from buildAreaBBoxes) to unpack zone files fast on every screen.
List<String> resolveAreasForPointFast(
  GeoPoint point,
  Map<String, List<GeoPoint>> areaPolygons, [
  Map<String, GeoBBox>? bboxes,
]) {
  final Map<String, GeoBBox> boxes = bboxes ?? buildAreaBBoxes(areaPolygons);
  final List<String> matched = [];
  areaPolygons.forEach((areaName, polygon) {
    if (polygon.length < 3) return;
    final box = boxes[areaName];
    if (box != null && !box.contains(point)) return;
    if (isPointInPolygon(point, polygon)) matched.add(areaName);
  });
  return matched;
}

// Single-offer deliverability for the seller-to-buyer path.
// Buyer sees the product, but only this seller price when true.
bool isOfferDocDeliverable({
  required Map<String, dynamic> offerData,
  required List<String> buyerAreas,
}) {
  return isOfferVisibleForBuyer(
    offerData: offerData,
    buyerAreas: buyerAreas,
    context: OfferListContext.productOffers,
  );
}

// True when at least one offer of the product is deliverable to the buyer.
// Used to keep the product visible while hiding non-covering seller prices.
bool hasDeliverableOffer({
  required Iterable<Map<String, dynamic>> offers,
  required List<String> buyerAreas,
}) {
  return offers.any((o) => isOfferDocDeliverable(offerData: o, buyerAreas: buyerAreas));
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

/// هل العرض نشط للمشتري؟ الغائب/الفارغ يُعامل كنشط (توافق رجعي مع
/// العروض القديمة التي لا تحمل الحقل)؛ أي قيمة غير `active` تعني مخفيًا.
/// لا تُستخدم في سياق البائع — البائع يرى كل عروضه ويديرها.
bool isOfferActive(Map<String, dynamic> offerData) {
  final dynamic raw = offerData['status'];
  if (raw == null) return true;
  final String s = raw.toString().trim().toLowerCase();
  return s.isEmpty || s == 'active';
}

/// سبب رفض طلب هذا العرض، أو null عندما يجوز طلبه. تُستخدم عند
/// الإضافة للسلة وعند إتمام الدفع لرفض العرض الذي أصبح غير نشط.
String? offerBlockedReason(Map<String, dynamic> offerData) {
  return isOfferActive(offerData) ? null : 'هذا العرض لم يعد متاحًا';
}

/// معرفات التجار الذين لديهم عرض واحد ظاهر على الأقل للمشتري
/// (نفس قرار الظهور في صفحة المنتجات — سياق productOffers — مع
/// شرط النشاط). تُستخدم في شاشة التجار حتى يظهر التاجر فقط عندما
/// يكون لديه عرض نشط ظاهر جغرافيًا للمشتري الحالي.
Set<String> visibleOfferSellerIds({
  required Iterable<Map<String, dynamic>> offerDocs,
  required List<String> buyerAreas,
}) {
  final ids = <String>{};
  for (final data in offerDocs) {
    final sellerId = data['sellerId']?.toString();
    if (sellerId == null || sellerId.isEmpty || ids.contains(sellerId)) continue;
    if (!isOfferActive(data)) continue;
    if (isOfferVisibleForBuyer(
      offerData: data,
      buyerAreas: buyerAreas,
      context: OfferListContext.productOffers,
    )) {
      ids.add(sellerId);
    }
  }
  return ids;
}

/// فلترة قائمة مستندات عروض خام حسب السياق، مع الحفاظ على الترتيب الأصلي.
/// مناطق المشتري تُحل مرة واحدة خارجها وتُمرَّر جاهزة — لا منطق جغرافي
/// إضافي هنا، القرار بالكامل في [isOfferVisibleForBuyer].
List<Map<String, dynamic>> filterOfferDocs(
  List<Map<String, dynamic>> docs,
  List<String> buyerAreas,
  OfferListContext context,
) {
  return docs
      .where((doc) => isOfferVisibleForBuyer(
            offerData: doc,
            buyerAreas: buyerAreas,
            context: context,
          ))
      .toList();
}
