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

  /// F3 registration: step 1 — ask the backend to OTP-prove an UNKNOWN phone
  /// for [role] (buyer/seller/consumer). The server rejects known numbers
  /// (409) and binds role+collection server-side. Returns txID in [AuthResult.data].
  Future<AuthResult> registerSend(String phoneNumber, String role) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phoneNumber': phoneNumber, 'role': role}),
      );
      final resData =
          response.body.isNotEmpty ? jsonDecode(response.body) : null;
      if (response.statusCode == 200) {
        final data = resData is Map ? resData['data'] : null;
        String? transactionReqID;
        if (data is Map && data['transactionReqID'] != null) {
          transactionReqID = data['transactionReqID'].toString();
        }
        return AuthResult.success(data: transactionReqID ?? '');
      }
      String? message;
      if (resData is Map && resData['message'] != null) {
        message = resData['message'].toString();
      }
      return AuthResult.failure(message: message ?? 'فشل بدء التسجيل');
    } catch (e) {
      return AuthResult.failure(message: 'خطأ تقني: $e');
    }
  }

  /// F3 registration: step 2 — server verifies OTP, creates the passwordless
  /// Auth identity + role doc in the bound collection, and returns a custom
  /// token. Throws [RegisterException] carrying the backend status
  /// (400 bad code/profile, 403 login-tx, 404 unknown tx, 409 already
  /// registered, 410 expired/used, 429 rate-limited).
  Future<RegisterResult> registerVerify({
    required String transactionReqID,
    required String otp,
    required String phoneNumber,
    required Map<String, dynamic> profile,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/register-verify'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'transactionReqID': transactionReqID,
        'otp': otp,
        'phoneNumber': phoneNumber,
        'profile': profile,
      }),
    );
    if (response.statusCode == 200) {
      final resData =
          response.body.isNotEmpty ? jsonDecode(response.body) : null;
      if (resData is Map && resData['customToken'] is String) {
        return RegisterResult(
          customToken: resData['customToken'] as String,
          role: resData['role']?.toString() ?? '',
          collection: resData['collection']?.toString() ?? '',
          status: resData['status']?.toString() ?? '',
        );
      }
    }
    throw RegisterException(response.statusCode, response.body);
  }

  /// F3: backend-mediated mint — the server verifies the OTP and issues a
  /// Firebase Custom Token. Returns the token, or throws [MintException]
  /// carrying the backend status (400 wrong code, 403 pending, 404 unknown,
  /// 410 expired/used, 429 rate-limited).
  Future<String> mintTransaction({
    required String transactionReqID,
    required String otp,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/mint'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'transactionReqID': transactionReqID, 'otp': otp}),
    );
    if (response.statusCode == 200) {
      final resData =
          response.body.isNotEmpty ? jsonDecode(response.body) : null;
      final token = resData is Map ? resData['customToken'] : null;
      if (token is String && token.isNotEmpty) return token;
    }
    throw MintException(response.statusCode, response.body);
  }
}

/// F3: mint failure carrying the backend status code for UI mapping.
class MintException implements Exception {
  final int statusCode;
  final String body;
  MintException(this.statusCode, this.body);
}

/// F3 registration failure carrying the backend status code for UI mapping.
class RegisterException implements Exception {
  final int statusCode;
  final String body;
  RegisterException(this.statusCode, this.body);
}

/// F3 registration success — identity created server-side in [collection]
/// with [status] (active = usable now, pending = admin review).
class RegisterResult {
  final String customToken;
  final String role;
  final String collection;
  final String status;
  RegisterResult({
    required this.customToken,
    required this.role,
    required this.collection,
    required this.status,
  });
}

class AuthResult {
  final bool isSuccess;
  final String? message;
  final String? data;
  AuthResult.success({this.data}) : isSuccess = true, message = null;
  AuthResult.failure({required this.message}) : isSuccess = false, data = null;
}
