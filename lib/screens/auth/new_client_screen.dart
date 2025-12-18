import 'package:flutter/material.dart';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sizer/sizer.dart';
import 'package:geolocator/geolocator.dart'; // المكتبة مضافة كما ذكرت
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

  // 🟢 وظيفة تحديد الموقع الجغرافي (تم دمجها بناءً على طلبك)
  Future<void> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('❌ يرجى تفعيل خدمات الموقع (GPS) في الهاتف')),
        );
      }
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('❌ تم رفض الوصول للموقع، يرجى السماح به للمتابعة')),
          );
        }
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('❌ إذن الموقع مرفوض نهائياً، يرجى تفعيله من الإعدادات')),
        );
      }
      return;
    }

    try {
      Position position = await Geolocator.getCurrentPosition();
      setState(() {
        _location = {
          'lat': position.latitude,
          'lng': position.longitude,
        };
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ تم تحديد موقعك الجغرافي بنجاح!'), backgroundColor: Color(0xFF2D9E68)),
        );
      }
    } catch (e) {
      print("Error getting location: $e");
    }
  }

  void _goToStep(int step) {
    setState(() => _currentStep = step);
    _pageController.animateToPage(
      step - 1,
      duration: const Duration(milliseconds: 400),
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

  Future<void> _handleRegistration() async {
    // التحقق من وجود الموقع قبل التسجيل (اختياري حسب رغبتك)
    if (_location == null) {
      await _determinePosition();
      if (_location == null) return; // توقف إذا لم يتم جلب الموقع
    }

    setState(() => _isSaving = true);
    try {
      // هنا يتم إرسال البيانات إلى DataSource شاملة الإحداثيات [_location]
      // والمفاتيح المتفق عليها: ownerId و supermarketName [cite: 2025-10-03]
      await _dataSource.registerClient(
        fullname: _controllers['fullname']!.text,
        email: _controllers['email']!.text,
        password: _controllers['password']!.text,
        address: _controllers['address']!.text,
        country: _selectedCountry,
        userType: _selectedUserType,
        location: _location,
        logo: _logoFile,
        // ... بقية البيانات
      );

      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ أثناء التسجيل: $e')),
      );
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
          child: SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
              child: Column(
                children: [
                  const _LogoHeader(),
                  SizedBox(height: 3.h),
                  _buildStepProgress(),
                  SizedBox(height: 4.h),
                  Container(
                    width: double.infinity,
                    constraints: BoxConstraints(minHeight: 55.h, maxHeight: 75.h),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(30),
                      child: PageView(
                        controller: _pageController,
                        physics: const NeverScrollableScrollPhysics(),
                        children: [
                          ClientSelectionStep(
                            stepNumber: 1,
                            onCountrySelected: (country) => _goToStep(2),
                            initialCountry: _selectedCountry,
                            initialUserType: _selectedUserType,
                            onCompleted: ({required String country, required String userType}) {},
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
                            onBusinessTypeChanged: (v) => _businessType = v,
                            onFilePicked: ({required field, required file}) {
                              setState(() {
                                if (field == 'logo') _logoFile = file;
                                if (field == 'cr') _crFile = file;
                                if (field == 'tc') _tcFile = file;
                              });
                            },
                            // ربط تحديد الموقع بـ ClientDetailsStep
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
                  SizedBox(height: 3.h),
                  const _Footer(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStepProgress() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (index) {
        int stepNum = index + 1;
        bool isCompleted = _currentStep > stepNum;
        bool isActive = _currentStep == stepNum;
        return Row(
          children: [
            Container(
              width: 35,
              height: 35,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isActive || isCompleted ? const Color(0xFF2D9E68) : Colors.grey.shade200,
                border: isActive ? Border.all(color: const Color(0xFF2D9E68).withOpacity(0.2), width: 4) : null,
              ),
              child: Center(
                child: isCompleted
                    ? const Icon(Icons.check, color: Colors.white, size: 18)
                    : Text('$stepNum',
                        style: TextStyle(
                            color: isActive ? Colors.white : Colors.grey, fontWeight: FontWeight.bold)),
              ),
            ),
            if (index < 2)
              Container(
                width: 15.w,
                height: 2,
                color: isCompleted ? const Color(0xFF2D9E68) : Colors.grey.shade200,
              ),
          ],
        );
      }),
    );
  }
}

class _LogoHeader extends StatelessWidget {
  const _LogoHeader();
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF2D9E68).withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.person_add_rounded, size: 40, color: const Color(0xFF2D9E68)),
        ),
        const SizedBox(height: 12),
        Text(
          'إنشاء حساب جديد',
          style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold, color: const Color(0xFF1A1A1A)),
        ),
        const SizedBox(height: 4),
        Text(
          'انضم إلى شبكة تجار أكسب في ثوانٍ',
          style: TextStyle(fontSize: 10.sp, color: Colors.grey.shade600),
        ),
      ],
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer();
  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: () => Navigator.of(context).pop(),
      child: Text.rich(
        TextSpan(
          text: 'لديك حساب بالفعل؟ ',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 11.sp),
          children: const [
            TextSpan(
              text: 'تسجيل الدخول',
              style: TextStyle(color: Color(0xFF2D9E68), fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
