// lib/services/notification_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class NotificationService {
  static const String _lambdaUrl = 'https://9ayce138ig.execute-api.us-east-1.amazonaws.com/V1/nofiction';

  static Future<void> broadcastPromoNotification({
    required String sellerId,
    required String sellerName,
    required String promoName,
    required List<dynamic> deliveryAreas,
    String? productId, // الـ ID عشان حماية الـ 6 ساعات في اللمدا
  }) async {
    try {
      debugPrint("🚀 Sending Broadcast Command to Lambda...");

      // الموبايل دلوقتى مش بيعمل Query خالص
      // بيبعت بس الداتا الأساسية والمناطق واللمدا هي اللي بتفلتر في السيرفر
      final payload = {
        "action": "BROADCAST_BY_AREA", 
        "sellerId": sellerId,
        "productId": productId ?? "general_gift",
        "deliveryAreas": deliveryAreas, // قائمة المدن [القاهرة, الجيزة..]
        "title": "عرض هدايا من $sellerName 🎁",
        "message": "وصلك عرض جديد: $promoName. اطلبه الآن من التطبيق!",
      };

      final response = await http.post(
        Uri.parse(_lambdaUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        debugPrint("✅ Lambda received the broadcast command");
      } else {
        debugPrint("⚠️ Lambda returned status: ${response.statusCode}");
      }
    } catch (e) {
      // بنخلي الخطأ صامت (Silent) عشان تجربة التاجر ما تتاثرش بشاشة سوداء
      debugPrint("🚨 Notification Service Error: $e");
    }
  }
}

