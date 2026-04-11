import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';
import 'package:my_test_app/helpers/auth_service.dart';
import 'package:my_test_app/services/user_session.dart';
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
  final AuthService _authService = AuthService();
  final Color primaryGreen = const Color(0xff28a745);

  Future<void> _initiateOtpLogin() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    setState(() { _isLoading = true; _errorMessage = null; });

    try {
      String phoneClean = _phone.trim();
      
      // 1. التحقق من كلمة السر أولاً (نفس منطق الأصل)
      String? userRole;
      try {
        userRole = await _authService.signInWithEmailAndPassword("$phoneClean@aksab.com", _password);
      } catch (e) {
        userRole = await _authService.signInWithEmailAndPassword("$phoneClean@aswaq.com", _password);
      }

      // 2. التحقق من حالة الحساب (Status check من الأصل)
      final userToCheck = FirebaseAuth.instance.currentUser;
      if (userToCheck != null) {
        var checkDoc = await FirebaseFirestore.instance.collection('consumers').doc(userToCheck.uid).get();
        if (!checkDoc.exists) checkDoc = await FirebaseFirestore.instance.collection('users').doc(userToCheck.uid).get();
        if (!checkDoc.exists) checkDoc = await FirebaseFirestore.instance.collection('sellers').doc(userToCheck.uid).get();

        if (checkDoc.exists && checkDoc.data()?['status'] == 'delete_requested') {
          await FirebaseAuth.instance.signOut();
          setState(() {
            _isLoading = false;
            _errorMessage = 'هذا الحساب قيد الحذف نهائياً، لا يمكن تسجيل الدخول إليه.';
          });
          return;
        }
      }

      // 3. لو كله تمام.. نبعت الـ OTP (SMS Misr)
      String generatedOtp = (Random().nextInt(9000) + 1000).toString();
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

      // 4. تجهيز بيانات اليوزر للتوجيه
      LoggedInUser loggedUser = LoggedInUser(
        id: userToCheck!.uid,
        fullname: UserSession.merchantName ?? 'مستخدم',
        role: userRole ?? 'seller',
        phone: phoneClean,
      );

      if (!mounted) return;
      
      Navigator.of(context).pushNamed(
        OtpVerificationScreen.routeName,
        arguments: {'otp': generatedOtp, 'user': loggedUser},
      );

    } catch (e) {
      setState(() => _errorMessage = "خطأ في رقم الهاتف أو كلمة المرور");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // استخدم نفس تصميم الـ UI الأصلي الجميل اللي كان معاك
    return Form(
      key: _formKey,
      child: Column(
        children: [
          _buildInput(Icons.phone_android, 'رقم الهاتف', (v) => _phone = v!),
          const SizedBox(height: 18),
          _buildInput(Icons.lock_outline, 'كلمة المرور', (v) => _password = v!, isPass: true),
          const SizedBox(height: 20),
          _buildSubmitButton(),
          if (_errorMessage != null) Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(_errorMessage!, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
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
        filled: true,
        fillColor: Colors.grey.shade50,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: Colors.grey.shade200)),
      ),
      validator: (value) => (value == null || value.isEmpty) ? 'مطلوب' : null,
      onSaved: onSaved,
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _initiateOtpLogin,
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryGreen,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        ),
        child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('تسجيل الدخول (OTP)', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
      ),
    );
  }
}

