// lib/services/analytics_service.dart
import 'package:cloud_functions/cloud_functions.dart';

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