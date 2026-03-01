// lib/screens/auth/new_client_screen.dart
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:sizer/sizer.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:my_test_app/data_sources/client_data_source.dart';
import 'package:my_test_app/screens/auth/client_selection_step.dart';
import 'package:my_test_app/screens/auth/client_details_step.dart';

class NewClientScreen extends StatefulWidget {
  const NewClientScreen({super.key});

  @override
  State<NewClientScreen> createState() => _NewClientScreenState();
}

class _NewClientScreenState extends State<NewClientScreen> {
  final PageController _pageController = PageController();
  final ClientDataSource _dataSource = ClientDataSource();

  String _selectedCountry = 'egypt';
  String _selectedUserType = '';

  // ✨ إضافة ownerName هنا لضمان وجود متحكم له
  final Map<String, TextEditingController> _controllers = {
    'fullname': TextEditingController(),
    'ownerName': TextEditingController(), // حقل اسم صاحب النشاط
    'phone': TextEditingController(),
    'password': TextEditingController(),
    'confirmPassword': TextEditingController(),
    'address': TextEditingController(),
    'merchantName': TextEditingController(),
    'additionalPhone': TextEditingController(),
    'businessType': TextEditingController(),
  };

  String? _logoUrl;
  String? _crUrl;
  String? _tcUrl;
  
  Map<String, double>? _location;
  int _currentStep = 1;
  bool _isSaving = false;

  @override
  void dispose() {
    _pageController.dispose();
    _controllers.forEach((key, controller) => controller.dispose());
    super.dispose();
  }

  void _goToStep(int step) {
    setState(() => _currentStep = step);
    _pageController.animateToPage(
      step - 1,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOutCubic,
    );
  }

  void _handleSelectionStep({required String country, required String userType}) {
    setState(() {
      _selectedCountry = country;
      _selectedUserType = userType;
    });
    _goToStep(3);
  }

  void _showSuccessDialog() {
    bool isSeller = _selectedUserType == 'seller';
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
          icon: const Icon(Icons.check_circle_rounded, color: Color(0xFF2D9E68), size: 70),
          title: Text('تم التسجيل بنجاح!', 
            style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w900, color: const Color(0xFF2D9E68))),
          content: Text(
            isSeller
                ? "شكراً لانضمامك لأسرة أكسب. طلبك قيد المراجعة حالياً، وسنقوم بتفعيل حسابك خلال 24 ساعة كحد أقصى."
                : "أهلاً بك في أكسب! حسابك جاهز الآن، ابدأ رحلة توفيرك وجمع نقاطك من اليوم.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13.sp, color: Colors.black87),
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2D9E68),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  padding: const EdgeInsets.symmetric(vertical: 15),
                ),
                onPressed: () => Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false),
                child: Text('الذهاب لتسجيل الدخول', style: TextStyle(color: Colors.white, fontSize: 13.sp, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleRegistration() async {
    final phoneValue = _controllers['phone']!.text.trim();
    final pass = _controllers['password']!.text;
    final confirmPass = _controllers['confirmPassword']!.text;

    if (phoneValue.isEmpty || phoneValue.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('❌ يرجى إدخال رقم هاتف صحيح')));
      return;
    }
    
    String smartEmail = "$phoneValue@aksab.com";

    if (pass != confirmPass) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('❌ كلمة المرور غير متطابقة')));
      return;
    }

    setState(() => _isSaving = true);
    try {
      // ✨ تم تمرير ownerName هنا ليصل إلى الـ DataSource ومنه لفايربيز
      await _dataSource.registerClient(
        fullname: _controllers['fullname']!.text,
        ownerName: _controllers['ownerName']!.text, 
        email: smartEmail,
        phone: phoneValue,
        password: pass,
        address: _controllers['address']!.text,
        country: _selectedCountry,
        userType: _selectedUserType,
        location: _location,
        logoUrl: _logoUrl, 
        crUrl: _crUrl,
        tcUrl: _tcUrl,
        merchantName: _controllers['merchantName']!.text,
        businessType: _controllers['businessType']!.text,
        additionalPhone: _controllers['additionalPhone']!.text,
      );

      await FirebaseAuth.instance.signOut();

      if (mounted) {
        _showSuccessDialog();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ خطأ في التسجيل: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBFDFB),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          child: Column(
            children: [
              SizedBox(height: 2.h),
              const _LogoHeader(),
              SizedBox(height: 2.h),
              _buildStepProgress(),
              SizedBox(height: 2.h),
              Expanded(
                child: Container(
                  width: double.infinity,
                  margin: EdgeInsets.symmetric(horizontal: 5.w, vertical: 1.h),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(35),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 25, offset: const Offset(0, 5)),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(35),
                    child: PageView(
                      controller: _pageController,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        ClientSelectionStep(
                          stepNumber: 1,
                          onCountrySelected: (country) {
                            setState(() => _selectedCountry = country);
                            _goToStep(2);
                          },
                          initialCountry: _selectedCountry,
                          initialUserType: _selectedUserType,
                        ),
                        ClientSelectionStep(
                          stepNumber: 2,
                          initialCountry: _selectedCountry,
                          initialUserType: _selectedUserType,
                          onCompleted: _handleSelectionStep,
                          onGoBack: () => _goToStep(1),
                          onCountrySelected: (_) {},
                        ),
                        ClientDetailsStep(
                          controllers: _controllers,
                          selectedUserType: _selectedUserType,
                          isSaving: _isSaving,
                          onUploadComplete: ({required field, required url}) {
                            setState(() {
                              if (field == 'logo') _logoUrl = url;
                              if (field == 'cr') _crUrl = url;
                              if (field == 'tc') _tcUrl = url;
                            });
                          },
                          onLocationChanged: ({required lat, required lng}) {
                            setState(() => _location = {'lat': lat, 'lng': lng});
                          },
                          onRegister: _handleRegistration,
                          onGoBack: () => _goToStep(2),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const _Footer(),
              SizedBox(height: 2.h),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepProgress() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 10.w),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(3, (index) {
          int stepNum = index + 1;
          bool isCompleted = _currentStep > stepNum;
          bool isActive = _currentStep == stepNum;
          return Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 45,
                height: 45,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isActive || isCompleted ? const Color(0xFF2D9E68) : Colors.grey.shade100,
                  border: Border.all(color: isActive ? const Color(0xFF2D9E68) : Colors.transparent, width: 2),
                ),
                child: Center(
                  child: isCompleted
                      ? const Icon(Icons.check_rounded, color: Colors.white, size: 24)
                      : Text('$stepNum',
                          style: TextStyle(
                              fontSize: 14.sp,
                              color: isActive ? Colors.white : Colors.grey,
                              fontWeight: FontWeight.bold)),
                ),
              ),
              if (index < 2)
                AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 12.w,
                    height: 4,
                    color: isCompleted ? const Color(0xFF2D9E68) : Colors.grey.shade100),
            ],
          );
        }),
      ),
    );
  }
}

class _LogoHeader extends StatelessWidget {
  const _LogoHeader();
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Icon(Icons.how_to_reg_rounded, size: 60, color: Color(0xFF2D9E68)),
        SizedBox(height: 1.h),
        Text('انضم إلينا الآن',
            style: TextStyle(
                fontSize: 22.sp, fontWeight: FontWeight.w900, color: const Color(0xFF1A1A1A))),
        SizedBox(height: 0.5.h),
        Text('خطوات بسيطة وتبدأ تجربتك الفريدة مع أكسب',
            style: TextStyle(fontSize: 11.sp, color: Colors.grey.shade600)),
      ],
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer();
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 1.h),
      child: TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: Text.rich(
          TextSpan(
            text: 'لديك حساب بالفعل؟ ',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13.sp),
            children: const [
              TextSpan(
                text: 'تسجيل الدخول',
                style: TextStyle(color: Color(0xFF2D9E68), fontWeight: FontWeight.w900, decoration: TextDecoration.underline),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
