import 'package:flutter/material.dart';
import 'package:my_test_app/widgets/login_form_widget.dart';
import 'package:flutter/gestures.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});
  static const String routeName = '/login';

  @override
  Widget build(BuildContext context) {
    // ألوان البراند
    const Color primaryGreen = Color(0xFF2D9E68);
    const Color lightBg = Color(0xFFF8FAF9);

    return Scaffold(
      backgroundColor: lightBg,
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: Stack( // استخدام Stack لإضافة دوائر جمالية في الخلفية
          children: [
            // دائرة جمالية في الخلفية
            Positioned(
              top: -100,
              right: -100,
              child: CircleAvatar(radius: 150, backgroundColor: primaryGreen.withOpacity(0.05)),
            ),
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // 1. منطقة اللوجو والترحيب
                    const Hero(
                      tag: 'logo',
                      child: CircleAvatar(
                        radius: 50,
                        backgroundColor: Colors.white,
                        child: Padding(
                          padding: EdgeInsets.all(12.0),
                          child: Image(
                            image: AssetImage('assets/images/logo2.png'),
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'أهلاً بك في أكسب',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'سجل دخولك للمتابعة',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 40),

                    // 2. كارت نموذج تسجيل الدخول
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: const LoginFormWidget(),
                    ),
                    const SizedBox(height: 32),

                    // 3. الفوتر (إنشاء حساب)
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
        style: TextStyle(color: Colors.grey.shade700, fontSize: 15),
        children: [
          TextSpan(
            text: 'إنشاء حساب جديد',
            style: TextStyle(
              color: Theme.of(context).primaryColor,
              fontWeight: FontWeight.bold,
              decoration: TextDecoration.none,
            ),
            recognizer: TapGestureRecognizer()
              ..onTap = () => Navigator.of(context).pushNamed('/register'),
          ),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }
}
