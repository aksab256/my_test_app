import 'package:flutter/material.dart';
import 'package:my_test_app/helpers/auth_service.dart';
import 'package:my_test_app/screens/forgot_password_screen.dart';

class LoginFormWidget extends StatefulWidget {
  const LoginFormWidget({super.key});

  @override
  State<LoginFormWidget> createState() => _LoginFormWidgetState();
}

class _LoginFormWidgetState extends State<LoginFormWidget> {
  final _formKey = GlobalKey<FormState>();
  String _email = '';
  String _password = '';
  bool _isLoading = false;
  String? _errorMessage;
  bool _obscurePassword = true; // للتحكم في رؤية كلمة السر
  final AuthService _authService = AuthService();

  Future<void> _submitLogin() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _authService.signInWithEmailAndPassword(_email, _password);
      
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ تم تسجيل الدخول بنجاح!', textAlign: TextAlign.center),
          backgroundColor: Color(0xFF2D9E68),
        ),
      );

      Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
    } on String catch (e) {
      setState(() {
        _errorMessage = (e == 'user-not-found' || e == 'wrong-password') 
            ? 'البريد الإلكتروني أو كلمة المرور غير صحيحة.' 
            : 'حدث خطأ أثناء تسجيل الدخول.';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'حدث خطأ غير متوقع.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // حقل البريد
          _buildTextField(
            hint: 'البريد الإلكتروني',
            icon: Icons.alternate_email_rounded,
            onSaved: (value) => _email = value!,
            validator: (value) => (value == null || !value.contains('@')) ? 'بريد غير صالح' : null,
          ),
          const SizedBox(height: 16),
          
          // حقل كلمة المرور
          _buildTextField(
            hint: 'كلمة المرور',
            icon: Icons.lock_outline_rounded,
            isPassword: true,
            obscureText: _obscurePassword,
            onSaved: (value) => _password = value!,
            toggleVisibility: () => setState(() => _obscurePassword = !_obscurePassword),
            validator: (value) => (value == null || value.length < 6) ? 'كلمة المرور قصيرة جداً' : null,
          ),

          // نسيان كلمة المرور
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const ForgotPasswordScreen()),
              ),
              child: const Text('نسيت كلمة المرور؟', style: TextStyle(color: Colors.grey)),
            ),
          ),
          const SizedBox(height: 10),

          // زر الدخول المطور
          _buildSubmitButton(),

          // عرض الخطأ إن وجد
          if (_errorMessage != null) _buildErrorBox(),
          
          // 💡 ملاحظة: تم حذف رابط "ليس لديك حساب" من هنا لأنه موجود في الـ Footer بالـ LoginScreen
        ],
      ),
    );
  }

  Widget _buildTextField({
    required String hint,
    required IconData icon,
    bool isPassword = false,
    bool obscureText = false,
    VoidCallback? toggleVisibility,
    required FormFieldSetter<String> onSaved,
    required FormFieldValidator<String> validator,
  }) {
    return TextFormField(
      obscureText: obscureText,
      textAlign: TextAlign.right,
      onSaved: onSaved,
      validator: validator,
      decoration: InputDecoration(
        filled: true,
        fillColor: const Color(0xFFF0F4F2), // خلفية هادئة للخانات
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),
        prefixIcon: isPassword 
            ? IconButton(
                icon: Icon(obscureText ? Icons.visibility_off : Icons.visibility, size: 20),
                onPressed: toggleVisibility,
              ) 
            : null,
        suffixIcon: Icon(icon, color: const Color(0xFF2D9E68), size: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF2D9E68), width: 1.5),
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return Container(
      height: 55,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(colors: [Color(0xFF2D9E68), Color(0xFF43B97F)]),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2D9E68).withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _isLoading ? null : _submitLogin,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: _isLoading
            ? const CircularProgressIndicator(color: Colors.white)
            : const Text('دخول', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildErrorBox() {
    return Container(
      margin: const EdgeInsets.only(top: 20),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(12)),
      child: Text('❌ $_errorMessage', textAlign: TextAlign.center, style: TextStyle(color: Colors.red.shade800)),
    );
  }
}
