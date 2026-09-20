// lib/services/analytics_service.dart
import 'package:cloud_functions/cloud_functions.dart';

/// Event names emitted to the internal pipeline (logAppEvent callable ->
/// app_analytics_logs -> analytics_daily_*). Only behavioral telemetry is
/// emitted here; business facts (orders, payments, delivery, settlements)
/// already live in production collections and must NOT be duplicated.
class AnalyticsEvents {
  static const String clickViewOffers = 'click_view_offers'; // existing
  static const String viewProduct = 'view_product';
  static const String searchProducts = 'search_products';
  static const String addToCart = 'add_to_cart';
  static const String checkoutStarted = 'checkout_started';
}

/// Pure-Dart payload builder (unit-testable, no Flutter/Firebase deps).
/// Contract: userId + timestamp are stamped server-side by logAppEvent;
/// clients send only eventName + eventData. Search terms are truncated to
/// bound PII/volume; numeric fields are coerced defensively.
class AnalyticsEventBuilder {
  static const int maxSearchTermLength = 100;

  static String truncateTerm(String term) {
    final t = term.trim();
    if (t.length <= maxSearchTermLength) return t;
    return t.substring(0, maxSearchTermLength);
  }

  static double numOrZero(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '') ?? 0.0;
  }

  static int intOrZero(dynamic v) {
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }

  static Map<String, dynamic> viewProduct({
    required String productId,
    String? productName,
    String? mainId,
    String? subId,
    String? role,
    String screen = 'product_details',
  }) {
    return {
      'productId': productId,
      if (productName != null) 'productName': productName,
      if (mainId != null) 'mainId': mainId,
      if (subId != null) 'subId': subId,
      if (role != null) 'role': role,
      'screen': screen,
    };
  }

  static Map<String, dynamic> searchProducts({
    required String searchTerm,
    String? mainCategoryId,
    String? subCategoryId,
    String? sortOption,
    required int resultCount,
    String? role,
  }) {
    return {
      'searchTerm': truncateTerm(searchTerm),
      if (mainCategoryId != null && mainCategoryId.isNotEmpty)
        'mainCategoryId': mainCategoryId,
      if (subCategoryId != null && subCategoryId.isNotEmpty)
        'subCategoryId': subCategoryId,
      if (sortOption != null) 'sortOption': sortOption,
      'resultCount': resultCount,
      if (role != null) 'role': role,
      'screen': 'search',
    };
  }

  static Map<String, dynamic> addToCart({
    required String productId,
    String? offerId,
    String? sellerId,
    required int quantity,
    required double price,
    String? unit,
    String? role,
    String screen = 'product',
  }) {
    return {
      'productId': productId,
      if (offerId != null && offerId.isNotEmpty) 'offerId': offerId,
      if (sellerId != null && sellerId.isNotEmpty) 'sellerId': sellerId,
      'quantity': quantity,
      'price': price,
      if (unit != null) 'unit': unit,
      if (role != null) 'role': role,
      'screen': screen,
    };
  }

  static Map<String, dynamic> checkoutStarted({
    required int itemsCount,
    required double totalAmount,
    required List<String> sellerIds,
    String? role,
  }) {
    return {
      'itemsCount': itemsCount,
      'totalAmount': totalAmount,
      'sellerIds': sellerIds,
      if (role != null) 'role': role,
      'screen': 'checkout',
    };
  }
}

class AnalyticsService {
  static final FirebaseFunctions _functions = FirebaseFunctions.instance;

  /// 🎯 الدالة العامة المساعدة لاستدعاء Cloud Function `logAppEvent`
  static Future<void> logEvent({
    required String eventName,
    Map<String, dynamic>? eventData,
  }) async {
    try {
      final HttpsCallable callable = _functions.httpsCallable('logAppEvent');
      
      // نداء الفانكشن وتمرير البيانات
      await callable.call({
        'eventName': eventName,
        'eventData': eventData ?? {},
      });
      
      print('📊 Event logged successfully: $eventName');
    } catch (e) {
      // طباعة الخطأ في الكونسول لتسهيل التتبع بدون تعطيل تجربة المشتري
      print('⚠️ Analytics Service Error ($eventName): $e');
    }
  }
}
