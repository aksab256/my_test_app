// lib/screens/login_screen.dart
import 'package:flutter/material.dart';
import 'package:my_test_app/widgets/login_form_widget.dart';
import 'package:flutter/gestures.dart';
import 'package:sizer/sizer.dart';
import 'package:url_launcher/url_launcher.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  static const String routeName = '/login';

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // حالة الموافقة على الشروط
  bool _isTermsAccepted = true;

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
            // خلفية جمالية علوية
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
                    // شعار أسواق أكسب
                    const Icon(Icons.account_circle, size: 120, color: primaryGreen),
                    SizedBox(height: 3.h),
                    Text(
                      'أهلاً بك في أسواق أكسب', // العودة للاسم الصحيح
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
                    
                    // حاوية الفورم
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
                      // تعطيل التفاعل مع الفورم في حال عدم الموافقة على الشروط
                      child: IgnorePointer(
                        ignoring: !_isTermsAccepted,
                        child: Opacity(
                          opacity: _isTermsAccepted ? 1.0 : 0.6,
                          child: const LoginFormWidget(),
                        ),
                      ),
                    ),
                    
                    SizedBox(height: 3.h),
                    
                    // مكون الفوتر (الشروط وإنشاء الحساب)
                    _FooterWidget(
                      isAccepted: _isTermsAccepted,
                      onChanged: (val) {
                        setState(() {
                          _isTermsAccepted = val ?? false;
                        });
                      },
                    ),
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
  final bool isAccepted;
  final ValueChanged<bool?> onChanged;

  const _FooterWidget({required this.isAccepted, required this.onChanged});

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
        // شروط الاستخدام والخصوصية
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Checkbox(
              value: isAccepted,
              activeColor: primaryGreen,
              onChanged: onChanged,
            ),
            Expanded(
              child: Text.rich(
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
                textAlign: TextAlign.right,
              ),
            ),
          ],
        ),
        SizedBox(height: 1.h),
        // إنشاء حساب جديد
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

