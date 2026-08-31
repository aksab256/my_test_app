// lib/widgets/login_form_widget.dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart'; // 👈 لفتح رابط الواتساب
import 'package:my_test_app/services/akedly_auth_service.dart';
import 'package:my_test_app/services/user_session.dart';
import 'package:my_test_app/helpers/auth_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
  bool _isPendingUser = false; // 👈 لمتابعة حالة الانتظار واظهار زر الواتساب

  String? _errorMessage;
  
  final AkedlyAuthService _akedlyService = AkedlyAuthService();
  final AuthService _authService = AuthService();
  final Color primaryGreen = const Color(0xff28a745);

  // 🔴 قائمة أرقام مراجعة جوجل بلاي
  final List<String> _reviewPhones = [
    '01278287168',
    '201278287168',
    '01551445210',
    '201551445210',
    '01021070461',
    '201021070461',
  ];

  // رقم واتساب الدعم الفني
  final String _supportWhatsAppNumber = "201131502688"; 

  void _handleError(String message, {bool isPending = false}) {
    setState(() {
      _errorMessage = message;
      _isPendingUser = isPending;
    });
    debugPrint("System Log Error: $message");
  }

  Future<void> _openWhatsApp() async {
    final Uri whatsappUrl = Uri.parse("https://wa.me/$_supportWhatsAppNumber?text=${Uri.encodeComponent("السلام عليكم، محتاج أتابع حالة تفعيل حسابي على أسواق أكسب لرقم الهاتف: $_phone")}");
    if (await canLaunchUrl(whatsappUrl)) {
      await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);
    }
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
      _isPendingUser = false;
    });

    final String formattedPhone = _formatPhoneNumber(_phone);
    final String cleanInputPhone = _phone.trim();

    try {
      bool userExists = false;
      String? foundRole;
      bool isPendingStatus = false;
      final collections = ['consumers', 'users', 'sellers', 'pendingSellers'];

      final String phoneWithZero = cleanInputPhone.startsWith('0') ? cleanInputPhone : '0$cleanInputPhone';
      final String phoneWithoutZero = cleanInputPhone.startsWith('0') ? cleanInputPhone.substring(1) : cleanInputPhone;
      final List<String> searchVariations = [phoneWithZero, phoneWithoutZero, formattedPhone];

      for (var col in collections) {
        var query = await FirebaseFirestore.instance
            .collection(col)
            .where('phone', whereIn: searchVariations)
            .limit(1)
            .get();
        if (query.docs.isNotEmpty) {
          userExists = true;
          final docData = query.docs.first.data();
          
          if (col == 'pendingSellers' || docData['status'] == 'pending') {
            isPendingStatus = true;
          }

          foundRole = col == 'users' ? 'buyer' : (col == 'sellers' ? 'seller' : col == 'consumers' ? 'consumer' : 'pending');
          break;
        }
      }

      if (!userExists) {
        setState(() => _isLoading = false);
        _handleError("❌ خطأ: الرقم غير مسجل في اسواق.");
        return;
      }

      // 🛑 حظر الإرسال وتوفير الرسايل لو الحساب تحت المراجعة/الانتظار
      if (isPendingStatus || foundRole == 'pending') {
        setState(() => _isLoading = false);
        _handleError("⏳ طلبك قيد المراجعة حالياً من قبل الإدارة. يرجى التواصل معنا للتفعيل.", isPending: true);
        return;
      }

      // 🔴 استثناء مراجعة جوجل: عدم استدعاء Akedly
      if (_reviewPhones.contains(cleanInputPhone) || _reviewPhones.contains(formattedPhone)) {
        setState(() => _isLoading = false);
        _showOtpDialog("TEST_STEP_REVIEW", formattedPhone, foundRole!);
        return;
      }

      final result = await _akedlyService.sendOtpDetailed(formattedPhone);
      setState(() => _isLoading = false);

      if (result.isSuccess) {
        _showOtpDialog(result.data ?? "", formattedPhone, foundRole!);
      } else {
        _handleError("⚠️ فشل إرسال كود التفعيل: ${result.message}");
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _handleError("💥 حدث استثناء أثناء معالجة الطلب.");
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
                  if (otpController.text.trim().length == 6) {
                    Navigator.pop(context);
                    _verifyAndLogin(stepId, otpController.text.trim(), phone);
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

  Future<void> _verifyAndLogin(String stepId, String code, String phone) async {
    setState(() => _isLoading = true);

    bool isVerified = false;
    final String cleanInputPhone = _phone.trim();
    final String formattedPhone = _formatPhoneNumber(_phone);

    if (_reviewPhones.contains(cleanInputPhone) || _reviewPhones.contains(formattedPhone)) {
      isVerified = (code == '123456');
    } else {
      isVerified = await _akedlyService.verifyOtp(stepId, code);
    }

    if (isVerified) {
      try {
        final String cleanPhone = _phone.trim().startsWith('0') ? _phone.trim() : '0${_phone.trim()}';
        final String smartEmail = "$cleanPhone@aksab.com";
        final String generatedPass = "Rabia_$cleanPhone";

        String finalRole = await _authService.signInWithEmailAndPassword(smartEmail, generatedPass);

        if (mounted) {
          await Provider.of<BuyerDataProvider>(context, listen: false).initializeData(
            FirebaseAuth.instance.currentUser?.uid,
            UserSession.ownerId,
            UserSession.merchantName ?? "مستخدم اسواق اكسب"
          );

          _navigateToHome(finalRole);
        }
      } catch (e) {
        setState(() => _isLoading = false);
        _handleError("❌ فشل الدخول: عذراً، لم نتمكن من إتمام العملية.");
      }
    } else {
      setState(() => _isLoading = false);
      _handleError("❌ كود التحقق خاطئ.");
    }
  }

  void _navigateToHome(String role) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: const Text('✅ أهلاً بك في اسواق اكسب'), backgroundColor: primaryGreen),
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
          if (_errorMessage != null)
            Container(
              margin: const EdgeInsets.only(top: 20),
              padding: const EdgeInsets.all(12),
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.withOpacity(0.3), width: 1.5),
              ),
              child: Column(
                children: [
                  Text(
                    _errorMessage!,
                    style: TextStyle(color: Colors.red[900], fontSize: 13, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  if (_isPendingUser) ...[
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: _openWhatsApp,
                      icon: const Icon(Icons.chat, color: Colors.white),
                      label: const Text("تواصل عبر واتساب للتفعيل", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xff25D366),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    )
                  ]
                ],
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
        style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
        child: _isLoading ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3)) : const Text('إرسال كود التفعيل', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
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

  const _InputGroup({required this.icon, required this.hintText, required this.validator, required this.onSaved, this.keyboardType = TextInputType.text});

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