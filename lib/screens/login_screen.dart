// lib/screens/login_screen.dart
import 'package:flutter/material.dart';
import 'package:my_test_app/widgets/login_form_widget.dart';
import 'package:flutter/gestures.dart';
import 'package:sizer/sizer.dart'; // سنستخدم sizer للخطوط

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
                        fontSize: 22.sp, // خط كبير وواضح
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
                      child: const LoginFormWidget(), // 🎯 هنا يتم التعديل الجوهري
                    ),
                    SizedBox(height: 4.h),
                    const _FooterWidget(),
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

class _FooterWidget extends StatelessWidget {
  const _FooterWidget();
  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        text: 'ليس لديك حساب؟ ',
        style: TextStyle(color: Colors.grey.shade700, fontSize: 13.sp),
        children: [
          TextSpan(
            text: 'إنشاء حساب جديد',
            style: TextStyle(color: const Color(0xFF2D9E68), fontWeight: FontWeight.bold),
            recognizer: TapGestureRecognizer()..onTap = () => Navigator.of(context).pushNamed('/register'),
          ),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }
}
