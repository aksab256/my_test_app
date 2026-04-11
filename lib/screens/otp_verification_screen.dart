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
  final List<TextEditingController> _controllers = List.generate(4, (index) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(4, (index) => FocusNode());
  bool _isLoading = false;

  Future<void> _verifyOtp() async {
    final String enteredOtp = _controllers.map((c) => c.text).join();
    final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
    final String correctOtp = args['otp'].toString();
    final LoggedInUser user = args['user'];

    if (enteredOtp != correctOtp) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('كود التحقق غير صحيح')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 1. حفظ الجلسة (نفس منطق الأصل)
      final prefs = await SharedPreferences.getInstance();
      final Map<String, dynamic> userData = {
        'id': user.id,
        'fullname': user.fullname,
        'role': user.role,
        'phone': user.phone,
        'ownerId': user.id,
      };
      await prefs.setString('loggedUser', jsonEncode(userData));
      
      // 2. تحميل الجلسة فعلياً
      await UserSession.loadSession();

      // 3. مهام الخلفية (AWS Notifications)
      _sendNotificationDataToAWS();

      // 4. تهيئة البروفايدر (نفس سطر الأصل السحري)
      if (!mounted) return;
      await Provider.of<BuyerDataProvider>(context, listen: false).initializeData(
        user.id, user.id, user.fullname
      );

      // 5. التوجيه النهائي
      String route = user.role == "seller" ? SellerScreen.routeName : 
                     (user.role == "consumer" ? ConsumerHomeScreen.routeName : BuyerHomeScreen.routeName);
      
      Navigator.pushNamedAndRemoveUntil(context, route, (route) => false);

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('حدث خطأ في الجلسة')));
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
    // الـ UI بتاعك اللي فيه الـ 4 مربعات
    return Scaffold(
      appBar: AppBar(title: const Text('تأكيد الأمان'), centerTitle: true),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const Text('أدخل كود التحقق المكون من 4 أرقام', style: TextStyle(fontSize: 16)),
              const SizedBox(height: 30),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(4, (index) => SizedBox(
                  width: 60,
                  child: TextField(
                    controller: _controllers[index],
                    focusNode: _focusNodes[index],
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    maxLength: 1,
                    decoration: const InputDecoration(counterText: "", border: OutlineInputBorder()),
                    onChanged: (v) {
                      if (v.isNotEmpty && index < 3) _focusNodes[index + 1].requestFocus();
                      if (v.isEmpty && index > 0) _focusNodes[index - 1].requestFocus();
                    },
                  ),
                )),
              ),
              const SizedBox(height: 40),
              _isLoading ? const CircularProgressIndicator() : ElevatedButton(
                onPressed: _verifyOtp,
                style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50), backgroundColor: Colors.green),
                child: const Text('تأكيد ودخول', style: TextStyle(color: Colors.white, fontSize: 18)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

