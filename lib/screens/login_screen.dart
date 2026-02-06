// lib/screens/login_screen.dart
import 'package:flutter/material.dart';
import 'package:my_test_app/widgets/login_form_widget.dart';
import 'package:flutter/gestures.dart';
import 'package:sizer/sizer.dart';
import 'package:url_launcher/url_launcher.dart'; // تأكد من وجود هذه المكتبة لفتح الرابط

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});
  static const String routeName = '/login';

  @override
  Widget build(BuildContext context) {
    const Color primaryGreen = Color(0xFF2D9E68);
    const Color lightBg = Color(0xFFF8FAF9);

    return Scaffold(
      backgroundColor: lightBg,
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: Stack(
          children: [
            Positioned(
              top: -80,
              right: -80,
              child: CircleAvatar(radius: 120, backgroundColor: primaryGreen.withOpacity(0.05)),
            ),
            Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: 6.w),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.account_circle, size: 120, color: primaryGreen),
                    SizedBox(height: 3.h),
                    Text(
                      'أهلاً بك في أكسب',
                      style: TextStyle(
                        fontSize: 22.sp,
                        fontWeight: FontWeight.w900, 
                        color: const Color(0xFF1A1A1A)
                      ),
                    ),
                    SizedBox(height: 1.h),
                    Text(
                      'سجل دخولك برقم الهاتف للمتابعة',
                      style: TextStyle(fontSize: 12.sp, color: Colors.grey.shade600),
                    ),
                    SizedBox(height: 5.h),
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.06), 
                            blurRadius: 30, 
                            offset: const Offset(0, 15)
                          )
                        ],
                      ),
                      child: const LoginFormWidget(),
                    ),
                    SizedBox(height: 3.h),
                    const _FooterWidget(), // المكون المحدث الذي يحتوي على الشروط
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FooterWidget extends StatefulWidget {
  const _FooterWidget();

  @override
  State<_FooterWidget> createState() => _FooterWidgetState();
}

class _FooterWidgetState extends State<_FooterWidget> {
  bool _isAccepted = true; // الحالة الافتراضية للموافقة

  void _launchPrivacyUrl() async {
    final Uri url = Uri.parse('https://aksab.shop/');
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      debugPrint('Could not launch $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryGreen = Color(0xFF2D9E68);

    return Column(
      children: [
        // --- قسم شروط الاستخدام والخصوصية ---
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Checkbox(
              value: _isAccepted,
              activeColor: primaryGreen,
              onChanged: (value) {
                setState(() {
                  _isAccepted = value ?? false;
                });
              },
            ),
            Text.rich(
              TextSpan(
                text: 'أوافق على ',
                style: TextStyle(color: Colors.grey.shade700, fontSize: 11.sp),
                children: [
                  TextSpan(
                    text: 'شروط الاستخدام والخصوصية',
                    style: const TextStyle(
                      color: primaryGreen,
                      fontWeight: FontWeight.bold,
                      decoration: TextDecoration.underline,
                    ),
                    recognizer: TapGestureRecognizer()..onTap = _launchPrivacyUrl,
                  ),
                ],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        SizedBox(height: 1.h),
        // --- قسم إنشاء حساب جديد ---
        Text.rich(
          TextSpan(
            text: 'ليس لديك حساب؟ ',
            style: TextStyle(color: Colors.grey.shade700, fontSize: 13.sp),
            children: [
              TextSpan(
                text: 'إنشاء حساب جديد',
                style: const TextStyle(color: primaryGreen, fontWeight: FontWeight.bold),
                recognizer: TapGestureRecognizer()..onTap = () => Navigator.of(context).pushNamed('/register'),
              ),
            ],
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
