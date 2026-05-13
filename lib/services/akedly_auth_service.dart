import 'dart:convert';
import 'package:http/http.dart' as http;

class AkedlyAuthService {
  final String apiKey = "f032dc4687c452cb7c340a91df69ed419e6a5330c3bb9b2f826828bf381e3624";
  final String pipelineId = "6a02edb9dc826dd83e860ad1"; 

  // تأكد من تغيير الاسم هنا ليكون sendOtpDetailed
  Future<Map<String, dynamic>> sendOtpDetailed(String phoneNumber) async {
    final url = Uri.parse("https://api.akedly.io/v1/otp/send");
    
    String p = phoneNumber.trim();
    if (p.startsWith('0')) p = '2' + p;

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
          "ttl": 300,
        }),
      );

      // بنرجع الرد الكامل بدون أي تعديل ليرسمه الـ UI
      return {
        "status": response.statusCode,
        "body": response.body, 
        "success": response.statusCode == 200 || response.statusCode == 201
      };
    } catch (e) {
      return {"status": 500, "body": "Network Error: ${e.toString()}", "success": false};
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
        },
        body: jsonEncode({"step_id": stepId, "code": code}),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}