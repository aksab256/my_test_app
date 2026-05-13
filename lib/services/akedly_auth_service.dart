import 'dart:convert';
import 'package:http/http.dart' as http;

class AkedlyAuthService {
  final String _apiKey = "f032dc4687c452cb7c340a91df69ed419e6a5330c3bb9b2f826828bf381e3624";
  final String _pipelineId = "6a02edb9dc826dd83e860ad1";
  final String _baseUrl = "https://api.akedly.io/api/v1.2"; // المسار اللي السيرفر طلبه

  Future<AuthResult> sendOtpDetailed(String phoneNumber) async {
    String p = phoneNumber.trim();
    if (p.startsWith('0')) { p = '2$p'; }
    
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/transactions'),
        headers: {
          'X-API-KEY': _apiKey,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'pipeline_id': _pipelineId,
          'phone_number': p,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return AuthResult.success(data: data['step_id'] ?? data['transaction_id']);
      } else {
        return AuthResult.failure(message: data['message'] ?? 'فشل الإرسال');
      }
    } catch (e) {
      return AuthResult.failure(message: e.toString());
    }
  }

  Future<bool> verifyOtp(String stepId, String otp) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/transactions/verify'),
        headers: {
          'X-API-KEY': _apiKey,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'pipeline_id': _pipelineId,
          'step_id': stepId,
          'otp': otp,
        }),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}