// lib/screens/otp_verification_screen.dart
import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import 'package:my_test_app/helpers/auth_service.dart';
import 'package:my_test_app/services/user_session.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:my_test_app/providers/buyer_data_provider.dart';
// استيراد الشاشات للتوجيه بعد النجاح
import 'package:my_test_app/screens/buyer/buyer_home_screen.dart';
import 'package:my_test_app/screens/consumer/consumer_home_screen.dart';
import 'package:my_test_app/screens/seller_screen.dart';

class OtpVerificationScreen extends StatefulWidget {
  static const String routeName = '/otp_verification';
  const OtpVerificationScreen({super.key});

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final TextEditingController _otpController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  final AuthService _authService = AuthService();
  final Color primaryGreen = const Color(0xff28a745);

  Future<void> _verifyAndLogin(Map<String, dynamic> args) async {
    String enteredOtp = _otpController.text.trim();
    String correctOtp = args['otpCode'];
    String phone = args['phone'];
    String password = args['password'];

    if (enteredOtp != correctOtp) {
      setState(() => _errorMessage = "كود التحقق غير صحيح");
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // تنفيذ عملية الدخول الحقيقية (نفس اللوجيك بتاعك الأصلي)
      String? userRole;
      try {
        userRole = await _authService.signInWithEmailAndPassword("$phone@aksab.com", password);
      } catch (e) {
        userRole = await _authService.signInWithEmailAndPassword("$phone@aswaq.com", password);
      }

      final userToCheck = FirebaseAuth.instance.currentUser;
      if (userToCheck != null) {
        // فحص حالة الحذف (نفس الكود الأصلي)
        var checkDoc = await FirebaseFirestore.instance.collection('consumers').doc(userToCheck.uid).get();
        if (!checkDoc.exists) checkDoc = await FirebaseFirestore.instance.collection('users').doc(userToCheck.uid).get();
        if (!checkDoc.exists) checkDoc = await FirebaseFirestore.instance.collection('sellers').doc(userToCheck.uid).get();

        if (checkDoc.exists && checkDoc.data()?['status'] == 'delete_requested') {
          await FirebaseAuth.instance.signOut();
          setState(() {
            _isLoading = false;
            _errorMessage = 'هذا الحساب قيد الحذف نهائياً';
          });
          return;
        }
      }

      await UserSession.loadSession();

      if (mounted) {
        await Provider.of<BuyerDataProvider>(context, listen: false).initializeData(
          FirebaseAuth.instance.currentUser?.uid,
          UserSession.ownerId,
          UserSession.merchantName ?? "مستخدم أكسب"
        );
        
        _navigateToHome(userRole ?? UserSession.role);
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = "حدث خطأ أثناء تسجيل الدخول";
      });
    }
  }

  void _navigateToHome(String? role) {
    String route = (role == 'buyer') ? BuyerHomeScreen.routeName 
                 : (role == 'consumer') ? ConsumerHomeScreen.routeName 
                 : SellerScreen.routeName;
    Navigator.of(context).pushNamedAndRemoveUntil(route, (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;

    return Scaffold(
      appNavigatorBar: AppBar(title: const Text("تأكيد رقم الهاتف"), backgroundColor: Colors.white, elevation: 0, foregroundColor: Colors.black),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 8.w),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text("أدخل كود التحقق المرسل إلى", style: TextStyle(fontSize: 14.sp)),
              Text(args['phone'], style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold, color: primaryGreen)),
              SizedBox(height: 4.h),
              TextField(
                controller: _otpController,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                letterSpacing: 10,
                style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  hintText: "------",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                ),
              ),
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 15),
                  child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
                ),
              SizedBox(height: 4.h),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : () => _verifyAndLogin(args),
                  style: ElevatedButton.styleFrom(backgroundColor: primaryGreen, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                  child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text("تأكيد ودخول", style: TextStyle(color: Colors.white, fontSize: 15)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

