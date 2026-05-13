import 'dart:convert';
import 'package:http/http.dart' as http;

class AkedlyAuthService {
  // الـ API Key المحدث من لوحة تحكم Akedly
  final String apiKey = "f032dc4687c452cb7c340a91df69ed419e6a5330c3bb9b2f826828bf381e3624";
  
  // الـ Pipeline ID الخاص بـ Aksab (المستخرج من الصورة)
  final String pipelineId = "6a02edb9dc826dd83e860ad1"; 

  // دالة إرسال كود التحقق
  Future<String?> sendOtp(String phoneNumber) async {
    final url = Uri.parse("https://api.akedly.io/v1/otp/send");
    
    print("--- محاولة إرسال OTP لشركة رابية أحلى ---");
    print("Recipient: $phoneNumber");
    print("Pipeline ID: $pipelineId");

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
          "recipient": phoneNumber,
          "ttl": 300,
        }),
      );

      print("Status Code: ${response.statusCode}");
      print("Raw Response Body: ${response.body}"); // ده أهم سطر في الكونسول حالياً

      final responseData = jsonDecode(response.body);
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        print("نجاح: تم استلام step_id: ${responseData['step_id']}");
        return responseData['step_id'];
      } else {
        // تشخيص دقيق للخطأ بناءً على رد السيرفر
        print("تنبيه Akedly: ${responseData['message'] ?? 'خطأ غير معروف'}");
        return null;
      }
    } catch (error) {
      print("فشل اتصال شبكة (Network Exception): $error");
      return null;
    }
  }

  // دالة التحقق من الكود لإدارة العهدة ونقاط الأمان
  Future<bool> verifyOtp(String stepId, String code) async {
    final url = Uri.parse("https://api.akedly.io/v1/otp/verify");
    
    print("--- محاولة التحقق من الكود لفتح العهدة ---");
    print("Step ID: $stepId | Code: $code");

    try {
      final response = await http.post(
        url,
        headers: {
          "Authorization": "Bearer $apiKey",
          "Content-Type": "application/json",
          "Accept": "application/json",
        },
        body: jsonEncode({
          "step_id": stepId,
          "code": code,
        }),
      );

      print("Verify Status Code: ${response.statusCode}");
      print("Verify Response Body: ${response.body}");

      if (response.statusCode == 200) {
        print("تم تأكيد العهدة بنجاح ✅");
        return true;
      } else {
        final responseData = jsonDecode(response.body);
        print("فشل التحقق: ${responseData['message']}");
        return false;
      }
    } catch (error) {
      print("خطأ أثناء عملية التحقق من العهدة: $error");
      return false;
    }
  }
}