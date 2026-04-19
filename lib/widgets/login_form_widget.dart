import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
      // تأكد من تنظيف الرقم (بدون الصفر الأول) لإرساله بصيغة +20
      String searchPhone = phoneClean;
      if (searchPhone.startsWith('0')) searchPhone = searchPhone.substring(1);
      
      String fullPhone = '+20$searchPhone';

      // 1. التحقق من كلمة السر والوجود في السيستم (أمان العهدة)
      String? userRole;
      try {
        userRole = await _authService.signInWithEmailAndPassword("$searchPhone@aksab.com", _password);
      } catch (e) {
        userRole = await _authService.signInWithEmailAndPassword("$searchPhone@aswaq.com", _password);
      }

      final userToCheck = FirebaseAuth.instance.currentUser;
      if (userToCheck == null) throw Exception("فشل التحقق من الهوية");

      // التحقق من حالة الحساب في المجموعات المختلفة
      var checkDoc = await FirebaseFirestore.instance.collection('consumers').doc(userToCheck.uid).get();
      if (!checkDoc.exists) checkDoc = await FirebaseFirestore.instance.collection('users').doc(userToCheck.uid).get();
      if (!checkDoc.exists) checkDoc = await FirebaseFirestore.instance.collection('sellers').doc(userToCheck.uid).get();

      if (checkDoc.exists && checkDoc.data()?['status'] == 'delete_requested') {
        await FirebaseAuth.instance.signOut();
        throw Exception('هذا الحساب قيد الحذف نهائياً');
      }

      // 2. إرسال كود تأمين العهدة عبر Firebase (حصرياً)
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: fullPhone,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (PhoneAuthCredential credential) async {
          // في حال التعرف التلقائي على الرسالة
          await FirebaseAuth.instance.signInWithCredential(credential);
        },
        verificationFailed: (FirebaseAuthException e) {
          setState(() {
            if (e.code == 'too-many-requests') {
              _errorMessage = "محاولات كثيرة، تم حظر الجهاز مؤقتاً للأمان";
            } else {
              _errorMessage = "فشل إرسال كود الأمان: ${e.message}";
            }
          });
        },
        codeSent: (String verificationId, int? resendToken) {
          LoggedInUser loggedUser = LoggedInUser(
            id: userToCheck.uid,
            fullname: UserSession.merchantName ?? 'مستخدم أكسب',
            role: userRole ?? 'seller',
            phone: searchPhone,
          );

          if (!mounted) return;

          // الانتقال لصفحة التأكيد وإرسال الـ verificationId
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
      debugPrint("Aksab Login Error: $e");
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
            'تأكيد العهدة (OTP)',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)
          ),
      ),
    );
  }
}

