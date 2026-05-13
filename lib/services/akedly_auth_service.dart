import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:akedly_shield/akedly_shield.dart'; // تأكد من إضافة هذه المكتبة في pubspec

class AkedlyAuthService {
  final String _apiKey = "f032dc4687c452cb7c340a91df69ed419e6a5330c3bb9b2f826828bf381e3624";
  final String _pipelineId = "6a02edb9dc826dd83e860ad1";

  Future<AuthResult> sendOtpDetailed(String phoneNumber) async {
    try {
      // الخطوة 1: طلب التحدي (Get Challenge)
      final challengeRes = await http.get(
        Uri.parse('https://api.akedly.io/api/v1.2/transactions/challenge?APIKey=$_apiKey&pipelineID=$_pipelineId'),
      );
      
      final challengeData = jsonDecode(challengeRes.body)['data'];
      
      // الخطوة 2: حل التحدي باستخدام Shield SDK
      // الـ SDK بيعمل SHA256 للـ challenge مع nonce لحد ما يوصل للصعوبة المطلوبة
      final solution = await AkedlyShield.solvePow(
        challengeData['challenge'], 
        challengeData['difficulty']
      );

      // الخطوة 3: إرسال الـ OTP مع حل التحدي
      final response = await http.post(
        Uri.parse('https://api.akedly.io/api/v1.2/transactions/send'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'APIKey': _apiKey,
          'pipelineID': _pipelineId,
          'verificationAddress': {'phoneNumber': phoneNumber},
          'powSolution': {
            'challengeToken': challengeData['challengeToken'],
            'nonce': solution.nonce,
          },
        }),
      );

      final resData = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return AuthResult.success(data: resData['data']['transactionReqID']);
      } else {
        return AuthResult.failure(message: resData['message'] ?? 'فشل الإرسال');
      }
    } catch (e) {
      return AuthResult.failure(message: 'خطأ تقني: $e');
    }
  }

  // خطوة التحقق (Verify) كما هي في الخطوة 4 بالمانيوال
  Future<bool> verifyOtp(String transactionReqID, String otp) async {
    final response = await http.post(
      Uri.parse('https://api.akedly.io/api/v1.2/transactions/verify'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'transactionReqID': transactionReqID, 'otp': otp}),
    );
    return response.statusCode == 200;
  }
}

class AuthResult {
  final bool isSuccess;
  final String? message;
  final String? data;
  AuthResult.success({this.data}) : isSuccess = true, message = null;
  AuthResult.failure({required this.message}) : isSuccess = false, data = null;
}