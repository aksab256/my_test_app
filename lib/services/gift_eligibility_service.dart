// lib/services/gift_eligibility_service.dart
//
// منطق أهلية عروض الهدايا الموحد للمشتري (Aksab Marketplace).
// يستخدمه تبويب الهدايا وقسم «اكسب هدايا» بنفس القواعد:
// مناطق المشتري عبر BuyerAreaResolver + effectiveLat/effectiveLng،
// صلاحية العرض (status + expiry)، والميزانية المتبقية (max-used)،
// وتغطية التاجر لمنطقة المشتري، وصلاحية عروض المحفز والهدية.
//
// الدوال الخالصة (parse/isLive/remaining/triggerLines/conditionText)
// بلا Firestore لتسهيل اختبارها.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:my_test_app/services/buyer_area_resolver.dart';
import 'package:my_test_app/utils/offer_geo_filter.dart';

/// سطر شراء واحد داخل العرض.
class GiftTriggerLine {
  final String offerId;
  final String productId;
  final String productName;
  final String unitName;
  final int unitIndex;
  final int quantityBase;
  final double price;
  final String imageUrl;

  const GiftTriggerLine({
    required this.offerId,
    required this.productId,
    required this.productName,
    required this.unitName,
    required this.unitIndex,
    required this.quantityBase,
    required this.price,
    required this.imageUrl,
  });
}

/// عرض هدية مؤهل وجاهز للعرض بعد الإثراء.
class EnrichedGift {
  final String promoId;
  final String sellerId;
  final String sellerName;
  final String promoName;
  final bool isMinOrder;
  final double minOrderValue;
  final List<GiftTriggerLine> triggers;
  final String giftName;
  final String giftUnit;
  final int giftQty;
  final String giftImage;
  final DateTime? expiry;
  final int remaining;

  const EnrichedGift({
    required this.promoId,
    required this.sellerId,
    required this.sellerName,
    required this.promoName,
    required this.isMinOrder,
    required this.minOrderValue,
    required this.triggers,
    required this.giftName,
    required this.giftUnit,
    required this.giftQty,
    required this.giftImage,
    required this.expiry,
    required this.remaining,
  });
}

/// يقبل Timestamp أو ISO-8601 String أو DateTime. غير ذلك -> null.
DateTime? parseGiftExpiry(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is Timestamp) return value.toDate();
  if (value is String && value.trim().isNotEmpty) {
    return DateTime.tryParse(value.trim());
  }
  return null;
}

/// المتبقي من ميزانية العرض. غياب الحقلين يعني غير محدود نظرياً،
/// لكن عملياً نعامل maxQuantity<=0 كغير مؤهل (لا مخزون محجوز).
int giftPromoRemaining(Map<String, dynamic> promo) {
  final maxQ = (promo['maxQuantity'] as num?)?.toInt() ?? 0;
  final usedQ = (promo['usedQuantity'] as num?)?.toInt() ?? 0;
  if (maxQ <= 0) return 0;
  final remaining = maxQ - usedQ;
  return remaining < 0 ? 0 : remaining;
}

/// هل العرض حي: status نشط + غير منتهٍ + متبقٍ.
/// أي status غير `active` (منها `disabled`) مرفوض.
/// انتهاء غير قابل للتحليل يغلق الباب (fail-closed).
bool isGiftPromoLive(Map<String, dynamic> promo, DateTime now) {
  if ((promo['status']?.toString() ?? '') != 'active') return false;
  if (!promo.containsKey('expiryDate') || promo['expiryDate'] == null) {
    return giftPromoRemaining(promo) > 0;
  }
  final exp = parseGiftExpiry(promo['expiryDate']);
  if (exp == null) return false;
  if (!exp.isAfter(now)) return false;
  return giftPromoRemaining(promo) > 0;
}

/// سطور الشراء: `triggers` أولاً (AND)، ثم `trigger` المفرد للتوافق.
List<Map<String, dynamic>> giftTriggerLines(Map<String, dynamic> promo) {
  final raw = promo['triggers'];
  if (raw is List && raw.isNotEmpty) {
    final lines = raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .where((e) => e['type'] == 'specific_item')
        .toList();
    if (lines.isNotEmpty) return lines;
  }
  final single = promo['trigger'];
  if (single is Map<String, dynamic> && single['type'] == 'specific_item') {
    return [single];
  }
  if (single is Map) {
    final m = Map<String, dynamic>.from(single);
    if (m['type'] == 'specific_item') return [m];
  }
  return const [];
}

/// نص الشرط الكامل بالعربية. لا اختصار يغير المعنى في عروض AND.
String giftConditionText(Map<String, dynamic> promo) {
  final trigger = promo['trigger'];
  final triggerMap =
      trigger is Map ? Map<String, dynamic>.from(trigger) : <String, dynamic>{};
  if (triggerMap['type'] == 'min_order') {
    final v = (triggerMap['value'] as num?)?.toDouble() ?? 0.0;
    return 'هدية عند طلب بقيمة $v ج أو أكثر';
  }
  final lines = giftTriggerLines(promo);
  if (lines.length > 1) {
    final parts = lines.map((e) {
      final q = (e['triggerQuantityBase'] as num?)?.toInt() ?? 0;
      final u = (e['unitName']?.toString() ?? '').trim();
      final n = (e['productName']?.toString() ?? 'منتج').trim();
      return 'اشترِ $q ${u.isEmpty ? '' : '$u من '}$n'.trim();
    }).join(' + ');
    return 'هدية عند شراء: $parts';
  }
  if (lines.length == 1) {
    final e = lines.first;
    final q = (e['triggerQuantityBase'] as num?)?.toInt() ?? 0;
    final u = (e['unitName']?.toString() ?? '').trim();
    final n = (e['productName']?.toString() ?? 'منتج محدد').trim();
    return 'اشترِ $q ${u.isEmpty ? '' : '$u من '}$n من نفس التاجر واحصل على الهدية'
        .trim();
  }
  return 'هدية عند استيفاء شرط العرض من نفس التاجر';
}

/// أول صورة متاحة من مستند عرض، أو '' (الأيقونة تتولى البديل — بلا وهمي).
String firstOfferImage(Map<String, dynamic> doc) {
  final urls = doc['imageUrls'];
  if (urls is List) {
    for (final u in urls) {
      final s = u?.toString() ?? '';
      if (s.isNotEmpty) return s;
    }
  }
  final single = doc['imageUrl'];
  if (single is String && single.isNotEmpty) return single;
  return '';
}

class GiftEligibilityService {
  GiftEligibilityService._();

  static const Duration cacheTtl = Duration(seconds: 90);
  static String _cacheKey = '';
  static DateTime? _cacheAt;
  static List<EnrichedGift> _cacheAll = [];

  static void clearCache() {
    _cacheKey = '';
    _cacheAt = null;
    _cacheAll = [];
  }

  static String cacheKeyFor(double? lat, double? lng, List<String> areas) {
    final la = lat == null ? 'x' : lat.toStringAsFixed(3);
    final ln = lng == null ? 'x' : lng.toStringAsFixed(3);
    return '$la,$ln|${areas.join(',')}';
  }

  /// هل التاجر يغطي المشتري: بلا مناطق = عام، وإلا تقاطع مع مناطق المشتري.
  /// مشترٍ بلا موقع معروف يرى العام فقط (نفس قاعدة TradersScreen).
  static bool sellerCoversBuyer(
      List<String> sellerAreas, List<String> buyerAreas) {
    if (sellerAreas.isEmpty) return true;
    if (buyerAreas.isEmpty) return false;
    return sellerAreas.any(buyerAreas.contains);
  }

  static List<String> readSellerAreas(Map<String, dynamic> sellerData) {
    final v = sellerData['deliveryAreas'];
    if (v is List) {
      return v.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
    }
    return const [];
  }

  static Map<String, dynamic>? _unitByIndexOrName(
      List<dynamic> units, int index, String unitName) {
    if (units.isEmpty) return null;
    if (index >= 0 && index < units.length && units[index] is Map) {
      return Map<String, dynamic>.from(units[index] as Map);
    }
    for (final u in units) {
      if (u is Map) {
        final m = Map<String, dynamic>.from(u);
        if ((m['unitName']?.toString() ?? '') == unitName) return m;
      }
    }
    if (units.first is Map) return Map<String, dynamic>.from(units.first as Map);
    return null;
  }

  static Future<Map<String, Map<String, dynamic>>> _fetchDocsById(
    FirebaseFirestore db,
    String collection,
    Set<String> ids,
  ) async {
    final result = <String, Map<String, dynamic>>{};
    if (ids.isEmpty) return result;
    final snaps = await Future.wait(ids.map((id) => db.collection(collection).doc(id).get()));
    for (final s in snaps) {
      if (s.exists && s.data() != null) result[s.id] = s.data()!;
    }
    return result;
  }

  /// يثري عرضاً واحداً بعد فحص الحياة والتغطية. null = غير مؤهل.
  static Future<EnrichedGift?> _enrichOne({
    required FirebaseFirestore db,
    required String promoId,
    required Map<String, dynamic> promo,
    required Map<String, Map<String, dynamic>> sellers,
    required Map<String, Map<String, dynamic>> offers,
    required DateTime now,
  }) async {
    if (!isGiftPromoLive(promo, now)) {
      debugPrint('GiftEligibility: promo $promoId excluded (dead: status/expiry/budget).');
      return null;
    }
    final sellerId = (promo['sellerId']?.toString() ?? '').trim();
    if (sellerId.isEmpty) {
      debugPrint('GiftEligibility: promo $promoId excluded (empty sellerId).');
      return null;
    }
    final sellerDoc = sellers[sellerId];
    if (sellerDoc == null) {
      debugPrint('GiftEligibility: promo $promoId excluded (seller $sellerId unreadable).');
      return null;
    }
    final sellerName = (sellerDoc['merchantName']?.toString().isNotEmpty == true)
        ? sellerDoc['merchantName'].toString()
        : (promo['sellerName']?.toString() ?? 'التاجر');

    // فحص صلاحية الهدية نفسها.
    final giftOfferId = (promo['giftOfferId']?.toString() ?? '').trim();
    if (giftOfferId.isEmpty) {
      debugPrint('GiftEligibility: promo $promoId excluded (empty giftOfferId).');
      return null;
    }
    final giftDoc = offers[giftOfferId];
    if (giftDoc == null || !isOfferActive(giftDoc)) {
      debugPrint('GiftEligibility: promo $promoId excluded (gift offer $giftOfferId missing/inactive).');
      return null;
    }

    final trigger = promo['trigger'];
    final triggerMap =
        trigger is Map ? Map<String, dynamic>.from(trigger) : <String, dynamic>{};
    final isMinOrder = triggerMap['type'] == 'min_order';
    final minValue = isMinOrder
        ? (triggerMap['value'] as num?)?.toDouble() ?? 0.0
        : 0.0;

    final lines = <GiftTriggerLine>[];
    if (!isMinOrder) {
      for (final line in giftTriggerLines(promo)) {
        final offerId = (line['offerId']?.toString() ?? '').trim();
        if (offerId.isEmpty) {
          debugPrint('GiftEligibility: promo $promoId excluded (trigger line without offerId).');
          return null;
        }
        final offerDoc = offers[offerId];
        // المحفز غير موجود أو موقوف -> العرض غير قابل للتنفيذ حالياً.
        if (offerDoc == null || !isOfferActive(offerDoc)) {
          debugPrint('GiftEligibility: promo $promoId excluded (trigger offer $offerId missing/inactive).');
          return null;
        }
        final units = offerDoc['units'] as List<dynamic>? ?? const [];
        final unitName = (line['unitName']?.toString() ?? '').trim();
        final unitIndex = (line['unitIndex'] as num?)?.toInt() ?? 0;
        final unit = _unitByIndexOrName(units, unitIndex, unitName);
        final price = (unit?['price'] as num?)?.toDouble() ??
            (offerDoc['price'] as num?)?.toDouble() ??
            0.0;
        lines.add(GiftTriggerLine(
          offerId: offerId,
          productId: (offerDoc['productId']?.toString().isNotEmpty == true)
              ? offerDoc['productId'].toString()
              : offerId,
          productName: (line['productName']?.toString().isNotEmpty == true)
              ? line['productName'].toString()
              : (offerDoc['productName']?.toString() ?? 'منتج'),
          unitName: unitName.isNotEmpty
              ? unitName
              : (unit?['unitName']?.toString() ?? 'وحدة'),
          unitIndex: units.isEmpty
              ? 0
              : unitIndex.clamp(0, units.length - 1),
          quantityBase: (line['triggerQuantityBase'] as num?)?.toInt() ?? 0,
          price: price,
          imageUrl: firstOfferImage(offerDoc),
        ));
      }
      if (lines.isEmpty) {
        debugPrint('GiftEligibility: promo $promoId excluded (no specific_item trigger lines).');
        return null;
      }
      if (lines.any((l) => l.quantityBase <= 0)) {
        debugPrint('GiftEligibility: promo $promoId excluded (non-positive trigger quantity).');
        return null;
      }
    }

    return EnrichedGift(
      promoId: promoId,
      sellerId: sellerId,
      sellerName: sellerName,
      promoName: (promo['promoName']?.toString() ?? 'عرض هدية').trim(),
      isMinOrder: isMinOrder,
      minOrderValue: minValue,
      triggers: lines,
      giftName: (promo['giftProductName']?.toString() ?? 'هدية').trim(),
      giftUnit: (promo['giftUnitName']?.toString() ?? 'وحدة').trim(),
      giftQty: (promo['giftQuantityPerBase'] as num?)?.toInt() ?? 1,
      giftImage: (promo['giftProductImage']?.toString() ?? '').trim(),
      expiry: promo.containsKey('expiryDate') ? parseGiftExpiry(promo['expiryDate']) : null,
      remaining: giftPromoRemaining(promo),
    );
  }

  static int _compareEnriched(EnrichedGift a, EnrichedGift b) {
    if (a.expiry != null && b.expiry != null) {
      final c = a.expiry!.compareTo(b.expiry!);
      if (c != 0) return c;
    } else if (a.expiry != null) {
      return -1;
    } else if (b.expiry != null) {
      return 1;
    }
    return b.remaining.compareTo(a.remaining);
  }

  static Future<List<String>> _buyerAreas(double? lat, double? lng) {
    return BuyerAreaResolver.resolveBuyerAreas(lat: lat, lng: lng);
  }

  /// أفضل N عروض مؤهلة للصفحة الرئيسية — خفيف: يفحص الحياة والتغطية أولاً،
  /// ويثري صور أول المرشحين فقط مع حد أقصى للفحص.
  /// الافتراضي 2 = عدد بطاقات قسم «اكسب هدايا» (لا تجلب الرئيسية أكثر).
  static Future<List<EnrichedGift>> fetchTopEligible({
    required FirebaseFirestore db,
    required double? lat,
    required double? lng,
    int needed = 2,
    int examineCap = 15,
    DateTime? nowOverride,
  }) async {
    final now = nowOverride ?? DateTime.now();
    final buyerAreas = await _buyerAreas(lat, lng);
    final promosSnap = await db
        .collection('giftPromos')
        .where('status', isEqualTo: 'active')
        .limit(examineCap * 2)
        .get();
    final liveDocs = promosSnap.docs
        .where((d) => isGiftPromoLive(d.data(), now))
        .take(examineCap)
        .toList();
    if (liveDocs.isEmpty) return const [];

    final sellerIds = liveDocs
        .map((d) => (d.data()['sellerId']?.toString() ?? '').trim())
        .where((s) => s.isNotEmpty)
        .toSet();
    final sellers = await _fetchDocsById(db, 'sellers', sellerIds);

    // ترتيب مبدئي: الأقرب انتهاءً أولاً.
    liveDocs.sort((a, b) {
      final ea = parseGiftExpiry(a.data()['expiryDate']);
      final eb = parseGiftExpiry(b.data()['expiryDate']);
      if (ea != null && eb != null) return ea.compareTo(eb);
      if (ea != null) return -1;
      if (eb != null) return 1;
      return 0;
    });

    final out = <EnrichedGift>[];
    for (final doc in liveDocs) {
      if (out.length >= needed) break;
      final data = doc.data();
      final sellerId = (data['sellerId']?.toString() ?? '').trim();
      final sellerDoc = sellers[sellerId];
      if (sellerDoc == null) continue;
      if (!sellerCoversBuyer(readSellerAreas(sellerDoc), buyerAreas)) continue;

      final needOfferIds = <String>{};
      final giftId = (data['giftOfferId']?.toString() ?? '').trim();
      if (giftId.isNotEmpty) needOfferIds.add(giftId);
      for (final line in giftTriggerLines(data)) {
        final oid = (line['offerId']?.toString() ?? '').trim();
        if (oid.isNotEmpty) needOfferIds.add(oid);
      }
      final trigger = data['trigger'];
      if (trigger is Map &&
          Map<String, dynamic>.from(trigger)['type'] == 'min_order' &&
          giftId.isEmpty) {
        continue;
      }
      final offers = await _fetchDocsById(db, 'productOffers', needOfferIds);
      final enriched = await _enrichOne(
        db: db,
        promoId: doc.id,
        promo: data,
        sellers: sellers,
        offers: offers,
        now: now,
      );
      if (enriched != null) out.add(enriched);
    }
    return out;
  }

  /// كل العروض المؤهلة لصفحة الهدايا الكاملة — بحد أقصى قابل للزيادة
  /// (limit escalation بدل cursor لأن الترشيح بعد الجلب).
  static Future<List<EnrichedGift>> fetchAllEligible({
    required FirebaseFirestore db,
    required double? lat,
    required double? lng,
    int queryLimit = 40,
    bool useCache = true,
    DateTime? nowOverride,
  }) async {
    final now = nowOverride ?? DateTime.now();
    final buyerAreas = await _buyerAreas(lat, lng);
    final key = '${cacheKeyFor(lat, lng, buyerAreas)}|$queryLimit';
    if (useCache &&
        _cacheKey == key &&
        _cacheAt != null &&
        DateTime.now().difference(_cacheAt!) < cacheTtl) {
      return _cacheAll;
    }

    final promosSnap = await db
        .collection('giftPromos')
        .where('status', isEqualTo: 'active')
        .limit(queryLimit)
        .get();
    final liveDocs = promosSnap.docs
        .where((d) => isGiftPromoLive(d.data(), now))
        .toList();
    if (liveDocs.isEmpty) {
      _cacheKey = key;
      _cacheAt = DateTime.now();
      _cacheAll = const [];
      return const [];
    }

    final sellerIds = liveDocs
        .map((d) => (d.data()['sellerId']?.toString() ?? '').trim())
        .where((s) => s.isNotEmpty)
        .toSet();
    final sellers = await _fetchDocsById(db, 'sellers', sellerIds);

    // تغطية التاجر أولاً (رخيص)، قبل جلب عروض المنتجات.
    final covered = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
    var skippedNoSeller = 0;
    var skippedNoCoverage = 0;
    for (final doc in liveDocs) {
      final data = doc.data();
      final sellerId = (data['sellerId']?.toString() ?? '').trim();
      final sellerDoc = sellers[sellerId];
      if (sellerDoc == null) {
        skippedNoSeller++;
        continue;
      }
      if (!sellerCoversBuyer(readSellerAreas(sellerDoc), buyerAreas)) {
        skippedNoCoverage++;
        continue;
      }
      covered.add(doc);
    }
    if (skippedNoSeller > 0 || skippedNoCoverage > 0) {
      debugPrint('GiftEligibility: fetchAll skipped $skippedNoSeller unreadable sellers, '
          '$skippedNoCoverage outside delivery coverage.');
    }
    if (covered.isEmpty) {
      _cacheKey = key;
      _cacheAt = DateTime.now();
      _cacheAll = const [];
      return const [];
    }

    final needOfferIds = <String>{};
    for (final doc in covered) {
      final data = doc.data();
      final giftId = (data['giftOfferId']?.toString() ?? '').trim();
      if (giftId.isNotEmpty) needOfferIds.add(giftId);
      for (final line in giftTriggerLines(data)) {
        final oid = (line['offerId']?.toString() ?? '').trim();
        if (oid.isNotEmpty) needOfferIds.add(oid);
      }
    }
    final offers = await _fetchDocsById(db, 'productOffers', needOfferIds);

    final out = <EnrichedGift>[];
    for (final doc in covered) {
      final enriched = await _enrichOne(
        db: db,
        promoId: doc.id,
        promo: doc.data(),
        sellers: sellers,
        offers: offers,
        now: now,
      );
      if (enriched != null) out.add(enriched);
    }
    out.sort(_compareEnriched);

    _cacheKey = key;
    _cacheAt = DateTime.now();
    _cacheAll = out;
    return out;
  }
}
