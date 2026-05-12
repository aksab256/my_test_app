import 'package:flutter/material.dart';
import 'package:my_test_app/services/akedly_auth_service.dart';
import 'package:my_test_app/services/user_session.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
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
  String? _errorMessage;
  
  final AkedlyAuthService _akedlyService = AkedlyAuthService();
  final Color primaryGreen = const Color(0xff28a745);

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
    });

    final String formattedPhone = _formatPhoneNumber(_phone);

    try {
      bool userExists = false;
      String? foundRole;
      final collections = ['consumers', 'users', 'sellers'];

      for (var col in collections) {
        var query = await FirebaseFirestore.instance
            .collection(col)
            .where('phoneNumber', isEqualTo: _phone.trim().startsWith('0') ? _phone.trim() : '0${_phone.trim()}') 
            .limit(1)
            .get();
        
        if (query.docs.isNotEmpty) {
          userExists = true;
          foundRole = col == 'users' ? 'buyer' : (col == 'sellers' ? 'seller' : 'consumer');
          break;
        }
      }

      if (!userExists) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'عذراً، هذا الرقم غير مسجل في منظومة أسواق أكسب.';
        });
        return;
      }

      // إرسال الكود عبر Akedly
      String? stepId = await _akedlyService.sendOtp(formattedPhone);
      setState(() => _isLoading = false);

      if (stepId != null) {
        _showOtpDialog(stepId, formattedPhone, foundRole!);
      } else {
        setState(() => _errorMessage = 'فشل إرسال الكود، يرجى المحاولة لاحقاً.');
      }

    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'حدث خطأ في الاتصال بالخادم.';
      });
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
    bool isVerified = await _akedlyService.verifyOtp(stepId, code);

    if (isVerified) {
      try { await FirebaseAuth.instance.signInAnonymously(); } catch (_) {}
      await UserSession.loadSession(); 

      if (mounted) {
        await Provider.of<BuyerDataProvider>(context, listen: false).initializeData(
          FirebaseAuth.instance.currentUser?.uid,
          UserSession.ownerId,
          UserSession.merchantName ?? "مستخدم أسواق أكسب"
        );
        _sendNotificationDataToAWS().catchError((e) => debugPrint("AWS Error: $e"));
        _navigateToHome(role);
      }
    } else {
      setState(() {
        _isLoading = false;
        _errorMessage = "كود التحقق غير صحيح، حاول مرة أخرى.";
      });
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

  Future<void> _sendNotificationDataToAWS() async {
    try {
      String? token = await FirebaseMessaging.instance.getToken();
      String? uid = FirebaseAuth.instance.currentUser?.uid;
      if (token != null && uid != null) {
        const String apiUrl = "https://5uex7vzy64.execute-api.us-east-1.amazonaws.com/V2/new_nofiction";
        await http.post(Uri.parse(apiUrl),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({"userId": uid, "fcmToken": token, "role": UserSession.role ?? "consumer"}));
      }
    } catch (e) { debugPrint("AWS Error: $e"); }
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
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(top: 15),
              child: Text(_errorMessage!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
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