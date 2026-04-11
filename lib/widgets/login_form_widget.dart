import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';
import 'package:my_test_app/models/logged_user.dart';
import 'package:my_test_app/screens/otp_verification_screen.dart';
import 'package:my_test_app/screens/forgot_password_screen.dart';

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
  final Color primaryGreen = const Color(0xff28a745);

  Future<void> _initiateOtpLogin() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      String phoneClean = _phone.trim();
      
      // ✅ 1. توليد كود من 4 أرقام ليطابق مربعات صفحة الـ OTP
      String generatedOtp = (Random().nextInt(9000) + 1000).toString();

      // ✅ 2. جلب بيانات المستخدم من Firestore لضمان وجود الحساب
      final userQuery = await FirebaseFirestore.instance
          .collection('consumers')
          .where('phone', isEqualTo: phoneClean)
          .get();

      if (userQuery.docs.isEmpty) {
        setState(() => _errorMessage = "هذا الرقم غير مسجل لدينا");
        return;
      }

      final userData = userQuery.docs.first.data();
      final loggedInUser = LoggedInUser(
        id: userQuery.docs.first.id,
        fullname: userData['fullname'] ?? 'مستخدم',
        role: userData['role'] ?? 'consumer',
        phone: phoneClean,
      );

      // ✅ 3. محاولة الاتصال بـ SMS Misr (حتى لو مفيش رصيد)
      try {
        final url = Uri.parse("https://smsmisr.com/api/OTP/");
        await http.post(url, body: {
          "environment": "2", // وضع الاختبار
          "username": "YOUR_USERNAME", // استبدلها ببياناتك
          "password": "YOUR_PASSWORD", // استبدلها ببياناتك
          "sender": "YOUR_SENDER",
          "mobile": "20$phoneClean",
          "template": "YOUR_TEMPLATE",
          "otp": generatedOtp,
        });
      } catch (e) {
        debugPrint("SMS API Error (Ignored for testing): $e");
      }

      if (!mounted) return;

      // ✅ 4. إظهار الكود للمستخدم في رسالة (SnackBar) لأنه مفيش SMS هتوصل
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('وضع الاختبار: كود التحقق هو $generatedOtp'),
          duration: const Duration(seconds: 10),
          backgroundColor: primaryGreen,
        ),
      );

      // ✅ 5. الانتقال لصفحة الـ OTP بالبيانات الصحيحة
      Navigator.of(context).pushNamed(
        OtpVerificationScreen.routeName,
        arguments: {
          'otp': generatedOtp, // الكود اللي هيطابق هناك
          'user': loggedInUser, // بيانات اليوزر عشان الجلسة
        },
      );

    } catch (e) {
      debugPrint("OTP Error: $e");
      setState(() => _errorMessage = "خطأ تقني في إرسال الكود");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          _InputGroup(
            icon: Icons.phone_android,
            hintText: 'رقم الهاتف',
            keyboardType: TextInputType.phone,
            validator: (value) => (value == null || value.isEmpty) ? 'مطلوب' : null,
            onSaved: (value) => _phone = value!,
          ),
          const SizedBox(height: 18),
          _InputGroup(
            icon: Icons.lock_outline,
            hintText: 'كلمة المرور',
            isPassword: true,
            validator: (value) => (value == null || value.length < 6) ? 'قصيرة جداً' : null,
            onSaved: (value) => _password = value!,
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const ForgotPasswordScreen()),
              ),
              child: Text('نسيت كلمة المرور؟', style: TextStyle(color: primaryGreen)),
            ),
          ),
          const SizedBox(height: 10),
          _buildSubmitButton(),
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return Container(
      width: double.infinity,
      height: 55,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        gradient: LinearGradient(colors: [primaryGreen, const Color(0xff1e7e34)]),
      ),
      child: ElevatedButton(
        onPressed: _isLoading ? null : _initiateOtpLogin,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        ),
        child: _isLoading
            ? const CircularProgressIndicator(color: Colors.white)
            : const Text(
                'تسجيل الدخول (OTP)',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
      ),
    );
  }
}

class _InputGroup extends StatelessWidget {
  final IconData icon;
  final String hintText;
  final bool isPassword;
  final TextInputType keyboardType;
  final FormFieldValidator<String> validator;
  final FormFieldSetter<String> onSaved;

  const _InputGroup({
    required this.icon,
    required this.hintText,
    required this.validator,
    required this.onSaved,
    this.isPassword = false,
    this.keyboardType = TextInputType.text,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      obscureText: isPassword,
      textAlign: TextAlign.right,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: const Color(0xff28a745)),
        hintText: hintText,
        filled: true,
        fillColor: Colors.grey.shade50,
        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: Color(0xff28a745), width: 2),
        ),
      ),
      validator: validator,
      onSaved: onSaved,
    );
  }
}

