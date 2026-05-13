import 'dart:convert';
import 'package:http/http.dart' as http;

class AkedlyAuthService {
  // البيانات المستخرجة من لوحة تحكم Akedly
  final String apiKey = "f032dc4687c452cb7c340a91df69ed419e6a5330c3bb9b2f826828bf381e3624";
  final String pipelineId = "6a02edb9dc826dd83e860ad1"; 

  /// إرسال طلب OTP واستلام الرد التفصيلي
  /// تم تحديث المسار إلى /create بناءً على توثيق V1.0 لحل مشكلة 404
  Future<Map<String, dynamic>> sendOtpDetailed(String phoneNumber) async {
    // المسار الصحيح لنسخة V1.0 هو create لإنشاء طلب التحقق
    final url = Uri.parse("https://api.akedly.io/v1/otp/create");
    
    // تنسيق الرقم لضمان وصوله بشكل دولي سليم (مثال: 201021070462)
    String p = phoneNumber.trim();
    if (p.startsWith('0')) {
      p = '2$p'; // تحويل 010 إلى 2010
    } else if (!p.startsWith('2') && !p.startsWith('+')) {
      p = '2$p';
    }

    try {
      final response = await http.post(
        url,
        headers: {
          "Authorization": "Bearer $apiKey",
          "Content-Type": "application/json",
          "Accept": "application/json",
        },
        body: jsonEncode({
          "pipeline_id": pipelineId,
          "recipient": p,
          "ttl": 300, // مدة صلاحية الكود 5 دقائق
        }),
      );

      // نرسل تفاصيل الرد كاملة لكي تظهر في صندوق الـ Live Log بالواجهة
      // النجاح في Akedly V1.0 غالباً ما يكون Code 200 أو 201
      bool isSuccess = response.statusCode == 200 || response.statusCode == 201;

      return {
        "status": response.statusCode,
        "body": response.body, 
        "success": isSuccess
      };
    } catch (e) {
      return {
        "status": 500, 
        "body": "خطأ في الاتصال بالسيرفر: ${e.toString()}", 
        "success": false
      };
    }
  }

  /// التحقق من الكود الذي أدخله المستخدم
  Future<bool> verifyOtp(String stepId, String code) async {
    final url = Uri.parse("https://api.akedly.io/v1/otp/verify");
    try {
      final response = await http.post(
        url,
        headers: {
          "Authorization": "Bearer $apiKey",
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "step_id": stepId, 
          "code": code
        }),
      );
      
      // إذا كان الرد 200 يعني الكود صحيح
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}