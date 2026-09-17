import 'dart:convert';
import 'package:http/http.dart' as http;

class AkedlyAuthService {
  static const String _baseUrl =
      'https://us-central1-aksab-erp.cloudfunctions.net/akedly';

  Future<AuthResult> sendOtpDetailed(String phoneNumber) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/send'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phoneNumber': phoneNumber}),
      );

      final resData =
          response.body.isNotEmpty ? jsonDecode(response.body) : null;
      if (response.statusCode == 200) {
        final data = resData is Map ? resData['data'] : null;
        String? transactionReqID;
        if (data is Map && data['transactionReqID'] != null) {
          transactionReqID = data['transactionReqID'].toString();
        } else if (resData is Map &&
            resData['transactionReqID'] != null) {
          transactionReqID = resData['transactionReqID'].toString();
        }
        return AuthResult.success(data: transactionReqID ?? '');
      } else {
        String? message;
        if (resData is Map && resData['message'] != null) {
          message = resData['message'].toString();
        }
        return AuthResult.failure(message: message ?? 'فشل الإرسال');
      }
    } catch (e) {
      return AuthResult.failure(message: 'خطأ تقني: $e');
    }
  }

  Future<bool> verifyOtp(String transactionReqID, String otp,
      [String? phoneNumber]) async {
    try {
      final body = <String, dynamic>{
        'transactionReqID': transactionReqID,
        'otp': otp,
      };
      if (phoneNumber != null && phoneNumber.isNotEmpty) {
        body['phoneNumber'] = phoneNumber;
      }
      final response = await http.post(
        Uri.parse('$_baseUrl/verify'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
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
