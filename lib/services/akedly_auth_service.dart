import 'package:akedly/akedly.dart';

class AkedlyAuthService {
  // البيانات اللي استخرجناها من لوحة التحكم (مظبوطة وجاهزة)
  final String _apiKey = "f032dc4687c452cb7c340a91df69ed419e6a5330c3bb9b2f826828bf381e3624";
  final String _pipelineId = "6a02edb9dc826dd83e860ad1";

  // تعريف الكلاينت الجديد بتاع الـ SDK
  late final AkedlyClient _akedlyClient;

  AkedlyAuthService() {
    _akedlyClient = AkedlyClient(
      apiKey: _apiKey,
      pipelineId: _pipelineId,
    );
  }

  /// إرسال طلب OTP (متوافق مع V1.2 ونظام الدرع)
  Future<Map<String, dynamic>> sendOtpDetailed(String phoneNumber) async {
    // تنسيق الرقم لضمان وصوله بشكل دولي (أهم خطوة)
    String p = phoneNumber.trim();
    if (p.startsWith('0')) {
      p = '2$p'; // تحويل 010 إلى 2010
    } else if (!p.startsWith('2') && !p.startsWith('+')) {
      p = '2$p';
    }

    try {
      // استخدام الـ SDK بدل الـ POST Request اليدوي
      // الـ SDK بيتعامل تلقائياً مع الـ Endpoints الجديدة والـ Shield
      final response = await _akedlyClient.sendOtp(p);

      return {
        "status": 200, 
        "verificationId": response.verificationId, // الـ ID المهم للتأكيد
        "success": true
      };
    } catch (e) {
      return {
        "status": 500,
        "body": "خطأ في الاتصال بالسيرفر أو الـ Shield: ${e.toString()}",
        "success": false
      };
    }
  }

  /// التحقق من الكود الذي أدخله المستخدم
  Future<bool> verifyOtp(String verificationId, String code) async {
    try {
      final isVerified = await _akedlyClient.verifyOtp(
        verificationId: verificationId,
        otpCode: code,
      );
      
      return isVerified;
    } catch (e) {
      print("Verify Error: $e");
      return false;
    }
  }
}