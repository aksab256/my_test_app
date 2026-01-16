// lib/screens/forgot_password_screen.dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:sizer/sizer.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final Color primaryGreen = const Color(0xff28a745);

  // دالة فتح الواتساب
  void _contactSupport() async {
    String phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى إدخال رقم الهاتف أولاً')),
      );
      return;
    }

    // رقم الدعم الفني الخاص بك ورسالة تلقائية
    String whatsappNumber = "201021070462"; 
    String message = "مرحباً دعم أكسب، لقد فقدت كلمة السر الخاصة بحسابي المسجل برقم: $phone. أرجو المساعدة في استعادتها.";
    
    // إنشاء الرابط
    String url = "https://wa.me/$whatsappNumber?text=${Uri.encodeComponent(message)}";
    final Uri uri = Uri.parse(url);

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('عذراً، لم نتمكن من فتح تطبيق واتساب')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAF9),
      appBar: AppBar(
        title: const Text('استعادة كلمة المرور', style: TextStyle(fontFamily: 'Cairo')),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        foregroundColor: Colors.black,
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 8.w),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_reset_rounded, size: 100, color: Color(0xff28a745)),
              SizedBox(height: 3.h),
              Text(
                'نسيت كلمة السر؟',
                style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 1.h),
              Text(
                'أدخل رقم هاتفك وسنقوم بتوجيهك للدعم الفني لاستعادة حسابك فوراً.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11.sp, color: Colors.grey.shade600),
              ),
              SizedBox(height: 4.h),
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                textAlign: TextAlign.right,
                decoration: InputDecoration(
                  hintText: 'رقم الهاتف المسجل',
                  prefixIcon: const Icon(Icons.phone_android, color: Color(0xff28a745)),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                ),
              ),
              SizedBox(height: 3.h),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton.icon(
                  onPressed: _contactSupport,
                  icon: const Icon(Icons.message, color: Colors.white),
                  label: const Text(
                    'تواصل مع الدعم عبر واتساب',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryGreen,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
