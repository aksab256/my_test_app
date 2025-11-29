// lib/screens/auth/new_client_screen.dart

import 'package:flutter/material.dart';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sizer/sizer.dart'; 
// 💡 افترض أن المسارات التالية صحيحة:
import 'package:my_test_app/data_sources/client_data_source.dart';
import 'package:my_test_app/screens/auth/client_selection_step.dart';
// ✅✅ تصحيح خطأ الاستيراد: إزالة "package:" المكررة ✅✅
import 'package:my_test_app/screens/auth/client_details_step.dart'; 
import 'package:my_test_app/widgets/form_widgets.dart';

class NewClientScreen extends StatefulWidget {
  const NewClientScreen({super.key});
  @override
  State<NewClientScreen> createState() => _NewClientScreenState();
}

class _NewClientScreenState extends State<NewClientScreen> {
  final PageController _pageController = PageController();
  final ClientDataSource _dataSource = ClientDataSource();

  // ⭐️ حالة حفظ البيانات المجمعة ⭐️
  String _selectedCountry = 'egypt';
  String _selectedUserType = '';
  final Map<String, TextEditingController> _controllers = {
    'fullname': TextEditingController(),
    'email': TextEditingController(),
    'password': TextEditingController(),
    'confirmPassword': TextEditingController(),
    'address': TextEditingController(),
    'merchantName': TextEditingController(),
    'additionalPhone': TextEditingController(),
  };

  String? _businessType;
  File? _logoFile;
  File? _crFile;
  File? _tcFile;
  Map<String, double>? _location;
  int _currentStep = 1;
  bool _isSaving = false;

  @override
  void dispose() {
    _pageController.dispose();
    _controllers.forEach((key, controller) => controller.dispose());
    super.dispose();
  }

  // دالة للانتقال بين الخطوات
  void _goToStep(int step) {
    setState(() {
      _currentStep = step;
    });
    _pageController.animateToPage(
      step - 1,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeIn,
    );
  }

  // 1. دالة معالجة الخطوة 1 & 2
  void _handleSelectionStep({
    required String country,
    required String userType,
  }) {
    setState(() {
      _selectedCountry = country;
      _selectedUserType = userType;
    });
    _goToStep(3);
  }

  // 2. دالة التسجيل الرئيسية
  Future<void> _handleRegistration() async {
    // 1. جمع البيانات الأساسية
    final email = _controllers['email']!.text.trim();
    final password = _controllers['password']!.text;
    final fullName = _controllers['fullname']!.text.trim();
    final address = _controllers['address']!.text.trim();

    // 2. التحقق من حقول تاجر الجملة إذا لزم الأمر
    if (_selectedUserType == 'seller') {
      if (_controllers['merchantName']!.text.isEmpty || _businessType == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الرجاء إدخال اسم الشركة ونوع النشاط التجاري.')));
        return;
      }
    }

    // 3. تعيين حالة الحفظ
    setState(() {
      _isSaving = true;
    });

    // 4. رفع الملفات إلى Cloudinary (تسلسل رفع الملفات)
    String? logoUrl, crUrl, tcUrl;
    try {
      if (_logoFile != null) logoUrl = await _dataSource.uploadImageToCloudinary(_logoFile!);
      if (_crFile != null) crUrl = await _dataSource.uploadImageToCloudinary(_crFile!);
      if (_tcFile != null) tcUrl = await _dataSource.uploadImageToCloudinary(_tcFile!);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشل رفع الملفات: $e')));
      setState(() => _isSaving = false);
      return;
    }
    // 5. بناء حمولة البيانات (Payload) لـ Firestore
    final Map<String, dynamic> userData = {
      'fullname': fullName,
      'email': email,
      'address': address,
      'location': _location != null
          ? {'lat': _location!['lat'], 'lng': _location!['lng']}
          : null,
      'role': _selectedUserType,
      'country': _selectedCountry,
      'createdAt': FieldValue.serverTimestamp(),
    };

    // إضافة حقول البائع (إن وجدت)
    if (_selectedUserType == 'seller') {
      userData.addAll({
        'merchantName': _controllers['merchantName']!.text.trim(),
        'businessType': _businessType,
        'additionalPhone': _controllers['additionalPhone']!.text.trim(),
        'logoUrl': logoUrl,
        'crUrl': crUrl,
        'tcUrl': tcUrl,
        'isVerified': false,
      });
    } else {
        userData['isVerified'] = true;
    }

    // 6. تسجيل المستخدم في Auth و Firestore
    try {
      await _dataSource.registerAndSaveUser(
        email: email,
        password: password,
        data: userData,
      );
      // إذا نجح، يتم التحويل
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ تم التسجيل بنجاح! يتم تحويلك الآن...'))
      );

      // For now, let's navigate to the post registration message page
      Navigator.of(context).pushReplacementNamed(
        '/post_registration_message',
        arguments: {'isSeller': _selectedUserType == 'seller'},
      );
    } catch (e) {
      String errorMessage = 'فشل التسجيل: يرجى المحاولة لاحقاً.';
      if (e.toString().contains('auth/email-already-in-use')) {
        errorMessage = 'هذا البريد الإلكتروني مسجل بالفعل.';
      } else if (e.toString().contains('auth/weak-password')) {
        errorMessage = 'كلمة المرور ضعيفة. يرجى اختيار كلمة مرور أقوى.';
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ $errorMessage')));
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            // 🎯 استخدام ارتفاع نسبي للمسافة العمودية
            padding: EdgeInsets.symmetric(vertical: 5.h),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 650),
              // 🎯 استخدام عرض نسبي للمسافة الأفقية
              margin: EdgeInsets.symmetric(horizontal: 5.w),
              padding: EdgeInsets.all(5.w), // هامش داخلي كبير نسبي
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(25),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    spreadRadius: 0,
                    blurRadius: 24,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // الشعار
                  const _LogoHeader(),
                  SizedBox(height: 3.h), // 🎯 استخدام ارتفاع نسبي

                  // الـ PageView للخطوات
                  // ⭐️ العودة لاستخدام SizedBox بارتفاع آمن (65.h) لحل مشكلة Unbounded Error
                  SizedBox(
                    height: 65.h, 
                    child: PageView(
                      controller: _pageController,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        // الخطوة 1: اختيار البلد
                        ClientSelectionStep(
                          stepNumber: 1,
                          onCompleted: ({required String country, required String userType}) {},
                          onCountrySelected: (country) => _goToStep(2),
                          initialCountry: _selectedCountry,
                          initialUserType: _selectedUserType,
                        ),

                        // الخطوة 2: اختيار نوع الحساب
                        ClientSelectionStep(
                          stepNumber: 2,
                          initialCountry: _selectedCountry,
                          initialUserType: _selectedUserType,
                          onCompleted: _handleSelectionStep,
                          onGoBack: () => _goToStep(1),
                          onCountrySelected: (_) {},
                        ),

                        // الخطوة 3: إدخال البيانات والتسجيل
                        ClientDetailsStep(
                          controllers: _controllers,
                          selectedUserType: _selectedUserType,
                          isSaving: _isSaving,
                          onBusinessTypeChanged: (value) => _businessType = value,
                          onFilePicked: ({required String field, required File file}) {
                            setState(() {
                              if (field == 'logo') _logoFile = file;
                              if (field == 'cr') _crFile = file;
                              if (field == 'tc') _tcFile = file;
                            });
                          },
                          onLocationChanged: ({required double lat, required double lng}) => _location = {'lat': lat, 'lng': lng},
                          onRegister: _handleRegistration,
                          onGoBack: () => _goToStep(2),
                        ),
                      ],
                    ),
                  ),
                  // تذييل الصفحة
                  SizedBox(height: 3.h), // 🎯 استخدام ارتفاع نسبي
                  const _Footer(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ----------------------------------------------------
// 💡 مكونات ثابتة مساعدة (Logo & Footer)
// ----------------------------------------------------
class _LogoHeader extends StatelessWidget {
  const _LogoHeader();

  @override
  Widget build(BuildContext context) {
    // 🌟 تحسين تصميم Header باستخدام أيقونة M3
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 💡 أيقونة M3 ممتلئة
            Icon(Icons.shopping_bag_rounded, size: 4.h, color: Theme.of(context).colorScheme.primary), // 🎯 حجم الأيقونة نسبي
            SizedBox(width: 1.w), // 🎯 عرض نسبي
            Text(
              'أسواق أكسب',
              style: TextStyle(
                fontSize: 14.sp, // 🎯 حجم الخط نسبي (sp يتناسب مع الخط)
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
        ),
        SizedBox(height: 1.h), // 🎯 ارتفاع نسبي
        Text(
          'تسجيل حساب جديد',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 8.sp), // 🎯 حجم خط نسبي
        ),
      ],
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        Navigator.of(context).pop();
      },
      child: Padding(
        padding: EdgeInsets.only(top: 1.h), //  🎯 مسافة نسبية
        child: Text.rich(
          TextSpan(
            text: 'لديك حساب بالفعل؟ ',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 8.5.sp), // 🎯 حجم خط نسبي
            children: [
              TextSpan(
                text: 'تسجيل الدخول',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.underline,
                ),
              ),
            ],
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
