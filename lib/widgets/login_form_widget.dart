import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';
import 'package:my_test_app/models/logged_user.dart';
import 'package:my_test_app/screens/otp_verification_screen.dart';

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

    setState(() { _isLoading = true; _errorMessage = null; });

    try {
      String phoneClean = _phone.trim();
      // توليد 4 أرقام ليطابق المربعات في صورتك 1000089468.jpg
      String generatedOtp = (Random().nextInt(9000) + 1000).toString();

      // 1. طلب الـ OTP بالبيانات اللي في صورك
      final response = await http.post(
        Uri.parse("https://smsmisr.com/api/OTP/"),
        body: {
          "environment": "2", 
          "username": "76495914", 
          "password": "p7u(Y9G9e9)", 
          "sender": "603b711e51270830768c8585915d5d179c36209b69994f8e580e060012759885", 
          "mobile": "20$phoneClean",
          "template": "180b55ec70499e056d6f20050854d19d65851412061225884241680191564552", 
          "otp": generatedOtp,
        },
      );

      debugPrint("SMS Misr Response: ${response.body}");

      // 2. البحث عن بيانات اليوزر عشان نعرف مساره (Seller/Consumer)
      final userQuery = await FirebaseFirestore.instance
          .collection('consumers')
          .where('phone', isEqualTo: phoneClean)
          .get();

      LoggedInUser loggedInUser;
      if (userQuery.docs.isNotEmpty) {
        final userData = userQuery.docs.first.data();
        loggedInUser = LoggedInUser(
          id: userQuery.docs.first.id,
          fullname: userData['fullname'] ?? 'مستخدم',
          role: userData['role'] ?? 'consumer',
          phone: phoneClean,
        );
      } else {
        // لو مش موجود، بنبعت بيانات افتراضية عشان يكمل للمربعات وتعرف تجرب
        loggedInUser = LoggedInUser(id: "test", fullname: "Guest", role: "consumer", phone: phoneClean);
      }

      if (!mounted) return;

      // إظهار الكود في SnackBar احتياطي لو الرسالة اتأخرت
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('كود التحقق (للتجربة): $generatedOtp')),
      );

      // 3. التوجيه لصفحة الـ OTP
      Navigator.of(context).pushNamed(
        OtpVerificationScreen.routeName,
        arguments: {
          'otp': generatedOtp, 
          'user': loggedInUser,
        },
      );

    } catch (e) {
      setState(() => _errorMessage = "خطأ في الاتصال");
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
          _buildInput(Icons.phone_android, 'رقم الهاتف', (v) => _phone = v!),
          const SizedBox(height: 18),
          _buildInput(Icons.lock_outline, 'كلمة المرور', (v) => _password = v!, isPass: true),
          const SizedBox(height: 20),
          _buildSubmitButton(),
          if (_errorMessage != null) Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
        ],
      ),
    );
  }

  Widget _buildInput(IconData icon, String hint, FormFieldSetter<String> onSaved, {bool isPass = false}) {
    return TextFormField(
      obscureText: isPass,
      textAlign: TextAlign.right,
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: primaryGreen),
        hintText: hint,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
      ),
      onSaved: onSaved,
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _initiateOtpLogin,
        style: ElevatedButton.styleFrom(backgroundColor: primaryGreen, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
        child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('تسجيل الدخول (OTP)', style: TextStyle(color: Colors.white, fontSize: 18)),
      ),
    );
  }
}

