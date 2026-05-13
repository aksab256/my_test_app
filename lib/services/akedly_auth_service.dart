import 'package:akedly/akedly.dart';

class AkedlyAuthService {
  // بياناتك اللي في الكود القديم (مظبوطة)
  final String _apiKey = "f032dc4687c452cb7c340a91df69ed419e6a5330c3bb9b2f826828bf381e3624";
  final String _pipelineId = "6a02edb9dc826dd83e860ad1";

  late final AkedlyClient _akedly;

  AkedlyAuthService() {
    _akedly = AkedlyClient(
      apiKey: _apiKey,
      pipelineId: _pipelineId,
    );
  }

  /// إرسال طلب OTP (التعديل هنا حسب التوثيق الجديد)
  Future<Map<String, dynamic>> sendOtpDetailed(String phoneNumber) async {
    String p = phoneNumber.trim();
    if (p.startsWith('0')) {
      p = '2$p'; 
    } else if (!p.startsWith('2') && !p.startsWith('+')) {
      p = '2$p';
    }

    try {
      // الاسم الصحيح حسب الصورة: sendOTP (كلها كابيتال في الآخر)
      final verificationId = await _akedly.sendOTP(p);
      
      if (verificationId != null) {
        return {
          "status": 200,
          "verificationId": verificationId,
          "success": true
        };
      } else {
        return {
          "status": 400,
          "body": "فشل إرسال الكود، تحقق من الرصيد أو الرقم",
          "success": false
        };
      }
    } catch (e) {
      return {
        "status": 500,
        "body": "خطأ تقني: ${e.toString()}",
        "success": false
      };
    }
  }

  /// التحقق من الكود (التعديل هنا حسب التوثيق الجديد)
  Future<bool> verifyOtp(String verificationId, String code) async {
    try {
      // الاسم الصحيح حسب الصورة: verifyOTP
      final isValid = await _akedly.verifyOTP(verificationId, code);
      return isValid;
    } catch (e) {
      print('OTP verification failed: $e');
      return false;
    }
  }
}