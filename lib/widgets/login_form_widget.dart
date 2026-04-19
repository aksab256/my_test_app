import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
      String searchPhone = _phone.trim();
      if (searchPhone.startsWith('0')) searchPhone = searchPhone.substring(1);
      
      String fullPhone = '+20$searchPhone';

      // 1. التحقق من وجود المستخدم في Firestore (أمان العهدة)
      // نتحقق في كل المجموعات المتاحة
      QuerySnapshot? userQuery;
      List<String> collections = ['consumers', 'users', 'sellers'];
      
      for (var col in collections) {
        var res = await FirebaseFirestore.instance
            .collection(col)
            .where('phone', isEqualTo: searchPhone)
            .get();
        if (res.docs.isNotEmpty) {
          userQuery = res;
          break;
        }
      }

      if (userQuery == null || userQuery.docs.isEmpty) {
        throw Exception("عفواً، رقم الهاتف هذا غير مسجل في النظام");
      }

      var userData = userQuery.docs.first.data() as Map<String, dynamic>;
      
      if (userData['status'] == 'delete_requested') {
        throw Exception('هذا الحساب قيد الحذف نهائياً');
      }

      // 2. إرسال الـ OTP عبر فايربيز (استغلال الـ 10 آلاف رسالة مجانية)
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: fullPhone,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (PhoneAuthCredential credential) async {
          // تسجيل دخول تلقائي في حالة التعرف على الكود
          await FirebaseAuth.instance.signInWithCredential(credential);
        },
        verificationFailed: (FirebaseAuthException e) {
          setState(() {
            if (e.code == 'too-many-requests') {
              _errorMessage = "محاولات كثيرة، تم حظر الجهاز مؤقتاً";
            } else {
              _errorMessage = "فشل الإرسال: ${e.message}";
            }
          });
        },
        codeSent: (String verificationId, int? resendToken) {
          LoggedInUser loggedUser = LoggedInUser(
            id: userQuery!.docs.first.id, 
            fullname: userData['fullname'] ?? 'مستخدم النظام',
            role: userData['role'] ?? 'delivery',
            phone: searchPhone,
          );

          if (!mounted) return;

          Navigator.of(context).pushNamed(
            OtpVerificationScreen.routeName,
            arguments: {
              'verificationId': verificationId,
              'user': loggedUser,
              'isFirebase': true,
            },
          );
        },
        codeAutoRetrievalTimeout: (String verificationId) {},
      );

    } catch (e) {
      debugPrint("Login Error: $e");
      setState(() => _errorMessage = e.toString().replaceAll("Exception:", ""));
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
          const Text(
            "تسجيل دخول سريع لشركاء النجاح",
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
          const SizedBox(height: 20),
          _buildInput(Icons.phone_android, 'رقم الهاتف المسجل', (v) => _phone = v!),
          const SizedBox(height: 25),
          _buildSubmitButton(),
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(top: 15),
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

  Widget _buildInput(IconData icon, String hint, FormFieldSetter<String> onSaved) {
    return TextFormField(
      textAlign: TextAlign.right,
      keyboardType: TextInputType.phone,
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: primaryGreen),
        hintText: hint,
        filled: true,
        fillColor: Colors.grey.shade50,
        contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: Colors.grey.shade300)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: Colors.grey.shade200)),
      ),
      validator: (value) => (value == null || value.isEmpty) ? 'برجاء إدخال الرقم' : null,
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
            'أرسل كود تأمين العهدة',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)
          ),
      ),
    );
  }
}

