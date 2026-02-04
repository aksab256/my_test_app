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

  Future<void> _submitLogin() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      String? userRole;
      String phoneClean = _phone.trim();
      
      try {
        debugPrint("Attempting login via @aksab.com...");
        userRole = await _authService.signInWithEmailAndPassword("$phoneClean@aksab.com", _password);
      } catch (e) {
        debugPrint("Aksab failed, attempting @aswaq.com...");
        userRole = await _authService.signInWithEmailAndPassword("$phoneClean@aswaq.com", _password);
      }

      // تحميل بيانات الجلسة في الذاكرة
      await UserSession.loadSession();
      
      // 🟢 [التعديل السحري]: تحديث البروفايدر فوراً بالبيانات الجديدة المخزنة
      // هذا السطر يمنع مشكلة "إغلاق وفتح التطبيق" ويجعل العنوان يظهر فوراً
      if (mounted) {
        await Provider.of<BuyerDataProvider>(context, listen: false).initializeData(
          FirebaseAuth.instance.currentUser?.uid,
          UserSession.ownerId,
          UserSession.merchantName ?? "مستخدم أكسب"
        );
      }

      // منطق الموظفين (Sub Users)
      if (UserSession.isSubUser) {
        final subUserDoc = await FirebaseFirestore.instance.collection("subUsers").doc(phoneClean).get();
        if (subUserDoc.exists && subUserDoc.data()?['mustChangePassword'] == true) {
          if (mounted) setState(() => _isLoading = false);
          _showChangePasswordDialog(phoneClean);
          return;
        }
      }

      _sendNotificationDataToAWS().catchError((e) => debugPrint("AWS Silent Error: $e"));

      if (!mounted) return;
      _navigateToHome(userRole ?? UserSession.role);

    } catch (e) {
      debugPrint("Core Login Error: $e");
      if (FirebaseAuth.instance.currentUser != null) {
        _navigateToHome(UserSession.role);
        return;
      }
      
      if (mounted) {
        setState(() {
          _isLoading = false;
          if (e.toString().contains('account-not-active')) {
            _errorMessage = 'هذا الحساب معلق، يرجى التواصل مع الإدارة';
          } else {
            _errorMessage = 'رقم الهاتف أو كلمة المرور غير صحيحة';
          }
        });
      }
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
    
    debugPrint("Final Redirect: $route for role: $role");
    Navigator.of(context).pushNamedAndRemoveUntil(route, (route) => false);
  }

  void _showChangePasswordDialog(String phone) {
    final TextEditingController newPassController = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("تأمين الحساب", textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("يرجى تعيين كلمة سر جديدة لحماية حسابك."),
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
                await FirebaseAuth.instance.currentUser?.updatePassword(newPassController.text.trim());
                await FirebaseFirestore.instance.collection("subUsers").doc(phone).update({'mustChangePassword': false});
                
                if (!mounted) return;
                _navigateToHome(UserSession.role);
              } catch (e) {
                debugPrint("Pass update error: $e");
              }
            },
            child: const Text("حفظ ودخول", style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }

  Future<void> _sendNotificationDataToAWS() async {
    try {
      String? token = await FirebaseMessaging.instance.getToken();
      String? uid = FirebaseAuth.instance.currentUser?.uid;
      if (token != null && uid != null) {
        const String apiUrl = "https://5uex7vzy64.execute-api.us-east-1.amazonaws.com/V2/new_nofiction";
        await http.post(Uri.parse(apiUrl),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({"userId": uid, "fcmToken": token, "role": UserSession.role ?? "seller"}));
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
        child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('تسجيل الدخول', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
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
