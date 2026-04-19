import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:my_test_app/providers/buyer_data_provider.dart';
import 'package:my_test_app/screens/buyer/buyer_home_screen.dart';
import 'package:my_test_app/screens/consumer/consumer_home_screen.dart';
import 'package:my_test_app/screens/seller_screen.dart';
import 'package:my_test_app/services/user_session.dart';
import 'package:my_test_app/models/logged_user.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class OtpVerificationScreen extends StatefulWidget {
  static const routeName = '/otp_verification';
  const OtpVerificationScreen({super.key});

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  // فايربيز بيبعت 6 أرقام افتراضياً، هنخليها 6 عشان تتوافق مع الكريدت المجاني
  final List<TextEditingController> _controllers = List.generate(6, (index) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (index) => FocusNode());
  bool _isLoading = false;

  Future<void> _verifyOtp() async {
    final String enteredOtp = _controllers.map((c) => c.text).join();
    final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
    
    // استلام البيانات من الشاشة السابقة
    final String verificationId = args['verificationId'] ?? '';
    final LoggedInUser user = args['user'];
    final bool isFirebase = args['isFirebase'] ?? false;

    if (enteredOtp.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('برجاء إدخال كود الأمان كاملاً')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (isFirebase) {
        // --- التحقق عبر فايربيز حصرياً لاستغلال الكريدت ---
        PhoneAuthCredential credential = PhoneAuthProvider.credential(
          verificationId: verificationId,
          smsCode: enteredOtp,
        );
        // محاولة تسجيل الدخول
        await FirebaseAuth.instance.signInWithCredential(credential);
      } else {
        // منطق SMS Misr القديم (لو احتجته مستقبلاً)
        if (enteredOtp != args['otp'].toString()) throw Exception("كود غير صحيح");
      }

      // --- بعد النجاح: حفظ الجلسة وتوجيه المندوب ---
      final prefs = await SharedPreferences.getInstance();
      final Map<String, dynamic> userData = {
        'id': user.id,
        'fullname': user.fullname,
        'role': user.role,
        'phone': user.phone,
        'ownerId': user.id,
      };
      
      await prefs.setString('loggedUser', jsonEncode(userData));
      await UserSession.loadSession();
      
      // مهام الخلفية (تحديث الـ Token للعهدة)
      _sendNotificationDataToAWS();

      if (!mounted) return;
      
      // تهيئة البيانات
      await Provider.of<BuyerDataProvider>(context, listen: false).initializeData(
          user.id, user.id, user.fullname
      );

      // التوجيه بناءً على الدور (Role)
      String route = user.role == "seller" ? SellerScreen.routeName :
                     (user.role == "consumer" ? ConsumerHomeScreen.routeName : BuyerHomeScreen.routeName);

      Navigator.pushNamedAndRemoveUntil(context, route, (route) => false);

    } on FirebaseAuthException catch (e) {
      String error = "فشل تأمين العهدة";
      if (e.code == 'invalid-verification-code') error = "كود الأمان غير صحيح أو انتهت صلاحيته";
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('حدث خطأ في مزامنة الجلسة')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _sendNotificationDataToAWS() async {
    try {
      String? token = await FirebaseMessaging.instance.getToken();
      String? uid = FirebaseAuth.instance.currentUser?.uid;
      if (token != null && uid != null) {
        await http.post(
          Uri.parse("https://5uex7vzy64.execute-api.us-east-1.amazonaws.com/V2/new_nofiction"),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({"userId": uid, "fcmToken": token, "role": UserSession.role ?? "seller"})
        );
      }
    } catch (e) { debugPrint("AWS Error: $e"); }
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryGreen = Color(0xFF2D9E68);
    
    return Scaffold(
      appBar: AppBar(title: const Text('تأكيد أمان العهدة'), centerTitle: true),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const Icon(Icons.shield_outlined, size: 80, color: primaryGreen),
              const SizedBox(height: 20),
              const Text('أدخل كود تأمين العهدة المستلم', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 30),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(6, (index) => SizedBox(
                  width: 45, // صغرنا العرض عشان يكفي 6 خانات
                  child: TextField(
                    controller: _controllers[index],
                    focusNode: _focusNodes[index],
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    maxLength: 1,
                    decoration: InputDecoration(
                      counterText: "",
                      enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.grey.shade300)),
                      focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: primaryGreen, width: 2)),
                    ),
                    onChanged: (v) {
                      if (v.isNotEmpty && index < 5) _focusNodes[index + 1].requestFocus();
                      if (v.isEmpty && index > 0) _focusNodes[index - 1].requestFocus();
                    },
                  ),
                )),
              ),
              const SizedBox(height: 40),
              _isLoading ? const CircularProgressIndicator(color: primaryGreen) : ElevatedButton(
                onPressed: _verifyOtp,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 55),
                  backgroundColor: primaryGreen,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                ),
                child: const Text('تأكيد العهدة والدخول', style: TextStyle(color: Colors.white, fontSize: 18)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

