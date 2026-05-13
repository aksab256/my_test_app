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
    String p = phoneNumber.trim();
    if (p.startsWith('0')) { p = '2$p'; } 
    else if (!p.startsWith('2') && !p.startsWith('+')) { p = '2$p'; }

    try {
      // التعديل الجوهري: بعتنا الـ p والـ _pipelineId عشان نحل خطأ الـ "2 required"
      final verificationId = await _akedly.sendOTP(p, _pipelineId);
      
      if (verificationId != null) {
        return AuthResult.success(data: verificationId);
      } else {
        return AuthResult.failure(message: 'Failed to send OTP');
      }
    } on AkedlyException catch (e) {
      return AuthResult.failure(message: e.message);
    } catch (e) {
      return AuthResult.failure(message: 'Network error: ${e.toString()}');
    }
  }

  Future<bool> verifyOtp(String verificationId, String otp) async {
    try {
      // التأكد من تمرير المعاملات بالترتيب الصح (ID ثم الكود)
      final isValid = await _akedly.verifyOTP(verificationId, otp);
      return isValid;
    } catch (e) {
      return false;
    }
  }
}

// كلاس النتيجة زي ما هو في المثال عشان التنظيم
class AuthResult {
  final bool isSuccess;
  final String? message;
  final String? data;
  AuthResult.success({this.data}) : isSuccess = true, message = null;
  AuthResult.failure({required this.message}) : isSuccess = false, data = null;
}