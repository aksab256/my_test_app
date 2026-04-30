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

// 🟢 [إضافة دقيقة]: استيراد البروفايدر لربط البيانات لحظياً
import 'package:provider/provider.dart';
import 'package:my_test_app/providers/buyer_data_provider.dart';

// استيراد الشاشات لجلب الـ routeName الصحيح
import 'package:my_test_app/screens/buyer/buyer_home_screen.dart';
import 'package:my_test_app/screens/consumer/consumer_home_screen.dart';
import 'package:my_test_app/screens/seller_screen.dart';

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

  // دالة تنظيف وتنسيق الرقم لضمان قبول Firebase له
  String _formatPhoneNumber(String phone) {
    String cleaned = phone.trim().replaceAll(RegExp(r'\s+'), '');
    if (cleaned.startsWith('0')) {
      cleaned = '+20${cleaned.substring(1)}';
    } else if (!cleaned.startsWith('+')) {
      cleaned = '+20$cleaned';
    }
    return cleaned;
  }

  Future<void> _submitLogin() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final String formattedPhone = _formatPhoneNumber(_phone);

    try {
      // 1. التحقق من وجود المستخدم في كوليكشنات أسواق أكسب
      bool userExists = false;
      final collectionsToSearch = ['consumers', 'users', 'sellers'];

      for (var collection in collectionsToSearch) {
        var query = await FirebaseFirestore.instance
            .collection(collection)
            .where('phoneNumber', isEqualTo: formattedPhone)
            .limit(1)
            .get();
        if (query.docs.isNotEmpty) {
          userExists = true;
          // التحقق من حالة الحذف
          if (query.docs.first.data()['status'] == 'delete_requested') {
            setState(() {
              _isLoading = false;
              _errorMessage = 'هذا الحساب قيد الحذف نهائياً.';
            });
            return;
          }
          break;
        }
      }

      if (!userExists) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'رقم الهاتف هذا غير مسجل في أسواق أكسب.';
        });
        return;
      }

      // 2. إذا وجدنا المستخدم، نبدأ عملية الـ OTP
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: formattedPhone,
        verificationCompleted: (PhoneAuthCredential credential) async {
          // التحقق التلقائي على بعض الأجهزة
          await _signInWithCredential(credential);
        },
        verificationFailed: (FirebaseAuthException e) {
          setState(() {
            _isLoading = false;
            _errorMessage = 'فشل التحقق: ${e.message}';
          });
        },
        codeSent: (String verificationId, int? resendToken) {
          setState(() => _isLoading = false);
          _showOtpDialog(verificationId, formattedPhone);
        },
        codeAutoRetrievalTimeout: (String verificationId) {},
      );

    } catch (e) {
      debugPrint("Pre-Login Error: $e");
      setState(() {
        _isLoading = false;
        _errorMessage = 'حدث خطأ أثناء الاتصال بالخادم';
      });
    }
  }

  // دالة إظهار ديالوج إدخال كود الـ OTP
  void _showOtpDialog(String verificationId, String phone) {
    final TextEditingController otpController = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("رمز التفعيل", textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("تم إرسال كود التحقق إلى\n$phone", textAlign: TextAlign.center),
            const SizedBox(height: 15),
            TextField(
              controller: otpController,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              // ✅ [تم الإصلاح]: وضع الـ letterSpacing داخل الـ style
              style: const TextStyle(
                fontSize: 24, 
                fontWeight: FontWeight.bold,
                letterSpacing: 8,
              ),
              decoration: InputDecoration(
                hintText: "000000",
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        actions: [
          Center(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryGreen, 
                minimumSize: const Size(150, 45),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () async {
                String smsCode = otpController.text.trim();
                if (smsCode.length == 6) {
                  PhoneAuthCredential credential = PhoneAuthProvider.credential(
                    verificationId: verificationId,
                    smsCode: smsCode,
                  );
                  Navigator.pop(context); // إغلاق الديالوج
                  await _signInWithCredential(credential);
                }
              },
              child: const Text("تحقق ودخول", style: TextStyle(color: Colors.white)),
            ),
          )
        ],
      ),
    );
  }

  // الدالة النهائية لإتمام تسجيل الدخول وربط الجلسة
  Future<void> _signInWithCredential(PhoneAuthCredential credential) async {
    setState(() => _isLoading = true);
    try {
      final authResult = await FirebaseAuth.instance.signInWithCredential(credential);

      if (authResult.user != null) {
        String phoneClean = _phone.trim();
        String? userRole;

        // تسجيل الدخول بالخلفية لربط نظام البريد الإلكتروني الافتراضي (@aksab.com)
        try {
          userRole = await _authService.signInWithEmailAndPassword("$phoneClean@aksab.com", _password);
        } catch (e) {
          userRole = await _authService.signInWithEmailAndPassword("$phoneClean@aswaq.com", _password);
        }

        await UserSession.loadSession();

        if (mounted) {
          await Provider.of<BuyerDataProvider>(context, listen: false).initializeData(
            authResult.user?.uid,
            UserSession.ownerId,
            UserSession.merchantName ?? "مستخدم أسواق أكسب"
          );
        }

        // تحديث بيانات التنبيهات على AWS
        _sendNotificationDataToAWS().catchError((e) => debugPrint("AWS Error: $e"));

        if (!mounted) return;
        _navigateToHome(userRole ?? UserSession.role);
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = "كود التحقق غير صحيح أو انتهت صلاحيته";
      });
    }
  }

  void _navigateToHome(String? role) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: const Text('✅ تم تسجيل الدخول بنجاح!'), backgroundColor: primaryGreen),
    );

    String route;
    if (role == 'buyer') {
      route = BuyerHomeScreen.routeName;
    } else if (role == 'consumer') {
      route = ConsumerHomeScreen.routeName;
    } else if (role == 'seller') {
      route = SellerScreen.routeName;
    } else {
      route = SellerScreen.routeName;
    }

    Navigator.of(context).pushNamedAndRemoveUntil(route, (route) => false);
  }

  Future<void> _sendNotificationDataToAWS() async {
    try {
      String? token = await FirebaseMessaging.instance.getToken();
      String? uid = FirebaseAuth.instance.currentUser?.uid;
      if (token != null && uid != null) {
        const String apiUrl = "https://5uex7vzy64.execute-api.us-east-1.amazonaws.com/V2/new_nofiction";
        await http.post(Uri.parse(apiUrl),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({
              "userId": uid, 
              "fcmToken": token, 
              "role": UserSession.role ?? "consumer"
            }));
      }
    } catch (e) {
      debugPrint("AWS Error: $e");
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
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => const ForgotPasswordScreen())),
              child: Text('نسيت كلمة المرور؟', style: TextStyle(color: primaryGreen)),
            ),
          ),
          const SizedBox(height: 10),
          _buildSubmitButton(),
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(_errorMessage!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
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
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: Colors.grey.shade300)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: Colors.grey.shade200)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: Color(0xff28a745), width: 2)),
      ),
      validator: validator,
      onSaved: onSaved,
    );
  }
}

