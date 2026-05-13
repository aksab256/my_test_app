import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart'; // للعمليات الحسابية

class AkedlyAuthService {
  final String _apiKey = "f032dc4687c452cb7c340a91df69ed419e6a5330c3bb9b2f826828bf381e3624";
  final String _pipelineId = "6a02edb9dc826dd83e860ad1";

  // دالة حل التحدي يدوياً (بديل للمكتبة الخارجية)
  int _solveChallenge(String challenge, int difficulty) {
    int nonce = 0;
    String target = '0' * difficulty;
    while (true) {
      String input = "$challenge:$nonce";
      String hash = sha256.convert(utf8.encode(input)).toString();
      if (hash.startsWith(target)) {
        return nonce;
      }
      nonce++;
    }
  }

  Future<AuthResult> sendOtpDetailed(String phoneNumber) async {
    try {
      // 1. Get Challenge
      final challengeRes = await http.get(
        Uri.parse('https://api.akedly.io/api/v1.2/transactions/challenge?APIKey=$_apiKey&pipelineID=$_pipelineId'),
      );
      
      final challengeData = jsonDecode(challengeRes.body)['data'];
      
      // 2. Solve Challenge (Manual)
      final nonce = _solveChallenge(
        challengeData['challenge'], 
        challengeData['difficulty']
      );

      // 3. Send OTP
      final response = await http.post(
        Uri.parse('https://api.akedly.io/api/v1.2/transactions/send'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'APIKey': _apiKey,
          'pipelineID': _pipelineId,
          'verificationAddress': {'phoneNumber': phoneNumber},
          'powSolution': {
            'challengeToken': challengeData['challengeToken'],
            'nonce': nonce,
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

  Future<bool> verifyOtp(String transactionReqID, String otp) async {
    try {
      final response = await http.post(
        Uri.parse('https://api.akedly.io/api/v1.2/transactions/verify'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'transactionReqID': transactionReqID, 'otp': otp}),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}

class AuthResult {
  final bool isSuccess;
  final String? message;
  final String? data;
  AuthResult.success({this.data}) : isSuccess = true, message = null;
  AuthResult.failure({required this.message}) : isSuccess = false, data = null;
}