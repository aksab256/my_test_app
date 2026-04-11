import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:my_test_app/providers/buyer_data_provider.dart';
import 'package:my_test_app/screens/buyer/buyer_home_screen.dart';
import 'package:my_test_app/screens/consumer/consumer_home_screen.dart';
import 'package:my_test_app/screens/seller_screen.dart';
import 'package:my_test_app/services/user_session.dart';
import 'package:my_test_app/models/logged_user.dart';
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

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  Future<void> _verifyOtp() async {
    final String enteredOtp = _controllers.map((controller) => controller.text).join();
    
    if (enteredOtp.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى إدخال كود التحقق كاملاً')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
      final String correctOtp = args['otp'].toString();
      final LoggedInUser user = args['user'];

      if (enteredOtp == correctOtp) {
        // حفظ الجلسة محلياً
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('loggedUser', jsonEncode(user.toJson()));
        await UserSession.updateSession(user);

        // تهيئة بيانات المستخدم في البروفايدر
        await Provider.of<BuyerDataProvider>(context, listen: false)
            .initializeData(user.id, user.id, user.fullname);

        // التوجيه حسب الرتبة
        if (!mounted) return;
        if (user.role == "seller") {
          Navigator.pushNamedAndRemoveUntil(context, SellerScreen.routeName, (route) => false);
        } else if (user.role == "consumer") {
          Navigator.pushNamedAndRemoveUntil(context, ConsumerHomeScreen.routeName, (route) => false);
        } else {
          Navigator.pushNamedAndRemoveUntil(context, BuyerHomeScreen.routeName, (route) => false);
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('كود التحقق غير صحيح')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('حدث خطأ أثناء التحقق')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تأكيد رقم الهاتف'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'أدخل كود التحقق المرسل إليك',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(4, (index) {
                return SizedBox(
                  width: 60,
                  child: TextField(
                    controller: _controllers[index],
                    focusNode: _focusNodes[index],
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    maxLength: 1,
                    decoration: const InputDecoration(
                      counterText: "",
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      if (value.isNotEmpty && index < 3) {
                        _focusNodes[index + 1].requestFocus();
                      } else if (value.isEmpty && index > 0) {
                        _focusNodes[index - 1].requestFocus();
                      }
                    },
                  ),
                );
              }),
            ),
            const SizedBox(height: 40),
            _isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: _verifyOtp,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                      backgroundColor: Colors.green,
                    ),
                    child: const Text('تأكيد', style: TextStyle(color: Colors.white, fontSize: 18)),
                  ),
          ],
        ),
      ),
    );
  }
}

