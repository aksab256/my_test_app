import 'package:flutter/material.dart';
import 'package:my_test_app/services/akedly_auth_service.dart';
import 'package:my_test_app/services/user_session.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import 'package:provider/provider.dart';
import 'package:my_test_app/providers/buyer_data_provider.dart';
import 'package:my_test_app/screens/buyer/buyer_home_screen.dart';
import 'package:my_test_app/screens/consumer/consumer_home_screen.dart';
import 'package:my_test_app/screens/seller_screen.dart';

class LoginFormWidget extends StatefulWidget {
  const LoginFormWidget({super.key});
  @override
  State<LoginFormWidget> createState() => _LoginFormWidgetState();
}

class _LoginFormWidgetState extends State<LoginFormWidget> {
  final _formKey = GlobalKey<FormState>();
  String _phone = '';
  bool _isLoading = false;
  
  // متغيرات لعرض رسائل الكونسول على الواجهة
  String? _errorMessage;
  String? _debugInfo; 

  final AkedlyAuthService _akedlyService = AkedlyAuthService();
  final Color primaryGreen = const Color(0xff28a745);

  // تحديث حالة الرسائل على الشاشة
  void _updateDebug(String info, {bool isError = false}) {
    setState(() {
      _debugInfo = info;
      if (isError) _errorMessage = info;
    });
    debugPrint(info); // بتطبع في الكونسول برضه للاحتياط
  }

  String _formatPhoneNumber(String phone) {
    String cleaned = phone.trim().replaceAll(RegExp(r'\s+'), '');
    if (cleaned.startsWith('0')) {
      cleaned = '20${cleaned.substring(1)}';
    } else if (!cleaned.startsWith('20') && !cleaned.startsWith('+')) {
      cleaned = '20$cleaned';
    }
    return cleaned;
  }

  Future<void> _submitLogin() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _debugInfo = "جاري بدء عملية التحقق...";
    });

    final String formattedPhone = _formatPhoneNumber(_phone);
    _updateDebug("الرقم بعد التنسيق: $formattedPhone");

    try {
      bool userExists = false;
      String? foundRole;
      final collections = ['consumers', 'users', 'sellers'];

      final String phoneWithZero = _phone.trim().startsWith('0') ? _phone.trim() : '0${_phone.trim()}';
      final String phoneWithoutZero = _phone.trim().startsWith('0') ? _phone.trim().substring(1) : _phone.trim();
      final List<String> searchVariations = [phoneWithZero, phoneWithoutZero, formattedPhone];

      _updateDebug("جاري البحث في Firestore عن: $searchVariations");

      for (var col in collections) {
        var query = await FirebaseFirestore.instance
            .collection(col)
            .where('phoneNumber', whereIn: searchVariations) 
            .limit(1)
            .get();
        
        if (query.docs.isNotEmpty) {
          userExists = true;
          foundRole = col == 'users' ? 'buyer' : (col == 'sellers' ? 'seller' : 'consumer');
          _updateDebug("تم العثور على المستخدم في مجموعة: $col برتبة: $foundRole");
          break;
        }
      }

      if (!userExists) {
        setState(() => _isLoading = false);
        _updateDebug("خطأ: الرقم $phoneWithZero غير مسجل في أي مجموعة.", isError: true);
        return;
      }

      _updateDebug("جاري إرسال OTP لـ Akedly...");
      
      // إرسال الكود عبر Akedly
      String? stepId = await _akedlyService.sendOtp(formattedPhone);
      
      setState(() => _isLoading = false);

      if (stepId != null) {
        _updateDebug("تم إرسال الكود بنجاح. StepId: $stepId");
        _showOtpDialog(stepId, formattedPhone, foundRole!);
      } else {
        _updateDebug("فشل Akedly في الإرسال. تأكد من الـ Pipeline Active والرصيد.", isError: true);
      }

    } catch (e) {
      setState(() => _isLoading = false);
      _updateDebug("حدث استثناء (Exception): ${e.toString()}", isError: true);
    }
  }

  void _showOtpDialog(String stepId, String phone, String role) {
    final TextEditingController otpController = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text("تأكيد الهوية", textAlign: TextAlign.center),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("أدخل الكود المرسل للرقم\n$phone", textAlign: TextAlign.center),
              const SizedBox(height: 20),
              TextField(
                controller: otpController,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                maxLength: 6,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 10),
                decoration: InputDecoration(
                  counterText: "",
                  hintText: "000000",
                  filled: true,
                  fillColor: Colors.grey[100],
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
          actions: [
            Center(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryGreen,
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () async {
                  String code = otpController.text.trim();
                  if (code.length == 6) {
                    Navigator.pop(context);
                    _verifyAndLogin(stepId, code, role);
                  }
                },
                child: const Text("دخول للنظام", style: TextStyle(color: Colors.white)),
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Future<void> _verifyAndLogin(String stepId, String code, String role) async {
    setState(() => _isLoading = true);
    _updateDebug("جاري التحقق من الكود: $code");

    bool isVerified = await _akedlyService.verifyOtp(stepId, code);

    if (isVerified) {
      _updateDebug("تم التحقق بنجاح! جاري تسجيل الدخول...");
      try { await FirebaseAuth.instance.signInAnonymously(); } catch (e) {
        _updateDebug("فشل الـ Anonymous Login: $e");
      }
      
      await UserSession.loadSession(); 

      if (mounted) {
        await Provider.of<BuyerDataProvider>(context, listen: false).initializeData(
          FirebaseAuth.instance.currentUser?.uid,
          UserSession.ownerId,
          UserSession.merchantName ?? "مستخدم أسواق أكسب"
        );
        _updateDebug("تم تحميل بيانات الجلسة والتوجه للرئيسية.");
        _navigateToHome(role);
      }
    } else {
      setState(() => _isLoading = false);
      _updateDebug("كود التحقق خاطئ أو منتهي الصلاحية.", isError: true);
    }
  }

  void _navigateToHome(String role) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: const Text('✅ أهلاً بك في أسواق أكسب'), backgroundColor: primaryGreen),
    );
    String route = SellerScreen.routeName;
    if (role == 'buyer') route = BuyerHomeScreen.routeName;
    else if (role == 'consumer') route = ConsumerHomeScreen.routeName;
    Navigator.of(context).pushNamedAndRemoveUntil(route, (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          _InputGroup(
            icon: Icons.phone_android,
            hintText: 'رقم الهاتف (01xxxxxxxxx)',
            keyboardType: TextInputType.phone,
            validator: (value) => (value == null || value.isEmpty) ? 'يرجى إدخال الرقم' : null,
            onSaved: (value) => _phone = value!,
          ),
          const SizedBox(height: 25),
          _buildSubmitButton(),
          
          // --- منطقة عرض رسايل الكونسول على الواجهة ---
          if (_debugInfo != null)
            Container(
              margin: const EdgeInsets.only(top: 20),
              padding: const EdgeInsets.all(10),
              width: double.infinity,
              decoration: BoxDecoration(
                color: (_errorMessage != null ? Colors.red : Colors.blue).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: (_errorMessage != null ? Colors.red : Colors.blue).withOpacity(0.3)),
              ),
              child: SelectableText(
                "📡 Console Log:\n$_debugInfo",
                style: TextStyle(
                  color: _errorMessage != null ? Colors.red : Colors.blue[900],
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace'
                ),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return Container(
      width: double.infinity,
      height: 55,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        gradient: LinearGradient(colors: [primaryGreen, const Color(0xff1e7e34)]),
      ),
      child: ElevatedButton(
        onPressed: _isLoading ? null : _submitLogin,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        ),
        child: _isLoading
          ? const CircularProgressIndicator(color: Colors.white)
          : const Text('إرسال كود التفعيل', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
      ),
    );
  }
}

class _InputGroup extends StatelessWidget {
  final IconData icon;
  final String hintText;
  final TextInputType keyboardType;
  final FormFieldValidator<String> validator;
  final FormFieldSetter<String> onSaved;

  const _InputGroup({
    required this.icon,
    required this.hintText,
    required this.validator,
    required this.onSaved,
    this.keyboardType = TextInputType.text,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      textAlign: TextAlign.right,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: const Color(0xff28a745)),
        hintText: hintText,
        filled: true,
        fillColor: Colors.grey.shade50,
        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: Colors.grey.shade300)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: Colors.grey.shade200)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: Color(0xff28a745), width: 2)),
      ),
      validator: validator,
      onSaved: onSaved,
    );
  }
}