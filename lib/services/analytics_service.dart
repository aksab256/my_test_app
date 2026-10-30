// lib/services/analytics_service.dart
import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Event names emitted to the internal pipeline (logAppEvent callable ->
/// app_analytics_logs -> analytics_daily_*). The list is intentionally NOT
/// closed: new behavioral event names are allowed without redesign, the
/// backend aggregates any eventName generically (product views get an extra
/// per-product rollup when payload carries productId/productName).
/// Business facts (orders, payments, delivery, settlements) already live in
/// production collections and must NOT be duplicated here.
class AnalyticsEvents {
  static const String clickViewOffers = 'click_view_offers'; // existing
  static const String viewProduct = 'view_product';
  static const String searchProducts = 'search_products';
  static const String addToCart = 'add_to_cart';
  static const String checkoutStarted = 'checkout_started';
  // Session / lifecycle (Phase 1).
  static const String appOpenFirst = 'app_open_first';
  static const String appOpen = 'app_open';
  static const String appForeground = 'app_foreground';
  static const String screenView = 'screen_view';
  // Outcome / identity.
  static const String orderPlaced = 'order_placed';
  static const String orderFailed = 'order_failed';
  static const String login = 'login';
  static const String logout = 'logout';
  static const String appError = 'app_error';
}

/// Pure-Dart payload builder (unit-testable, no Flutter/Firebase deps).
/// Contract: userId + timestamp are stamped server-side by logAppEvent;
/// clients send only eventName + eventData. Search terms are truncated to
/// bound PII/volume; numeric fields are coerced defensively. No GPS, no
/// passwords/tokens, no free-form user content beyond truncated search text.
class AnalyticsEventBuilder {
  static const int maxSearchTermLength = 100;
  static const int maxScreenNameLength = 120;

  static String truncateTerm(String term) {
    final t = term.trim();
    if (t.length <= maxSearchTermLength) return t;
    return t.substring(0, maxSearchTermLength);
  }

  static String truncateScreen(String screen) {
    final t = screen.trim();
    if (t.length <= maxScreenNameLength) return t;
    return t.substring(0, maxScreenNameLength);
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

  static Map<String, dynamic> screenView({
    required String screen,
    String? role,
  }) {
    return {
      'screen': truncateScreen(screen),
      if (role != null) 'role': role,
    };
  }

  static Map<String, dynamic> orderPlaced({
    required List<String> orderIds,
    required int itemsCount,
    required double totalAmount,
    String? role,
  }) {
    return {
      'orderIds': orderIds,
      'ordersCount': orderIds.length,
      'itemsCount': itemsCount,
      'totalAmount': totalAmount,
      if (role != null) 'role': role,
      'screen': 'checkout',
    };
  }

  static Map<String, dynamic> orderFailed({
    required String stage,
    String? reason,
    String? role,
  }) {
    return {
      'stage': stage,
      if (reason != null) 'reason': reason,
      if (role != null) 'role': role,
      'screen': 'checkout',
    };
  }

  static Map<String, dynamic> login({
    required String method,
    String? role,
  }) {
    return {
      'method': method,
      if (role != null) 'role': role,
      'screen': 'login',
    };
  }
}

/// Pure-Dart session helper (unit-testable): one session id per process,
/// first-open detection is persisted by the service, not here.
class AnalyticsSession {
  static String newSessionId({required int nowMs, required Random random}) {
    final rand = random.nextInt(36 * 36 * 36 * 36 * 36 * 36);
    return '$nowMs-${rand.toRadixString(36).padLeft(6, '0')}';
  }
}

class _QueuedEvent {
  final String eventName;
  final Map<String, dynamic> eventData;
  final String clientEventId;
  final String sessionId;
  final String appVersion;
  final String platform;

  _QueuedEvent({
    required this.eventName,
    required this.eventData,
    required this.clientEventId,
    required this.sessionId,
    required this.appVersion,
    required this.platform,
  });

  Map<String, dynamic> toJson() => {
        'eventName': eventName,
        'eventData': eventData,
        'clientEventId': clientEventId,
        'sessionId': sessionId,
        'appVersion': appVersion,
        'platform': platform,
      };

  static _QueuedEvent? fromJson(Map<String, dynamic> json) {
    try {
      return _QueuedEvent(
        eventName: json['eventName'] as String,
        eventData: Map<String, dynamic>.from(json['eventData'] as Map),
        clientEventId: json['clientEventId'] as String,
        sessionId: (json['sessionId'] as String?) ?? '',
        appVersion: (json['appVersion'] as String?) ?? '',
        platform: (json['platform'] as String?) ?? '',
      );
    } catch (_) {
      return null;
    }
  }
}

class AnalyticsService {
  static final FirebaseFunctions _functions = FirebaseFunctions.instance;

  static const String _queuePrefsKey = 'analytics_event_queue_v1';
  static const String _firstOpenPrefsKey = 'analytics_first_open_done_v1';
  static const int _maxQueueSize = 100;
  static const Duration _callTimeout = Duration(seconds: 8);

  static String _appVersion = 'unknown';
  static String _sessionId = '';
  static String _platform = 'unknown';
  static bool _configured = false;
  static bool _flushInFlight = false;

  /// Must be called once at app start (before first logEvent). Safe to call
  /// more than once; later calls are ignored.
  static Future<void> configure({required String appVersion}) async {
    if (_configured) return;
    _configured = true;
    _appVersion = appVersion;
    _platform = defaultTargetPlatform.name;
    _sessionId = AnalyticsSession.newSessionId(
      nowMs: DateTime.now().millisecondsSinceEpoch,
      random: Random(),
    );
    // Drain events queued while offline in a previous run.
    unawaited(_flushQueue());
  }

  /// Session id for this process (empty until [configure] runs).
  static String get sessionId => _sessionId;

  static String _newClientEventId() {
    final r = Random();
    final a = r.nextInt(1 << 32).toRadixString(36);
    final b = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    return 'ev-$b-$a';
  }

  /// Fire-and-forget: never throws, never blocks checkout. Events are
  /// queued persistently and retried; the backend dedupes by clientEventId.
  static Future<void> logEvent({
    required String eventName,
    Map<String, dynamic>? eventData,
    String? clientEventId,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final queue = _readQueue(prefs);
      queue.add(_QueuedEvent(
        eventName: eventName,
        eventData: eventData ?? const {},
        clientEventId: clientEventId ?? _newClientEventId(),
        sessionId: _sessionId,
        appVersion: _appVersion,
        platform: _platform,
      ));
      while (queue.length > _maxQueueSize) {
        queue.removeAt(0); // drop oldest, keep newest
      }
      await prefs.setString(
          _queuePrefsKey, jsonEncode(queue.map((e) => e.toJson()).toList()));
    } catch (e) {
      debugPrint('⚠️ Analytics queue error ($eventName): $e');
    }
    unawaited(_flushQueue());
  }

  static List<_QueuedEvent> _readQueue(SharedPreferences prefs) {
    try {
      final raw = prefs.getString(_queuePrefsKey);
      if (raw == null || raw.isEmpty) return [];
      final list = jsonDecode(raw) as List;
      return list
          .whereType<Map>()
          .map((m) => _QueuedEvent.fromJson(
              Map<String, dynamic>.from(m as Map)))
          .whereType<_QueuedEvent>()
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> _flushQueue() async {
    if (_flushInFlight) return;
    _flushInFlight = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      var queue = _readQueue(prefs);
      while (queue.isNotEmpty) {
        final head = queue.first;
        try {
          final HttpsCallable callable =
              _functions.httpsCallable('logAppEvent');
          await callable.call({
            'eventName': head.eventName,
            'eventData': head.eventData,
            'clientEventId': head.clientEventId,
            'sessionId': head.sessionId,
            'appVersion': head.appVersion,
            'platform': head.platform,
          }).timeout(_callTimeout);
          queue.removeAt(0);
          await prefs.setString(_queuePrefsKey,
              jsonEncode(queue.map((e) => e.toJson()).toList()));
        } catch (e) {
          // Offline or backend error: keep the remainder for a later run.
          debugPrint('⚠️ Analytics flush paused: $e');
          break;
        }
      }
    } catch (e) {
      debugPrint('⚠️ Analytics flush error: $e');
    } finally {
      _flushInFlight = false;
    }
  }

  /// Logs app_open_first once ever (per install), then app_open.
  /// Returns true when this was the first open.
  static Future<bool> logAppOpen() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final done = prefs.getBool(_firstOpenPrefsKey) ?? false;
      if (!done) {
        await logEvent(eventName: AnalyticsEvents.appOpenFirst);
        await prefs.setBool(_firstOpenPrefsKey, true);
      }
      await logEvent(eventName: AnalyticsEvents.appOpen);
      return !done;
    } catch (e) {
      debugPrint('⚠️ Analytics app-open error: $e');
      return false;
    }
  }
}
