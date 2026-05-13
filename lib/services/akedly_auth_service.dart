import 'package:akedly/akedly.dart';

class AkedlyAuthService {
  // بياناتك الحقيقية من الداشبورد
  final String _apiKey = "f032dc4687c452cb7c340a91df69ed419e6a5330c3bb9b2f826828bf381e3624";
  final String _pipelineId = "6a02edb9dc826dd83e860ad1";
  
  // تعريف الكلاينت من المكتبة اللي إنت منزلها
  late final AkedlyClient _akedly;

  AkedlyAuthService() {
    _akedly = AkedlyClient(
      apiKey: _apiKey,
      pipelineId: _pipelineId,
    );
  }

  Future<AuthResult> sendOtpDetailed(String phoneNumber) async {
    try {
      // هنا المكتبة هي اللي بتبعت الـ OTP وبتتعامل مع الـ v1.2 داخلياً
      final verificationId = await _akedly.sendOTP(phoneNumber);
      
      if (verificationId != null) {
        // بنرجع الـ ID عشان نستخدمه في خطوة التأكيد
        return AuthResult.success(data: verificationId);
      } else {
        return AuthResult.failure(message: 'فشل إرسال كود التفعيل، تأكد من الرقم');
      }
    } catch (e) {
      return AuthResult.failure(message: 'خطأ: ${e.toString()}');
    }
  }

  Future<bool> verifyOtp(String verificationId, String otp) async {
    try {
      // التأكيد برضه عن طريق المكتبة
      final isValid = await _akedly.verifyOTP(verificationId, otp);
      return isValid;
    } catch (e) {
      print('OTP verification failed: $e');
      return false;
    }
  }
}

// الكلاس ده بنسيبه عشان شاشات الـ Login متعرفة عليه
class AuthResult {
  final bool isSuccess;
  final String? message;
  final String? data;

  AuthResult.success({this.data}) : isSuccess = true, message = null;
  AuthResult.failure({required this.message}) : isSuccess = false, data = null;
}