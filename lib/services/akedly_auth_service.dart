import 'dart:convert';
import 'package:http/http.dart' as http;

class AkedlyAuthService {
  // الـ API Key الخاص بك من منصة Akedly (محدث)
  final String apiKey = "f032dc4687c452cb7c340a91df69ed419e6a5330c3bb9b2f826828bf381e3624";
  
  // الـ Pipeline ID المستخرج من لوحة التحكم (Aksab Pipeline)
  final String pipelineId = "6a02edb9dc826dd83e860ad1"; 

  // دالة إرسال كود التحقق للمندوب أو المستخدم لشركة أسواق أكسب
  Future<String?> sendOtp(String phoneNumber) async {
    final url = Uri.parse("https://api.akedly.io/v1/otp/send");
    
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
          "ttl": 300, // الكود صالح لمدة 5 دقائق لضمان وصوله للمندوب
        }),
      );

      final responseData = jsonDecode(response.body);
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        // نرجّح الـ step_id لاستخدامه في عملية التحقق اللاحقة
        return responseData['step_id'];
      } else {
        // طباعة الرسالة القادمة من السيرفر لتسهيل المعالجة
        print("خطأ من Akedly: ${responseData['message']}");
        return null;
      }
    } catch (error) {
      print("فشل الاتصال بمزود الخدمة في أسواق أكسب: $error");
      return null;
    }
  }

  // دالة التحقق من الكود لفتح "العهدة" وإدارة "نقاط التأمين" لضمان النقل الآمن
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
        // تم تأكيد الهوية بنجاح، يمكن الآن المتابعة لإدارة العهدة
        return true;
      } else {
        final responseData = jsonDecode(response.body);
        print("كود التحقق غير صحيح: ${responseData['message']}");
        return false;
      }
    } catch (error) {
      print("خطأ أثناء عملية التحقق من العهدة: $error");
      return false;
    }
  }
}