import 'dart:convert';
import 'package:http/http.dart' as http;

/// خدمة التحقق المضمونة لمنصة "رابيه أحلى"
class AkedlyAuthService {
  final String apiKey = "f032dc4687c452cb7c340a91df69ed419e6a5330c3bb9b2f826828bf381e3624";
  final String pipelineId = "6a02edb9dc826dd83e860ad1"; 

  /// تنظيف وتنسيق الرقم لضمان قبوله عالمياً ومحلياً
  String _formatPhoneNumber(String phone) {
    String p = phone.trim();
    // إذا كان الرقم يبدأ بـ 01، نحذف الصفر ونضيف كود مصر 2
    if (p.startsWith('01')) {
      p = '2' + p; 
    }
    // إذا كان يبدأ بـ +20، نحذف الـ +
    if (p.startsWith('+')) {
      p = p.substring(1);
    }
    // التأكد من أن الرقم يبدأ بـ 20 لضمان وصول الـ SMS
    if (!p.startsWith('20') && p.length == 11 && p.startsWith('01')) {
       p = '2' + p;
    }
    return p;
  }

  Future<String?> sendOtp(String phoneNumber) async {
    final url = Uri.parse("https://api.akedly.io/v1/otp/send");
    
    // تنسيق الرقم قبل الإرسال (مثلاً: من 010 إلى 2010)
    final formattedPhone = _formatPhoneNumber(phoneNumber);

    print("--- [Aksab-Tech] Sending OTP ---");
    print("Original: $phoneNumber | Formatted: $formattedPhone");

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
          "recipient": formattedPhone, // نرسل الرقم المنسق
          "ttl": 300, 
        }),
      );

      print("Status: ${response.statusCode} | Body: ${response.body}");

      final responseData = jsonDecode(response.body);
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        // Akedly أحياناً يرجع النجاح في حقل 'data' أو مباشرة
        return responseData['step_id'] ?? responseData['data']?['step_id'];
      } else {
        print("❌ Akedly Error: ${responseData['message']}");
        return null;
      }
    } catch (error) {
      print("⚠️ Network Error: $error");
      return null;
    }
  }

  Future<bool> verifyOtp(String stepId, String code) async {
    final url = Uri.parse("https://api.akedly.io/v1/otp/verify");
    
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

      if (response.statusCode == 200) {
        print("✅ OTP Verified - Assets Secured.");
        return true;
      }
      return false;
    } catch (error) {
      return false;
    }
  }
}