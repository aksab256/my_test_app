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

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      String phoneClean = _phone.trim();

      // 1. التحقق من كلمة السر أولاً عبر Firebase
      String? userRole;
      try {
        userRole = await _authService.signInWithEmailAndPassword("$phoneClean@aksab.com", _password);
      } catch (e) {
        userRole = await _authService.signInWithEmailAndPassword("$phoneClean@aswaq.com", _password);
      }

      final userToCheck = FirebaseAuth.instance.currentUser;
      if (userToCheck == null) throw Exception("Authentication Failed");

      // التحقق من حالة الحساب (Status check)
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

      // 2. إرسال الـ OTP عبر SMS Misr بنظام الـ GET
      String generatedOtp = (Random().nextInt(9000) + 1000).toString();
      
      // استخدام التمبلت الخاص بـ Your One Time Password (OTP) is...
      String templateToken = "eb60c2a456825a40a56dd36813e8ba8740b6dbe1c5d6921034bd9508e78d5fac";

      final url = Uri.parse("https://smsmisr.com/api/OTP/").replace(queryParameters: {
        "environment": "2", // وضع الاختبار
        "username": "76495914",
        "password": "p7u(Y9G9e9)",
        "sender": "603b711e51270830768c8585915d5d179c36209b69994f8e580e060012759885",
        "mobile": "20$phoneClean",
        "template": templateToken,
        "otp": generatedOtp,
      });

      debugPrint("Requesting OTP: $url");
      final response = await http.get(url);
      
      if (response.body.isEmpty) throw Exception("Empty response from SMS server");

      final responseData = jsonDecode(response.body);
      // تحويل الكود لنص لضمان عدم حدوث Null عند المقارنة
      final String resultCode = responseData['code']?.toString() ?? "unknown";

      // 3. معالجة النتيجة بناءً على مستندات SMS Misr
      if (resultCode == "4901") {
        LoggedInUser loggedUser = LoggedInUser(
          id: userToCheck.uid,
          fullname: UserSession.merchantName ?? 'مستخدم أكسب',
          role: userRole ?? 'seller',
          phone: phoneClean,
        );

        if (!mounted) return;

        Navigator.of(context).pushNamed(
          OtpVerificationScreen.routeName,
          arguments: {
            'otp': generatedOtp,
            'user': loggedUser,
          },
        );
      } else {
        // ترجمة الأكواد لمنع ظهور (null) للمستخدم
        String errorDetail;
        switch (resultCode) {
          case "4903": errorDetail = "خطأ في بيانات حساب الإرسال"; break;
          case "4906": errorDetail = "عفواً، رصيد رسائل SMS غير كافٍ"; break;
          case "4909": errorDetail = "خطأ في توكن القالب (Template Token)"; break;
          case "4905": errorDetail = "رقم الهاتف غير صحيح"; break;
          default: errorDetail = "فشل إرسال الكود: (Code $resultCode)";
        }
        setState(() => _errorMessage = errorDetail);
      }

    } catch (e) {
      debugPrint("Aksab Login Error: $e");
      setState(() => _errorMessage = "تأكد من رقم الهاتف وكلمة المرور");
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
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInput(IconData icon, String hint, FormFieldSetter<String> onSaved, {bool isPass = false}) {
    return TextFormField(
      obscureText: isPass,
      textAlign: TextAlign.right,
      keyboardType: isPass ? TextInputType.text : TextInputType.phone,
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: primaryGreen),
        hintText: hint,
        filled: true,
        fillColor: Colors.grey.shade50,
        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: Colors.grey.shade300)
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: Colors.grey.shade200)
        ),
      ),
      validator: (value) => (value == null || value.isEmpty) ? 'برجاء إكمال الحقل' : null,
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
          elevation: 2,
        ),
        child: _isLoading
          ? const CircularProgressIndicator(color: Colors.white)
          : const Text(
              'تسجيل الدخول (OTP)',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)
            ),
      ),
    );
  }
}

