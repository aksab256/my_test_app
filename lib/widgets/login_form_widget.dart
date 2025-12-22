import 'package:flutter/material.dart';
import 'package:my_test_app/helpers/auth_service.dart';
import 'package:my_test_app/screens/forgot_password_screen.dart';
import 'package:sizer/sizer.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
// --- إضافة مكتبات الـ API ---
import 'package:http/http.dart' as http;
import 'dart:convert';

class LoginFormWidget extends StatefulWidget {
  const LoginFormWidget({super.key});

  @override
  State<LoginFormWidget> createState() => _LoginFormWidgetState();
}

class _LoginFormWidgetState extends State<LoginFormWidget> {
  final _formKey = GlobalKey<FormState>();
  String _phone = '';
  String _password = '';
  bool _isLoading = false;
  String? _errorMessage;
  bool _obscurePassword = true;
  final AuthService _authService = AuthService();

  // 🎯 الدالة الجديدة لربط الموبايل بـ AWS عبر الـ API (نفس شغل الويب)
  Future<void> _registerWithAwsApi(String userId, String fcmToken) async {
    const String apiUrl = "https://5uex7vzy64.execute-api.us-east-1.amazonaws.com/V2/new_nofiction";
    
    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "userId": userId,
          "fcmToken": fcmToken,
          "role": "buyer", // يمكنك تغييرها حسب بيانات المستخدم
          "address": ""     // اختياري
        }),
      );

      if (response.statusCode == 200) {
        print("✅ AWS Registration Success: ${response.body}");
      } else {
        print("❌ AWS Registration Failed: ${response.statusCode}");
      }
    } catch (e) {
      print("❌ Error calling AWS API: $e");
    }
  }

  // 🎯 تحديث التوكن وطلب الإذن
  Future<void> _updateNotificationToken() async {
    try {
      FirebaseMessaging messaging = FirebaseMessaging.instance;
      NotificationSettings settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        String? token = await messaging.getToken();
        if (token != null) {
          String? uid = FirebaseAuth.instance.currentUser?.uid;
          if (uid != null) {
            // 1. تحديث Firestore (للتوثيق)
            await FirebaseFirestore.instance.collection('users').doc(uid).set({
              'notificationToken': token,
              'lastTokenUpdate': FieldValue.serverTimestamp(),
              'platform': 'android',
            }, SetOptions(merge: true));

            // 2. 🔥 استدعاء الـ API الخاص بـ AWS فوراً لإنشاء الـ ARN
            await _registerWithAwsApi(uid, token);
            
            print("🚀 Notification System Ready for User: $uid");
          }
        }
      }
    } catch (e) {
      print("❌ Error in Notification Process: $e");
    }
  }

  Future<void> _submitLogin() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      String fakeEmail = "${_phone.trim()}@aswaq.com";
      await _authService.signInWithEmailAndPassword(fakeEmail, _password);

      // 🔥 تسجيل التوكن في Firestore و AWS API
      await _updateNotificationToken();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ تم تسجيل الدخول بنجاح!', textAlign: TextAlign.center),
          backgroundColor: Color(0xFF2D9E68),
        ),
      );

      Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
    } catch (e) {
      setState(() {
        _errorMessage = 'رقم الهاتف أو كلمة المرور غير صحيحة.';
        _isLoading = false;
      });
    }
  }

  // ... (بقية دوال الـ Build والـ UI تظل كما هي دون تغيير)
  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildTextField(
            hint: 'رقم الهاتف',
            icon: Icons.phone_android_rounded,
            keyboardType: TextInputType.phone,
            onSaved: (value) => _phone = value!,
            validator: (value) => (value == null || value.length < 8) ? 'يرجى إدخال رقم هاتف صحيح' : null,
          ),
          SizedBox(height: 2.5.h),
          _buildTextField(
            hint: 'كلمة المرور',
            icon: Icons.lock_outline_rounded,
            isPassword: true,
            obscureText: _obscurePassword,
            onSaved: (value) => _password = value!,
            toggleVisibility: () => setState(() => _obscurePassword = !_obscurePassword),
            validator: (value) => (value == null || value.length < 6) ? 'كلمة المرور قصيرة جداً' : null,
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const ForgotPasswordScreen()),
              ),
              child: Text('نسيت كلمة المرور؟',
                  style: TextStyle(color: Colors.grey[600], fontSize: 11.sp, fontWeight: FontWeight.bold)),
            ),
          ),
          SizedBox(height: 2.h),
          _buildSubmitButton(),
          if (_errorMessage != null) _buildErrorBox(),
        ],
      ),
    );
  }

  // (دوال الـ UI المساعدة _buildTextField و _buildSubmitButton و _buildErrorBox كما هي)
  Widget _buildTextField({required String hint, required IconData icon, bool isPassword = false, bool obscureText = false, VoidCallback? toggleVisibility, TextInputType keyboardType = TextInputType.text, required FormFieldSetter<String> onSaved, required FormFieldValidator<String> validator}) {
    return TextFormField(
      obscureText: obscureText,
      textAlign: TextAlign.right,
      keyboardType: keyboardType,
      onSaved: onSaved,
      validator: validator,
      style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        filled: true,
        fillColor: const Color(0xFFF7F9F8),
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 13.sp),
        contentPadding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
        prefixIcon: isPassword ? IconButton(icon: Icon(obscureText ? Icons.visibility_off : Icons.visibility, size: 24, color: Colors.grey), onPressed: toggleVisibility) : null,
        suffixIcon: Padding(padding: const EdgeInsets.symmetric(horizontal: 15), child: Icon(icon, color: const Color(0xFF2D9E68), size: 28)),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: const BorderSide(color: Color(0xFF2D9E68), width: 2)),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return Container(
      height: 75,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), gradient: const LinearGradient(colors: [Color(0xFF2D9E68), Color(0xFF38B277)]), boxShadow: [BoxShadow(color: const Color(0xFF2D9E68).withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8))]),
      child: ElevatedButton(
        onPressed: _isLoading ? null : _submitLogin,
        style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
        child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : Text('دخول', style: TextStyle(color: Colors.white, fontSize: 16.sp, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildErrorBox() {
    return Container(
      margin: const EdgeInsets.only(top: 20),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.red.shade200)),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.error_outline, color: Colors.red.shade800), const SizedBox(width: 10), Expanded(child: Text(_errorMessage!, style: TextStyle(color: Colors.red.shade800, fontWeight: FontWeight.bold, fontSize: 11.sp)))]),
    );
  }
}
