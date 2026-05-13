import 'dart:convert';
import 'package:http/http.dart' as http;

/// خدمة التحقق من الهوية عبر Akedly لمنصة "رابيه أحلى"
/// تُستخدم لإدارة "العهدة" وتأمين "نقاط الأمان" للمناديب والموردين.
class AkedlyAuthService {
  // الـ API Key المحدث من لوحة تحكم Akedly
  final String apiKey = "f032dc4687c452cb7c340a91df69ed419e6a5330c3bb9b2f826828bf381e3624";
  
  // الـ Pipeline ID الخاص بـ Aksab (المستخرج من لوحة التحكم)
  final String pipelineId = "6a02edb9dc826dd83e860ad1"; 

  /// إرسال كود التحقق (OTP) لبدء عملية استلام العهدة
  Future<String?> sendOtp(String phoneNumber) async {
    final url = Uri.parse("https://api.akedly.io/v1/otp/send");
    
    // --- رسائل الكونسول لتتبع العملية ---
    print("--- [رابيه أحلى] محاولة إرسال OTP ---");
    print("المستلم (Recipient): $phoneNumber");
    print("مسار العملية (Pipeline ID): $pipelineId");

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
          "ttl": 300, // صالح لمدة 5 دقائق لضمان وصوله للمندوب في الميدان
        }),
      );

      // طباعة الرد الكامل من السيرفر للتشخيص (Critical Logs)
      print("كود حالة الرد (Status Code): ${response.statusCode}");
      print("محتوى الرد الخام (Raw Body): ${response.body}");

      final responseData = jsonDecode(response.body);
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        print("✅ نجاح: تم إرسال الكود. Step ID المستلم: ${responseData['step_id']}");
        return responseData['step_id'];
      } else {
        // طباعة الرسالة القادمة من Akedly لتحديد سبب الرفض (رصيد، رقم خطأ، إلخ)
        print("❌ تنبيه من Akedly: ${responseData['message'] ?? 'فشل مجهول'}");
        return null;
      }
    } catch (error) {
      print("⚠️ خطأ في الاتصال بالشبكة (Aksab-OTP-Error): $error");
      return null;
    }
  }

  /// التحقق من الكود لإتمام "تأكيد العهدة" وتخصيص "نقاط التأمين"
  Future<bool> verifyOtp(String stepId, String code) async {
    final url = Uri.parse("https://api.akedly.io/v1/otp/verify");
    
    print("--- [رابيه أحلى] محاولة تأكيد العهدة ---");
    print("المعرف (Step ID): $stepId | الكود المدخل: $code");

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

      print("حالة تأكيد العهدة (Verify Status): ${response.statusCode}");
      print("رد تأكيد العهدة (Verify Body): ${response.body}");

      if (response.statusCode == 200) {
        print("✅ تم تأكيد العهدة بنجاح. سيتم الآن تخصيص نقاط الأمان.");
        return true;
      } else {
        final responseData = jsonDecode(response.body);
        print("❌ فشل التحقق من العهدة: ${responseData['message']}");
        return false;
      }
    } catch (error) {
      print("⚠️ خطأ تقني أثناء تأكيد العهدة: $error");
      return false;
    }
  }
}