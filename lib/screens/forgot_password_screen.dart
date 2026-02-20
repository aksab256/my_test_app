import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:sizer/sizer.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final Color primaryGreen = const Color(0xff28a745);
  
  String _selectedRole = 'consumers'; // القيمة الافتراضية
  bool _isLoading = false;
  bool _isVerified = false; // هل تم التحقق من وجود الرقم؟
  String? _userName; // اسم المستخدم الذي تم العثور عليه

  // الخرائط الخاصة بمجموعات قاعدة البيانات الخاصة بك
  final Map<String, String> _roles = {
    'consumers': 'مستهلك',
    'users': 'تاجر تجزئة',
    'sellers': 'مورد / موردين',
  };

  // دالة التحقق من وجود الرقم في Firestore
  Future<void> _verifyUser() async {
    String phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      _showSnackBar('يرجى إدخال رقم الهاتف أولاً', Colors.orange);
      return;
    }

    setState(() {
      _isLoading = true;
      _isVerified = false;
    });

    try {
      // البحث في المجموعة المختارة عن حقل phone
      var result = await FirebaseFirestore.instance
          .collection(_selectedRole)
          .where('phone', isEqualTo: phone)
          .limit(1)
          .get();

      if (result.docs.isNotEmpty) {
        // إذا وجدنا المستخدم
        setState(() {
          _isVerified = true;
          // جلب الاسم سواء كان fullname أو supermarketName (حسب الصور)
          _userName = result.docs.first.data()['fullname'] ?? 
                      result.docs.first.data()['supermarketName'] ?? 
                      "عميل أكسب";
        });
        _showSnackBar('تم التحقق بنجاح، يمكنك التواصل مع الدعم الآن', Colors.green);
      } else {
        // إذا لم يوجد الرقم
        _showErrorDialog();
      }
    } catch (e) {
      _showSnackBar('حدث خطأ أثناء التحقق: $e', Colors.red);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // تنبيه في حالة عدم وجود الحساب
  void _showErrorDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('عذراً، غير موجود', textAlign: TextAlign.right, style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
        content: Text(
          'هذا الرقم غير مسجل لدينا كـ ${_roles[_selectedRole]}. تأكد من الرقم أو نوع الحساب، أو قم بإنشاء حساب جديد.',
          textAlign: TextAlign.right,
          style: const TextStyle(fontFamily: 'Cairo'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('تعديل البيانات', style: TextStyle(fontFamily: 'Cairo')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: primaryGreen),
            onPressed: () {
              Navigator.pop(context);
              // أضف كود التوجه لصفحة التسجيل هنا
            },
            child: const Text('تسجيل حساب جديد', style: TextStyle(fontFamily: 'Cairo', color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // دالة فتح الواتساب (تعمل فقط بعد التحقق)
  void _contactSupport() async {
    String phone = _phoneController.text.trim();
    String whatsappNumber = "201551445252"; // رقم الدعم الفني
    String message = "مرحباً دعم أكسب، أنا $_userName، مسجل كـ ${_roles[_selectedRole]} برقم: $phone. فقدت كلمة السر وأريد استعادتها.";
    
    String url = "https://wa.me/$whatsappNumber?text=${Uri.encodeComponent(message)}";
    final Uri uri = Uri.parse(url);

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      _showSnackBar('عذراً، لم نتمكن من فتح واتساب', Colors.red);
    }
  }

  void _showSnackBar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg, textAlign: TextAlign.center, style: const TextStyle(fontFamily: 'Cairo')), backgroundColor: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAF9),
      appBar: AppBar(
        title: const Text('استعادة الحساب', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        foregroundColor: Colors.black,
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 5.h),
          child: Column(
            children: [
              const Icon(Icons.shield_outlined, size: 100, color: Color(0xff28a745)),
              SizedBox(height: 3.h),
              Text('التحقق من الهوية', style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
              SizedBox(height: 4.h),

              // اختيار نوع الحساب
              DropdownButtonFormField<String>(
                value: _selectedRole,
                decoration: InputDecoration(
                  labelText: 'نوع الحساب',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                ),
                items: _roles.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value, style: const TextStyle(fontFamily: 'Cairo')))).toList(),
                onChanged: (val) => setState(() {
                  _selectedRole = val!;
                  _isVerified = false; // إعادة التصفير عند تغيير الاختيار
                }),
              ),

              SizedBox(height: 2.h),

              // حقل الهاتف
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                onChanged: (_) => setState(() => _isVerified = false),
                decoration: InputDecoration(
                  hintText: 'رقم الهاتف المسجل',
                  prefixIcon: const Icon(Icons.phone_android, color: Color(0xff28a745)),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                ),
              ),

              SizedBox(height: 4.h),

              // زر التحقق أو زر الواتساب (يتغير حسب الحالة)
              SizedBox(
                width: double.infinity,
                height: 55,
                child: _isLoading 
                  ? const Center(child: CircularProgressIndicator())
                  : _isVerified 
                    ? ElevatedButton.icon(
                        onPressed: _contactSupport,
                        icon: const Icon(Icons.message, color: Colors.white),
                        label: const Text('تواصل مع الدعم الفني الآن', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
                        style: ElevatedButton.styleFrom(backgroundColor: primaryGreen, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                      )
                    : ElevatedButton(
                        onPressed: _verifyUser,
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2C3E50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                        child: const Text('تحقق من وجود الحساب', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
                      ),
              ),
              
              if (_isVerified) ...[
                SizedBox(height: 2.h),
                Text("أهلاً $_userName، تم العثور على حسابك.", style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
              ]
            ],
          ),
        ),
      ),
    );
  }
}
