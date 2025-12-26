// lib/widgets/login_form_widget.dart
import 'package:flutter/material.dart';
import 'package:my_test_app/helpers/auth_service.dart';
import 'package:my_test_app/screens/forgot_password_screen.dart';
import 'package:my_test_app/services/user_session.dart'; // 🎯 الجلسة
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

  // 1. 🕵️ دالة تحديد هل هو مدير أم موظف (مضافة للمنطق الجديد)
  Future<void> _setupSellerSession(String phone, String uid) async {
    final firestore = FirebaseFirestore.instance;
    // فحص هل هو المورد الأساسي
    var adminDoc = await firestore.collection("sellers").doc(uid).get();
    if (adminDoc.exists && adminDoc.data()?['phone'] == phone) {
      UserSession.role = 'full';
      UserSession.ownerId = uid;
      UserSession.userId = uid;
      return;
    }
    // فحص هل هو موظف (Sub-User) داخل مصفوفة أي مورد
    var allSellers = await firestore.collection("sellers").get();
    for (var doc in allSellers.docs) {
      List subs = doc.data()['subUsers'] ?? [];
      var match = subs.firstWhere((u) => u['phone'] == phone, orElse: () => null);
      if (match != null) {
        UserSession.role = match['role'];
        UserSession.ownerId = doc.id; // ربطه بصاحب العمل الأساسي لإرسال الإشعارات
        UserSession.userId = uid;
        return;
      }
    }
  }

  void _showPendingDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Column(
          children: [
            Icon(Icons.hourglass_top_rounded, size: 50, color: Colors.orange.shade400),
            const SizedBox(height: 15),
            const Text('طلبك قيد المراجعة', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: const Text('أهلاً بك في عائلة أكسب! تم استلام طلب انضمامك بنجاح، وجاري مراجعته من قبل الإدارة لتفعيل حسابك في أقرب وقت.', textAlign: TextAlign.center, style: TextStyle(height: 1.5)),
        actions: [
          Center(
            child: TextButton(onPressed: () => Navigator.pop(context), child: Text('حسناً، سأنتظر', style: TextStyle(color: primaryGreen, fontWeight: FontWeight.bold))),
          ),
        ],
      ),
    );
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
      final String userRole = await _authService.signInWithEmailAndPassword(fakeEmail, _password);

      // --- 🎯 الجزء الحاسم: إعداد الجلسة قبل الإشعارات ---
      if (userRole == 'seller') {
        User? currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser != null) {
          await _setupSellerSession(_phone.trim(), currentUser.uid);
        }
      }

      // --- 🔔 جزء الإشعارات الأصلي + توافق الموظفين ---
      try {
        String? token = await FirebaseMessaging.instance.getToken();
        String? uid = FirebaseAuth.instance.currentUser?.uid;

        if (token != null && uid != null) {
          // الحفاظ على المنطق الأصلي في اختيار الـ Collection
          String collection = (userRole == 'seller') ? 'sellers' : (userRole == 'consumer' ? 'consumers' : 'users');
          
          // تحديث التوكن في فايرستور للمستخدم الحالي (سواء موظف أو مدير)
          await FirebaseFirestore.instance.collection(collection).doc(uid).set({
            'notificationToken': token,
            'fcmToken': token, // لضمان التوافق مع أي كود خارجي
            'platform': 'android',
          }, SetOptions(merge: true));

          // 🎯 إرسال التوكن لـ API أمازون (الرابط الأصلي)
          // ملاحظة: الموظف سيرسل الـ ownerId لكي تصله طلبات المحل
          String targetIdForApi = (userRole == 'seller' && UserSession.ownerId != null) 
              ? UserSession.ownerId! 
              : uid;

          const String apiUrl = "https://5uex7vzy64.execute-api.us-east-1.amazonaws.com/V2/new_nofiction";
          await http.post(
            Uri.parse(apiUrl), 
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({
              "userId": targetIdForApi, // هنا يتم الربط السحري
              "fcmToken": token, 
              "role": userRole
            })
          );
        }
      } catch (e) {
        debugPrint("Notification Setup Error: $e");
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text('✅ تم تسجيل الدخول بنجاح!', textAlign: TextAlign.center), backgroundColor: primaryGreen),
      );

      await Future.delayed(const Duration(milliseconds: 1500));
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
    } catch (e) {
      setState(() {
        _isLoading = false;
        if (e == 'auth/account-not-active') {
          _showPendingDialog();
        } else {
          _errorMessage = 'بيانات الدخول غير صحيحة';
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // ... (بقية كود الواجهة كما هو تماماً في الأصل دون تغيير) ...
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
      width: double.infinity, height: 55,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        gradient: LinearGradient(colors: [primaryGreen, const Color(0xff1e7e34)]),
      ),
      child: ElevatedButton(
        onPressed: _isLoading ? null : _submitLogin,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent, shadowColor: Colors.transparent,
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

// ... (Widget _InputGroup remains same as original) ...
class _InputGroup extends StatelessWidget {
  final IconData icon;
  final String hintText;
  final bool isPassword;
  final TextInputType keyboardType;
  final FormFieldValidator<String> validator;
  final FormFieldSetter<String> onSaved;

  const _InputGroup({
    required this.icon, required this.hintText, required this.validator, required this.onSaved,
    this.isPassword = false, this.keyboardType = TextInputType.text,
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

