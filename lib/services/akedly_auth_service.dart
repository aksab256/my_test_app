import 'package:akedly/akedly.dart';

class AkedlyAuthService {
  final String _apiKey = "f032dc4687c452cb7c340a91df69ed419e6a5330c3bb9b2f826828bf381e3624";
  final String _pipelineId = "6a02edb9dc826dd83e860ad1";
  
  late final AkedlyClient _akedly;

  AkedlyAuthService() {
    _akedly = AkedlyClient(
      apiKey: _apiKey,
      pipelineId: _pipelineId,
    );
  }

  Future<AuthResult> sendOtpDetailed(String phoneNumber) async {
    try {
      // التعديل هنا: بنبعت الـ phoneNumber والـ _pipelineId سوا
      final verificationId = await _akedly.sendOTP(phoneNumber, _pipelineId);
      
      if (verificationId != null) {
        return AuthResult.success(data: verificationId);
      } else {
        return AuthResult.failure(message: 'فشل إرسال كود التفعيل');
      }
    } catch (e) {
      return AuthResult.failure(message: 'خطأ: ${e.toString()}');
    }
  }

  Future<bool> verifyOtp(String verificationId, String otp) async {
    try {
      // هنا برضه لو طلب 3 arguments هنضيف الـ _pipelineId في الآخر
      final isValid = await _akedly.verifyOTP(verificationId, otp);
      return isValid;
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