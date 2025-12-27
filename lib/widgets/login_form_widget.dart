// lib/widgets/login_form_widget.dart
import 'package:flutter/material.dart';
import 'package:my_test_app/helpers/auth_service.dart';
import 'package:my_test_app/screens/forgot_password_screen.dart';
import 'package:my_test_app/services/user_session.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
  final AuthService _authService = AuthService();
  final Color primaryGreen = const Color(0xff28a745);

  // 1. دالة تهيئة الجلسة: أصبحت تعيد true إذا كان هناك تغيير كلمة سر مطلوب
  Future<bool> _setupSellerSession(String phone, String uid) async {
    final firestore = FirebaseFirestore.instance;

    // أولاً: التاجر الأساسي
    var adminDoc = await firestore.collection("sellers").doc(uid).get();
    if (adminDoc.exists && adminDoc.data()?['phone'] == phone) {
      UserSession.role = 'full';
      UserSession.ownerId = uid;
      UserSession.userId = uid;
      return false; 
    }

    // ثانياً: الموظف (SubUser)
    var subUserDoc = await firestore.collection("subUsers").doc(phone).get();
    if (subUserDoc.exists) {
      var data = subUserDoc.data()!;
      UserSession.role = data['role'];
      UserSession.ownerId = data['parentSellerId']; 
      UserSession.userId = uid;

      if (data['mustChangePassword'] == true) {
        _showChangePasswordDialog(phone);
        return true; // يجب الانتظار لتغيير كلمة السر
      }
    }
    return false;
  }

  // 2. المربع الحواري المحدث مع ربط الـ AWS
  void _showChangePasswordDialog(String phone) {
    final TextEditingController newPassController = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("تأمين الحساب", textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("يرجى تعيين كلمة سر جديدة لحماية حسابك الموظف."),
            const SizedBox(height: 15),
            TextField(
              controller: newPassController,
              obscureText: true,
              decoration: InputDecoration(
                hintText: "كلمة السر الجديدة",
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: primaryGreen),
            onPressed: () async {
              if (newPassController.text.length < 6) return;
              
              try {
                // تحديث الباسورد و Firestore
                await FirebaseAuth.instance.currentUser?.updatePassword(newPassController.text.trim());
                await FirebaseFirestore.instance.collection("subUsers").doc(phone).update({
                  'mustChangePassword': false,
                });

                // إرسال الإشعار للـ AWS فور التحديث
                await _sendNotificationDataToAWS();

                if (!mounted) return;
                Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
              } catch (e) {
                debugPrint("Error updating password: $e");
              }
            },
            child: const Text("حفظ ودخول", style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }

  // دالة مساعدة لإرسال بيانات الـ AWS
  Future<void> _sendNotificationDataToAWS() async {
    try {
      String? token = await FirebaseMessaging.instance.getToken();
      String? uid = FirebaseAuth.instance.currentUser?.uid;
      if (token != null && uid != null) {
        const String apiUrl = "https://5uex7vzy64.execute-api.us-east-1.amazonaws.com/V2/new_nofiction";
        await http.post(
          Uri.parse(apiUrl),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({
            "userId": uid, // UID الموظف
            "fcmToken": token,
            "role": "seller"
          })
        );
      }
    } catch (e) {
      debugPrint("AWS Notification Error: $e");
    }
  }

  Future<void> _submitLogin() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();
    setState(() { _isLoading = true; _errorMessage = null; });

    try {
      String fakeEmail = "${_phone.trim()}@aswaq.com";
      final String userRole = await _authService.signInWithEmailAndPassword(fakeEmail, _password);

      if (userRole == 'seller') {
        User? currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser != null) {
          bool shouldWait = await _setupSellerSession(_phone.trim(), currentUser.uid);
          
          if (shouldWait) {
            setState(() => _isLoading = false);
            return; // 🛑 التوقف هنا للسماح للموظف بتغيير الباسورد
          }
        }
      }

      // إذا وصلنا هنا، يعني المستخدم لا يحتاج لتغيير باسورد
      await _sendNotificationDataToAWS();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text('✅ تم تسجيل الدخول بنجاح!'), backgroundColor: primaryGreen),
      );

      await Future.delayed(const Duration(milliseconds: 1500));
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);

    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'بيانات الدخول غير صحيحة';
      });
    }
  }

  // ... باقي كود الـ UI (Build, InputGroup, الخ) كما هو لديك ...
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
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => const ForgotPasswordScreen())),
              child: Text('نسيت كلمة المرور؟', style: TextStyle(color: primaryGreen)),
            ),
          ),
          const SizedBox(height: 10),
          _buildSubmitButton(),
          const SizedBox(height: 25),
          _buildRegisterLink(),
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(_errorMessage!, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
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
        onPressed: _isLoading ? null : _submitLogin,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        ),
        child: _isLoading
            ? const CircularProgressIndicator(color: Colors.white)
            : const Text('تسجيل الدخول', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildRegisterLink() {
    return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Text('ليس لديك حساب؟'),
      TextButton(
        onPressed: () => Navigator.of(context).pushNamed('/register'),
        child: Text('إنشاء حساب', style: TextStyle(color: primaryGreen, fontWeight: FontWeight.bold)),
      ),
    ]);
  }
}

// كود الـ _InputGroup يبقى كما هو في ملفك الأصلي
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
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: Colors.grey.shade300)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: Colors.grey.shade200)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: Color(0xff28a745), width: 2)),
      ),
      validator: validator,
      onSaved: onSaved,
    );
  }
}

