// lib/screens/auth/new_client_screen.dart
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:sizer/sizer.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:my_test_app/services/akedly_auth_service.dart';
import 'package:my_test_app/screens/auth/client_selection_step.dart';
import 'package:my_test_app/screens/auth/client_details_step.dart';

class NewClientScreen extends StatefulWidget {
  const NewClientScreen({super.key});

  @override
  State<NewClientScreen> createState() => _NewClientScreenState();
}

class _NewClientScreenState extends State<NewClientScreen> {
  final PageController _pageController = PageController();
  final AkedlyAuthService _regService = AkedlyAuthService();

  String _selectedCountry = 'egypt';
  String _selectedUserType = '';

  // ✨ الحفاظ على جميع المتحكمات لضمان التوافق مع DataSource
  final Map<String, TextEditingController> _controllers = {
    'fullname': TextEditingController(),
    'ownerName': TextEditingController(),
    'phone': TextEditingController(),
    'password': TextEditingController(), // سيتم توليده تلقائياً
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
          title: Text(
            'تم التسجيل بنجاح!',
            style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.w900, color: const Color(0xFF2D9E68), fontFamily: 'Cairo'),
          ),
          content: Text(
            isSeller
                ? "شكراً لانضمامك لأسرة أسواق أكسب. طلبك قيد المراجعة حالياً، وسنقوم بتفعيل حسابك خلال 24 ساعة كحد أقصى."
                : "أهلاً بك في أسواق أكسب! حسابك جاهز الآن، ابدأ رحلة توفيرك وجمع نقاطك من اليوم.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w600, color: Colors.black87, fontFamily: 'Cairo', height: 1.4),
          ),
          actions: [
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 💬 زر الواتساب للموردين فقط للرقم 01131502688
                if (isSeller) ...[
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF25D366),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () async {
                        const phoneNumber = "201131502688";
                        final message = Uri.encodeComponent("مرحباً أسواق أكسب، قمت بالتسجيل كمورد للتو وأود متابعة تفعيل حسابي.");
                        final whatsappUrl = Uri.parse("https://wa.me/$phoneNumber?text=$message");
                        
                        if (await canLaunchUrl(whatsappUrl)) {
                          await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);
                        }
                      },
                      icon: const Icon(Icons.chat_rounded, color: Colors.white, size: 22),
                      label: Text(
                        'التواصل عبر الواتساب لمتابعة التفعيل',
                        style: TextStyle(color: Colors.white, fontSize: 12.sp, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],

                // 🟢 زر الانتقال لتسجيل الدخول الأساسي
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2D9E68),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      padding: const EdgeInsets.symmetric(vertical: 15),
                    ),
                    onPressed: () => Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false),
                    child: Text(
                      'الذهاب لتسجيل الدخول',
                      style: TextStyle(color: Colors.white, fontSize: 13.sp, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _registerErrorMessage(int status) {
    switch (status) {
      case 400:
        return '❌ رمز التحقق أو البيانات غير صحيحة.';
      case 409:
        return '❌ هذا الرقم مسجل بالفعل. سجّل الدخول.';
      case 410:
        return '❌ انتهت صلاحية الكود. أعد التسجيل.';
      case 429:
        return '❌ محاولات كثيرة. حاول لاحقًا.';
      default:
        return '❌ تعذّر إتمام التسجيل حاليًا.';
    }
  }

  Future<String?> _promptOtpDialog() {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('كود التفعيل', style: TextStyle(fontFamily: 'Cairo'), textAlign: TextAlign.center),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          maxLength: 10,
          textAlign: TextAlign.center,
          decoration: const InputDecoration(hintText: 'أدخل الكود المرسل لهاتفك'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(ctrl.text.trim()),
            child: const Text('تأكيد', style: TextStyle(fontFamily: 'Cairo')),
          ),
        ],
      ),
    );
  }

  Future<void> _handleRegistration() async {
    final phoneValue = _controllers['phone']!.text.trim();
    
    // F3: no client-side passwords - identity is created server-side after OTP proof.
    // F3: no generated passwords anymore.
    // F3: password controllers no longer used for registration.
    // F3: confirm-password controller no longer used for registration.

    if (phoneValue.isEmpty || phoneValue.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('❌ يرجى إدخال رقم هاتف صحيح')));
      return;
    }

    // F3: smart email is assigned server-side; the client sends profile only.

    setState(() => _isSaving = true);
    try {
      // ✅ إرسال البيانات للـ DataSource مع الاحتفاظ بكل الحقول دون اختصار
      // F3: step 1 - backend OTP-proves the unknown phone and binds the role server-side.
      if (_selectedUserType != 'buyer' &&
          _selectedUserType != 'seller' &&
          _selectedUserType != 'consumer') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('❌ يرجى اختيار نوع الحساب أولاً')));
        }
        return;
      }
      final send = await _regService.registerSend(phoneValue, _selectedUserType);
      if (!send.isSuccess) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(send.message ?? '❌ تعذّر بدء التسجيل')));
        }
        return;
      }
      final txID = send.data ?? '';
      if (txID.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('❌ تعذّر بدء التسجيل')));
        }
        return;
      }

      final otp = await _promptOtpDialog();
      if (otp == null || otp.isEmpty) return;

      // F3: step 2 - server verifies OTP then creates the passwordless identity + role doc.
      await _regService.registerVerify(
        transactionReqID: txID,
        otp: otp,
        phoneNumber: phoneValue,
        profile: {
          'fullname': _controllers['fullname']!.text,
          'ownerName': _controllers['ownerName']!.text,
          'address': _controllers['address']!.text,
          'country': _selectedCountry,
          'additionalPhone': _controllers['additionalPhone']!.text,
          'merchantName': _controllers['merchantName']!.text,
          'businessType': _controllers['businessType']!.text,
          'logoUrl': _logoUrl,
          'crUrl': _crUrl,
          'tcUrl': _tcUrl,
          if (_location != null) 'location': _location,
        },
      );


      if (mounted) {
        _showSuccessDialog();
      }
    } on RegisterException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_registerErrorMessage(e.statusCode))));
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
        Text('خطوات بسيطة وتبدأ تجربتك الفريدة مع أسواق أكسب',
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
