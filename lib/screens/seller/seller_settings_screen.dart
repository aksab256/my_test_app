// lib/screens/seller/seller_settings_screen.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';
import 'package:sizer/sizer.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:my_test_app/utils/seller_link_code_state.dart';
import 'package:my_test_app/utils/rabia_webhook_setup.dart';
import 'package:my_test_app/utils/whatsapp_consent_state.dart';

// 🎯 الألوان والثوابت المعتمدة
const Color primaryColor = Color(0xff28a745);

// 🎯 معرفات كلوديناري النهائية
const String CLOUDINARY_URL = "https://api.cloudinary.com/v1_1/dgmmx6jbu/image/upload";
const String UPLOAD_PRESET = "commerce"; 

class SellerSettingsScreen extends StatefulWidget {
  final String currentSellerId;
  const SellerSettingsScreen({super.key, required this.currentSellerId});

  @override
  State<SellerSettingsScreen> createState() => _SellerSettingsScreenState();
}

class _SellerSettingsScreenState extends State<SellerSettingsScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  bool _isLoading = true;
  bool _isUploading = false;
  bool _isCodeObscured = true; // التحكم في إخفاء/إظهار كود Rabia ERP
  bool _isDashboardCodeObscured = true; // التحكم في إخفاء/إظهار كود اللوحة

  // 🔔 حالة Webhook طلبات Rabia — إضافة مستقلة بجوار كود الربط، لا تمس مسار RABIA-xxx.
  bool _webhookStatusLoaded = false;
  bool _webhookChecking = false;
  bool _webhookCreating = false;
  bool _webhookActive = false;
  String? _webhookId;
  String? _webhookSecretOnce; // يُعرض مرة واحدة فقط ثم يُمسح من الذاكرة ولا يُعاد عرضه.
  String? _webhookError;

  // 🔔 إشعارات الطلبات عبر واتساب — مسودة محلية + حقيقة الخادم.
  // لا تُعرض كـ«مفعّلة» إلا بعد حفظ موثوق في sellers/{id} (isWhatsappActive).
  final _whatsappNumberController = TextEditingController();
  bool _whatsappOptInDraft = false;
  bool _whatsappSaving = false;

  Map<String, dynamic> sellerDataCache = {};
  List<Map<String, dynamic>> subUsersList = [];

  final _merchantNameController = TextEditingController();
  final _minOrderTotalController = TextEditingController();
  final _deliveryFeeController = TextEditingController();
  final _subUserPhoneController = TextEditingController();

  String _selectedSubUserRole = 'read_only';
  
  // الحقل الجديد لـ "مدة التوصيل"
  String? _selectedDeliveryDuration; 
  final List<String> _deliveryOptions = [
    '24 ساعة',
    '48 ساعة',
    '72 ساعة',
    'أسبوع',
  ];

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  Future<void> _refreshData() async {
    setState(() => _isLoading = true);
    await _loadSellerData();
    await _loadRabiaWebhookStatus();
    await _loadSubUsersFromCollection();
    setState(() => _isLoading = false);
  }

  Future<void> _loadSellerData() async {
    try {
      final doc = await _firestore.collection("sellers").doc(widget.currentSellerId).get();
      if (doc.exists) {
        sellerDataCache = doc.data()!;
        _merchantNameController.text = sellerDataCache['merchantName'] ?? '';
        _minOrderTotalController.text = (sellerDataCache['minOrderTotal'] ?? 0.0).toString();
        _deliveryFeeController.text = (sellerDataCache['deliveryFee'] ?? 0.0).toString();
        _whatsappNumberController.text = (sellerDataCache['whatsappNumber'] is String) ? sellerDataCache['whatsappNumber'] as String : '';
        _whatsappOptInDraft = sellerDataCache['whatsappOptIn'] == true;
        
        // جلب قيمة مدة التوصيل بأمان
        if (sellerDataCache.containsKey('deliveryDuration')) {
          String? val = sellerDataCache['deliveryDuration'];
          if (_deliveryOptions.contains(val)) {
            _selectedDeliveryDuration = val;
          }
        }
      }
    } catch (e) {
      debugPrint("Error loading seller data: $e");
    }
  }

  Future<void> _loadSubUsersFromCollection() async {
    try {
      final snapshot = await _firestore
          .collection("subUsers")
          .where("parentSellerId", isEqualTo: widget.currentSellerId)
          .get();
      setState(() {
        subUsersList = snapshot.docs.map((doc) => doc.data()).toList();
      });
    } catch (e) {
      debugPrint("Error loading sub-users: $e");
    }
  }

  // 🔑 دالة توليد أو إعادة عرض كود لوحة التحكم الخاص بالدخول
  Future<void> _generateDashboardOtp() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final int? expiresAt = sellerDataCache['dashboard_otp_expires'];
    final String? currentOtp = sellerDataCache['dashboard_otp'];

    // إذا كان الكود الحالي ما زال فعالاً ولم ينتهِ، يعرض نفس الكود ويمنع التكرار العشوائي
    if (currentOtp != null && currentOtp.isNotEmpty && expiresAt != null && now < expiresAt) {
      _showFloatingAlert("🔑 رمز الدخول النشط حالياً:\n$currentOtp\nما زال صالحاً للاستخدام.");
      return;
    }

    // توليد كود جديد من 6 أرقام وصالح لمدة 10 دقائق
    String newOtp = (100000 + Random().nextInt(900000)).toString();
    int newExpiresAt = DateTime.now().add(const Duration(minutes: 10)).millisecondsSinceEpoch;

    setState(() => _isLoading = true);
    try {
      await _firestore.collection("sellers").doc(widget.currentSellerId).update({
        'dashboard_otp': newOtp,
        'dashboard_otp_expires': newExpiresAt,
      });

      await _refreshData();
      _showFloatingAlert("✅ تم إنتاج رمز دخول اللوحة بنجاح:\n$newOtp\nالرمز صالح لمدة 10 دقائق.");
    } catch (e) {
      _showFloatingAlert("❌ فشل إنشاء رمز اللوحة: تأكد من الاتصال بالإنترنت", isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateSettings() async {
    setState(() => _isLoading = true);
    try {
      await _firestore.collection("sellers").doc(widget.currentSellerId).update({
        'merchantName': _merchantNameController.text.trim(),
        'minOrderTotal': double.tryParse(_minOrderTotalController.text) ?? 0.0,
        'deliveryFee': double.tryParse(_deliveryFeeController.text) ?? 0.0,
        'deliveryDuration': _selectedDeliveryDuration, // تحديث الحقل الجديد
      });
      _showFloatingAlert("✅ تم تحديث بيانات العمل بنجاح");
    } catch (e) {
      _showFloatingAlert("❌ فشل التحديث: تأكد من الاتصال بالإنترنت", isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveWhatsappPrefs() async {
    final String? normalized = normalizeWhatsappNumber(_whatsappNumberController.text);
    if (_whatsappOptInDraft && normalized == null) {
      _showFloatingAlert('⚠️ أدخل رقم واتساب صحيحًا مع كود الدولة أولًا', isError: true);
      return;
    }
    if (_whatsappSaving) return;
    setState(() => _whatsappSaving = true);
    try {
      final Map<String, Object?> updates = <String, Object?>{
        'whatsappNumber': normalized ?? _whatsappNumberController.text.trim(),
        'whatsappOptIn': _whatsappOptInDraft,
      };
      if (_whatsappOptInDraft) {
        updates['whatsappOptInAt'] = FieldValue.serverTimestamp();
      }
      await _firestore.collection('sellers').doc(widget.currentSellerId).update(updates);
      await _loadSellerData();
      _showFloatingAlert(_whatsappOptInDraft ? '✅ تم تفعيل إشعارات الطلبات عبر واتساب' : '✅ تم إيقاف إشعارات الطلبات عبر واتساب');
    } catch (e) {
      _showFloatingAlert('❌ فشل حفظ تفضيلات واتساب', isError: true);
    } finally {
      if (mounted) setState(() => _whatsappSaving = false);
    }
  }

  Future<void> _uploadLogo() async {
    PermissionStatus status = await Permission.photos.status;
    
    if (status.isDenied || status.isPermanentlyDenied || status.isRestricted) {
      final bool? proceed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Icon(Icons.photo_library, color: primaryColor, size: 22.sp),
              SizedBox(width: 8.sp),
              Text("تحديث شعار المتجر", style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 14.sp)),
            ],
          ),
          content: Text(
            "نحتاج للوصول إلى معرض الصور لاختيار شعار متجرك. سيتم عرض الشعار للمستهلكين لتمييز علامتك التجارية وضمان هوية النشاط.",
            style: TextStyle(fontFamily: 'Cairo', fontSize: 12.sp, height: 1.5),
            textAlign: TextAlign.right,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text("إلغاء", style: TextStyle(fontFamily: 'Cairo', fontSize: 12.sp, color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: primaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              onPressed: () => Navigator.pop(context, true),
              child: Text("موافق", style: TextStyle(fontFamily: 'Cairo', fontSize: 12.sp, color: Colors.white)),
            ),
          ],
        ),
      );

      if (proceed != true) return;
    }

    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 50);

    if (image == null) return;
    setState(() => _isUploading = true);
    try {
      var request = http.MultipartRequest('POST', Uri.parse(CLOUDINARY_URL));
      request.fields['upload_preset'] = UPLOAD_PRESET;
      request.fields['folder'] = 'merchant_logos'; 
      request.files.add(await http.MultipartFile.fromPath('file', image.path));

      var res = await request.send();
      if (res.statusCode == 200) {
        var responseData = await res.stream.bytesToString();
        var jsonRes = json.decode(responseData);
        String newUrl = jsonRes['secure_url'];

        await _firestore.collection("sellers").doc(widget.currentSellerId).update({
          'logoUrl': newUrl
        });

        await _refreshData();
        _showFloatingAlert("✅ تم تحديث الشعار بنجاح");
      } else {
        _showFloatingAlert("❌ فشل رفع الصورة (كود الخطأ: ${res.statusCode})", isError: true);
      }
    } catch (e) {
      _showFloatingAlert("❌ حدث خطأ أثناء الرفع: $e", isError: true);
    } finally {
      setState(() => _isUploading = false);
    }
  }

  Future<void> _deleteAccount() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('⚠️ حذف الحساب', textAlign: TextAlign.right, style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
        content: const Text(
          'هل أنت متأكد من رغبتك في حذف حسابك؟ سيتم إخفاء نشاطك التجاري وستفقد الوصول للتطبيق خلال 14 يوماً.',
          textAlign: TextAlign.right,
          style: TextStyle(fontFamily: 'Cairo'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('تأكيد الحذف', style: TextStyle(color: Colors.white, fontFamily: 'Cairo')),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      await _firestore.collection("sellers").doc(widget.currentSellerId).update({
        'isDeleted': true,
        'deletedAt': FieldValue.serverTimestamp(),
        'status': 'delete_requested',
      });

      await _auth.signOut();
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
      }
    } catch (e) {
      _showFloatingAlert("❌ حدث خطأ أثناء معالجة الطلب", isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// F3: creation frozen — shows notice instead. Existing sub-users and
  /// [_addSubUser] are preserved untouched for the later delegation decision.
  void _subUsersFrozenNotice() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('إضافة الموظفين متوقفة مؤقتًا')),
    );
  }

  Future<void> _addSubUser() async {
    final phone = _subUserPhoneController.text.trim();
    if (phone.isEmpty) {
      _showFloatingAlert("⚠️ يرجى إدخال رقم هاتف الموظف", isError: true);
      return;
    }

    setState(() => _isLoading = true);
    try {
      String fakeEmail = "$phone@aksab.com";
      try {
        await _auth.createUserWithEmailAndPassword(email: fakeEmail, password: "123456");
      } catch (_) {}

      final subData = {
        'phone': phone,
        'email': fakeEmail,
        'role': _selectedSubUserRole,
        'parentSellerId': widget.currentSellerId,
        'mustChangePassword': true,
        'addedAt': FieldValue.serverTimestamp(),
        'merchantName': sellerDataCache['merchantName'] ?? 'متجر',
      };

      await _firestore.collection("subUsers").doc(phone).set(subData, SetOptions(merge: true));
      _subUserPhoneController.clear();
      await _refreshData();
      _showFloatingAlert("✅ تمت إضافة الموظف بنجاح.\nكلمة المرور: 123456");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _removeSubUser(String phone) async {
    try {
      await _firestore.collection("subUsers").doc(phone).delete();
      await _refreshData();
      _showFloatingAlert("🗑️ تم حذف الموظف بنجاح");
    } catch (e) {
      _showFloatingAlert("❌ خطأ أثناء الحذف", isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final String? logoUrl = sellerDataCache['logoUrl'];

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          elevation: 0,
          title: Text('إعدادات الحساب', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16.sp)),
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          centerTitle: true,
          actions: [
            IconButton(
              tooltip: "تحديث البيانات",
              icon: const Icon(Icons.refresh_rounded),
              // Re-reads sellers/{currentSellerId} so a code issued from
              // Rabia after this screen was opened becomes visible without
              // restarting the app. Reads own document only.
              onPressed: _refreshData,
            ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: primaryColor))
            : SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 2.h),
                child: Column(
                  children: [
                    _buildLogoHeader(logoUrl),
                    SizedBox(height: 4.h),
                    
                    // 🖥️ كارت طلب كود لوحة التحكم (مستقل)
                    _buildDashboardOtpCard(),
                    SizedBox(height: 2.5.h),

                    // 🔗 كارت عرض كود ربط النظام الخارجي / Rabia ERP (مستقل)
                    _buildIntegrationCodeCard(),
                    SizedBox(height: 2.5.h),

                    // 🔔 كارت Webhook طلبات Rabia (إضافة مستقلة — لا تمس كود الربط RABIA-xxx).
                    _buildRabiaWebhookCard(),
                    SizedBox(height: 2.5.h),
                    _buildWhatsappNotificationsCard(),
                    SizedBox(height: 3.h),

                    _buildSectionTitle("بيانات العمل"),
                    _buildModernField("اسم النشاط", _merchantNameController, Icons.storefront),
                    _buildReadOnlyField("نوع النشاط", sellerDataCache['businessType'] ?? 'غير محدد', Icons.category),
                    
                    // حقل مدة التوصيل الجديد
                    _buildDeliveryDurationDropdown(),

                    Row(
                      children: [
                        Expanded(child: _buildModernField("الحد الأدنى", _minOrderTotalController, Icons.shopping_basket, isNum: true)),
                        SizedBox(width: 3.w),
                        Expanded(child: _buildModernField("التوصيل", _deliveryFeeController, Icons.local_shipping, isNum: true)),
                      ],
                    ),
                    _buildMainButton("حفظ الإعدادات", Icons.check_circle, _updateSettings),
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 3.h),
                      child: const Divider(color: Color(0xfff1f1f1), thickness: 2),
                    ),
                    _buildSectionTitle("الموظفين والصلاحيات"),
                    _buildModernField("رقم هاتف الموظف", _subUserPhoneController, Icons.phone_android, isNum: true),
                    _buildRoleDropdown(),
                    SizedBox(height: 1.h),
                    // F3: sub-user creation FROZEN (business decision pending) — existing data untouched.
                    _buildMainButton("إضافة موظف جديد", Icons.person_add, _subUsersFrozenNotice, color: Colors.blueGrey[800]!),
                    SizedBox(height: 3.h),
                    _buildSubUsersList(),
                    
                    SizedBox(height: 4.h),
                    const Divider(color: Colors.redAccent, thickness: 0.5),
                    TextButton.icon(
                      onPressed: _deleteAccount,
                      icon: const Icon(Icons.delete_forever, color: Colors.redAccent),
                      label: const Text(
                        "حذف حساب التاجر نهائياً",
                        style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
                      ),
                    ),
                    SizedBox(height: 5.h),
                  ],
                ),
              ),
      ),
    );
  }

  // --- المكونات المساعدة (UI Helpers) ---

  // 💻 كارت كود لوحة التحكم الخاص بتسجيل الدخول
  Widget _buildDashboardOtpCard() {
    String rawOtp = sellerDataCache['dashboard_otp'] ?? '';
    int? expiresAt = sellerDataCache['dashboard_otp_expires'];
    bool isExpired = expiresAt == null || DateTime.now().millisecondsSinceEpoch > expiresAt;
    
    bool hasOtp = rawOtp.isNotEmpty && !isExpired;
    String displayOtp = hasOtp 
        ? (_isDashboardCodeObscured ? '*' * rawOtp.length : rawOtp)
        : 'لا يوجد كود نشط';

    return Container(
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: const Color(0xfff0fdf4),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: primaryColor, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.dashboard_customize_outlined, color: primaryColor, size: 20.sp),
              SizedBox(width: 2.w),
              Text(
                "طلب كود لوحة التحكم",
                style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.bold, fontFamily: 'Cairo', color: Colors.black87),
              ),
            ],
          ),
          SizedBox(height: 1.h),
          Text(
            "اضغط للحصول على رمز مؤقت لاستخدامه عند تسجيل الدخول إلى لوحة تحكم المتجر الإلكترونية.",
            style: TextStyle(fontSize: 10.sp, color: Colors.grey[700], fontFamily: 'Cairo', height: 1.4),
          ),
          SizedBox(height: 2.h),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.2.h),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: primaryColor.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    displayOtp,
                    style: TextStyle(
                      fontSize: 16.sp, 
                      fontWeight: FontWeight.bold, 
                      letterSpacing: _isDashboardCodeObscured && hasOtp ? 3 : 1.5, 
                      color: hasOtp ? primaryColor : Colors.grey, 
                      fontFamily: 'Cairo'
                    ),
                  ),
                ),
                if (hasOtp)
                  Row(
                    children: [
                      IconButton(
                        tooltip: _isDashboardCodeObscured ? "إظهار الكود" : "إخفاء الكود",
                        icon: Icon(
                          _isDashboardCodeObscured ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                          color: Colors.blueGrey,
                        ),
                        onPressed: () {
                          setState(() {
                            _isDashboardCodeObscured = !_isDashboardCodeObscured;
                          });
                        },
                      ),
                      IconButton(
                        tooltip: "نسخ الكود",
                        icon: const Icon(Icons.copy_rounded, color: primaryColor),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: rawOtp));
                          _showFloatingAlert("📋 تم نسخ رمز لوحة التحكم إلى الحافظة");
                        },
                      ),
                    ],
                  )
              ],
            ),
          ),
          SizedBox(height: 1.5.h),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _generateDashboardOtp,
              icon: const Icon(Icons.key, color: primaryColor),
              label: Text(
                hasOtp ? "عرض/تجديد كود اللوحة" : "إنشاء كود لوحة التحكم",
                style: const TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: primaryColor, width: 1.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: EdgeInsets.symmetric(vertical: 1.2.h),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIntegrationCodeCard() {
    final SellerLinkCodeView linkView = classifySellerLinkCode(sellerDataCache);
    final String rawCode = linkView.code;
    final bool hasCode = linkView.state == SellerLinkCodeState.available;
    final bool isLinkExpired = linkView.state == SellerLinkCodeState.expired;
    final bool isLinkConsumed = linkView.state == SellerLinkCodeState.linkedConsumed;
    String displayCode = hasCode 
        ? (_isCodeObscured ? '*' * rawCode.length : rawCode)
        : isLinkExpired
            ? 'انتهت صلاحية الكود — اطلب كوداً جديداً من رابية ثم حدّث الصفحة'
            : isLinkConsumed
                ? 'تم الربط بنجاح — لا حاجة لكود جديد'
                : 'غير متوفر';

    return Container(
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: const Color(0xfff8f9fa),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey.withOpacity(0.3), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.qr_code_scanner, color: Colors.blueGrey, size: 20.sp),
              SizedBox(width: 2.w),
              Text(
                "كود الربط مع نظام Rabia ERP",
                style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.bold, fontFamily: 'Cairo', color: Colors.black87),
              ),
            ],
          ),
          SizedBox(height: 1.h),
          Text(
            "اضغط إرسال الكود من رابية، ثم حدّث هذه الصفحة لعرض الكود. الكود صالح لمدة 10 دقائق فقط.",
            style: TextStyle(fontSize: 10.sp, color: Colors.grey[600], fontFamily: 'Cairo', height: 1.4),
          ),
          SizedBox(height: 2.h),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.5.h),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xffe9ecef)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: SelectableText(
                    displayCode,
                    style: TextStyle(
                      fontSize: 16.sp, 
                      fontWeight: FontWeight.bold, 
                      letterSpacing: _isCodeObscured && hasCode ? 3 : 1.5, 
                      color: Colors.blueGrey[800], 
                      fontFamily: 'Cairo'
                    ),
                  ),
                ),
                if (hasCode)
                  Row(
                    children: [
                      IconButton(
                        tooltip: _isCodeObscured ? "إظهار الكود" : "إخفاء الكود",
                        icon: Icon(
                          _isCodeObscured ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                          color: Colors.blueGrey,
                        ),
                        onPressed: () {
                          setState(() {
                            _isCodeObscured = !_isCodeObscured;
                          });
                        },
                      ),
                      IconButton(
                        tooltip: "نسخ الكود",
                        icon: const Icon(Icons.copy_rounded, color: Colors.blueGrey),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: rawCode));
                          _showFloatingAlert("📋 تم نسخ كود الربط إلى الحافظة");
                        },
                      ),
                    ],
                  )
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// ترويسة المصادقة لمنافذ Webhooks الحالية (POST/GET/DELETE) في بوابة
  /// التكاملات — يُعاد استخدامها كما هي دون أي تعديل على الـBackend.
  Future<Map<String, String>?> _webhookAuthHeaders() async {
    try {
      final token = await _auth.currentUser?.getIdToken();
      if (token == null || token.isEmpty) return null;
      return <String, String>{
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      };
    } catch (_) {
      return null;
    }
  }

  /// يحدّث حالة Webhook طلبات Rabia من GET /webhooks (لا يكشف السر أبدًا).
  /// فشل التحديث اللاحق لا يمحو حالة نشطة مثبتة سابقًا.
  Future<void> _loadRabiaWebhookStatus() async {
    if (!mounted) return;
    setState(() {
      _webhookChecking = true;
      if (!_webhookStatusLoaded) _webhookError = null;
    });
    try {
      final headers = await _webhookAuthHeaders();
      if (headers == null) throw Exception('auth');
      final res = await http
          .get(Uri.parse('$kIntegrationsApiBase/webhooks'), headers: headers)
          .timeout(const Duration(seconds: 20));
      if (!mounted) return;
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        final list = (body is Map && body['data'] is List)
            ? (body['data'] as List)
            : const <dynamic>[];
        final match = findRabiaOrdersWebhook(list);
        setState(() {
          _webhookActive = match != null;
          _webhookId = match?['webhookId']?.toString();
          _webhookStatusLoaded = true;
          _webhookError = null;
        });
      } else if (res.statusCode == 401) {
        throw Exception('session');
      } else {
        throw Exception('http_${res.statusCode}');
      }
    } catch (_) {
      if (!mounted) return;
      if (!_webhookStatusLoaded) {
        setState(() {
          _webhookError = 'تعذر التحقق من حالة الـWebhook — تحقق من الاتصال ثم أعد المحاولة.';
        });
      }
    } finally {
      if (mounted) setState(() => _webhookChecking = false);
    }
  }

  /// ينشئ Webhook طلبات Rabia عبر POST /webhooks الحالي، مع حارس منع
  /// التكرار (يتحقق أولًا من عدم وجود إعداد مطابق). السر المعروض لمرة
  /// واحدة لا يُسجَّل في أي سجل — يُحفظ في حالة الشاشة فقط.
  Future<void> _createRabiaWebhook() async {
    if (_webhookCreating) return;
    setState(() {
      _webhookCreating = true;
      _webhookError = null;
    });
    try {
      if (!_webhookStatusLoaded) {
        await _loadRabiaWebhookStatus();
        if (!mounted) return;
      }
      if (_webhookActive) return; // حارس التكرار: الإعداد موجود فعلًا.
      final headers = await _webhookAuthHeaders();
      if (headers == null) throw Exception('auth');
      final res = await http
          .post(
            Uri.parse('$kIntegrationsApiBase/webhooks'),
            headers: headers,
            body: jsonEncode(<String, dynamic>{
              'url': kRabiaOrdersReceiverUrl,
              'events': kRabiaOrdersEvents,
            }),
          )
          .timeout(const Duration(seconds: 20));
      if (!mounted) return;
      if (res.statusCode == 201) {
        final body = jsonDecode(res.body);
        final data = (body is Map && body['data'] is Map)
            ? Map<String, dynamic>.from(body['data'] as Map)
            : <String, dynamic>{};
        final secret = data['secret']?.toString() ?? '';
        if (secret.isEmpty) throw Exception('empty_secret');
        setState(() {
          _webhookSecretOnce = secret;
          _webhookId = data['webhookId']?.toString();
          _webhookActive = true;
          _webhookStatusLoaded = true;
        });
      } else {
        throw Exception('http_${res.statusCode}');
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _webhookError = 'فشل إنشاء الـWebhook — أعد المحاولة.';
      });
    } finally {
      if (mounted) setState(() => _webhookCreating = false);
    }
  }

  /// يحذف الـWebhook الحالي (لإعادة الإنشاء عند ضياع المفتاح). كود الربط
  /// RABIA-xxx لا يتأثر إطلاقًا.
  Future<void> _deleteRabiaWebhook() async {
    final id = _webhookId;
    if (id == null || id.isEmpty || _webhookCreating) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('⚠️ حذف Webhook طلبات Rabia', textAlign: TextAlign.right, style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
        content: const Text(
          'سيتوقف نقل الطلبات الفوري إلى Rabia حتى تنشئ Webhook جديدًا. كود الربط RABIA-xxx لن يتأثر.',
          textAlign: TextAlign.right,
          style: TextStyle(fontFamily: 'Cairo'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('تأكيد الحذف', style: TextStyle(color: Colors.white, fontFamily: 'Cairo')),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    setState(() {
      _webhookCreating = true;
      _webhookError = null;
    });
    try {
      final headers = await _webhookAuthHeaders();
      if (headers == null) throw Exception('auth');
      final res = await http
          .delete(Uri.parse('$kIntegrationsApiBase/webhooks/$id'), headers: headers)
          .timeout(const Duration(seconds: 20));
      if (!mounted) return;
      if (res.statusCode == 200) {
        setState(() {
          _webhookActive = false;
          _webhookId = null;
          _webhookSecretOnce = null;
          _webhookStatusLoaded = true;
        });
        _showFloatingAlert('🗑️ تم حذف الـWebhook — يمكنك إنشاء واحد جديد عند الحاجة.');
      } else {
        throw Exception('http_${res.statusCode}');
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _webhookError = 'فشل حذف الـWebhook — أعد المحاولة.';
      });
    } finally {
      if (mounted) setState(() => _webhookCreating = false);
    }
  }

  Widget _buildRabiaWebhookCard() {
    Widget body;
    if (_webhookSecretOnce != null) {
      final secret = _webhookSecretOnce!;
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.5.h),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xffe9ecef)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: SelectableText(
                    secret,
                    style: TextStyle(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.blueGrey[800],
                      fontFamily: 'Cairo',
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'نسخ المفتاح',
                  icon: const Icon(Icons.copy_rounded, color: Colors.blueGrey),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: secret));
                    _showFloatingAlert('📋 تم نسخ مفتاح الـWebhook إلى الحافظة');
                  },
                ),
              ],
            ),
          ),
          SizedBox(height: 1.h),
          Text(
            '⚠️ انسخ هذا المفتاح الآن والصقه في صفحة تكامل Aksab داخل Rabia — لن يظهر مرة أخرى بعد الإخفاء.',
            style: TextStyle(fontSize: 10.sp, color: Colors.red[700], fontFamily: 'Cairo', height: 1.4),
          ),
          SizedBox(height: 1.h),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => setState(() => _webhookSecretOnce = null),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: primaryColor, width: 1.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: EdgeInsets.symmetric(vertical: 1.2.h),
              ),
              child: const Text(
                'إخفاء المفتاح',
                style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
              ),
            ),
          ),
        ],
      );
    } else if (_webhookCreating || (_webhookChecking && !_webhookStatusLoaded)) {
      body = Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(color: primaryColor, strokeWidth: 2.5),
          ),
          SizedBox(width: 3.w),
          Text(
            _webhookCreating ? 'جارٍ التنفيذ...' : 'جارٍ التحقق من حالة الـWebhook...',
            style: TextStyle(fontSize: 11.sp, color: Colors.grey[600], fontFamily: 'Cairo'),
          ),
        ],
      );
    } else if (_webhookActive) {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle, color: primaryColor),
              SizedBox(width: 2.w),
              Text(
                'الـWebhook نشط — يستقبل Rabia حدثي order.created وorder.status_updated لحظيًا.',
                style: TextStyle(fontSize: 10.sp, color: Colors.grey[700], fontFamily: 'Cairo', height: 1.4),
              ),
            ],
          ),
          if (_webhookError != null) ...[
            SizedBox(height: 1.h),
            Text(
              _webhookError!,
              style: TextStyle(fontSize: 10.sp, color: Colors.red[700], fontFamily: 'Cairo'),
            ),
          ],
          SizedBox(height: 1.5.h),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _webhookCreating ? null : _deleteRabiaWebhook,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.redAccent, width: 1.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: EdgeInsets.symmetric(vertical: 1.2.h),
              ),
              child: const Text(
                'حذف الـWebhook (لإعادة الإنشاء عند ضياع المفتاح)',
                style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
              ),
            ),
          ),
        ],
      );
    } else if (_webhookError != null) {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _webhookError!,
            style: TextStyle(fontSize: 10.sp, color: Colors.red[700], fontFamily: 'Cairo', height: 1.4),
          ),
          SizedBox(height: 1.5.h),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _webhookChecking ? null : _loadRabiaWebhookStatus,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: primaryColor, width: 1.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: EdgeInsets.symmetric(vertical: 1.2.h),
              ),
              child: const Text(
                'إعادة المحاولة',
                style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
              ),
            ),
          ),
        ],
      );
    } else {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'أنشئ Webhook لنقل طلباتك وحالاتها إلى Rabia لحظيًا — يُعرض مفتاح whsec_ مرة واحدة فقط لتلصقه في Rabia.',
            style: TextStyle(fontSize: 10.sp, color: Colors.grey[600], fontFamily: 'Cairo', height: 1.4),
          ),
          SizedBox(height: 1.5.h),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _webhookCreating ? null : _createRabiaWebhook,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: primaryColor, width: 1.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: EdgeInsets.symmetric(vertical: 1.2.h),
              ),
              child: const Text(
                'إنشاء Webhook طلبات Rabia',
                style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
              ),
            ),
          ),
        ],
      );
    }

    return Container(
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: const Color(0xfff8f9fa),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey.withOpacity(0.3), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.webhook, color: Colors.blueGrey, size: 20.sp),
              SizedBox(width: 2.w),
              Text(
                'Webhook طلبات Rabia',
                style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.bold, fontFamily: 'Cairo', color: Colors.black87),
              ),
            ],
          ),
          SizedBox(height: 1.h),
          body,
        ],
      ),
    );
  }

  Widget _buildWhatsappNotificationsCard() {
    final bool serverActive = isWhatsappActive(sellerDataCache);
    final Object? consentAt = sellerDataCache['whatsappOptInAt'];
    String consentLabel = 'لم يتم التفعيل بعد';
    if (consentAt != null) {
      try {
        DateTime? dt;
        if (consentAt is Timestamp) {
          dt = consentAt.toDate();
        }
        if (dt != null) {
          final DateTime local = dt.toLocal();
          consentLabel = 'تاريخ الموافقة: ${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
        }
      } catch (_) {}
    }
    final bool hasUnsavedChanges = (_whatsappOptInDraft != (sellerDataCache['whatsappOptIn'] == true)) ||
        (_whatsappNumberController.text.trim() != ((sellerDataCache['whatsappNumber'] is String) ? (sellerDataCache['whatsappNumber'] as String) : ''));
    return Container(
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: const Color(0xfff0fdf4),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: primaryColor, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.notifications_active_outlined, color: primaryColor, size: 20.sp),
              SizedBox(width: 2.w),
              Text(
                'إشعارات الطلبات عبر واتساب',
                style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.bold, fontFamily: 'Cairo', color: Colors.black87),
              ),
            ],
          ),
          SizedBox(height: 1.h),
          Text(
            'فعّل استقبال إشعارات الطلبات الجديدة من أكسب عبر واتساب، حتى يصلك تنبيه فور وصول طلب جديد إلى متجرك.',
            style: TextStyle(fontSize: 10.sp, color: Colors.grey[700], fontFamily: 'Cairo', height: 1.4),
          ),
          SizedBox(height: 1.5.h),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.h),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: primaryColor.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: serverActive ? primaryColor : Colors.grey,
                    shape: BoxShape.circle,
                  ),
                ),
                SizedBox(width: 2.w),
                Expanded(
                  child: Text(
                    serverActive ? 'الحالة: مفعّلة' : 'الحالة: غير مفعّلة',
                    style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.bold, fontFamily: 'Cairo', color: serverActive ? primaryColor : Colors.grey[700]),
                  ),
                ),
              ],
            ),
          ),
          if (serverActive) ...[
            SizedBox(height: 1.h),
            Text(consentLabel, style: TextStyle(fontSize: 10.sp, color: Colors.grey[600], fontFamily: 'Cairo')),
          ],
          SizedBox(height: 1.5.h),
          _buildModernField('رقم واتساب مع كود الدولة (مثال: +2010...)', _whatsappNumberController, Icons.phone_android),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'استقبال إشعارات الطلبات الجديدة',
                  style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
                ),
              ),
              Switch(
                value: _whatsappOptInDraft,
                activeThumbColor: primaryColor,
                onChanged: (bool v) => setState(() => _whatsappOptInDraft = v),
              ),
            ],
          ),
          Text(
            'أوافق على استقبال إشعارات الطلبات الجديدة المتعلقة بمتجري من أكسب عبر واتساب على الرقم المسجل. يمكنني إيقاف هذه الإشعارات في أي وقت.',
            style: TextStyle(fontSize: 10.sp, color: Colors.grey[700], fontFamily: 'Cairo', height: 1.4),
          ),
          SizedBox(height: 1.h),
          Text(
            'الرسائل مقتصرة على إشعارات الطلبات، وليست رسائل تسويقية.',
            style: TextStyle(fontSize: 10.sp, color: Colors.grey[600], fontFamily: 'Cairo', height: 1.4),
          ),
          if (hasUnsavedChanges) ...[
            SizedBox(height: 1.h),
            Text(
              'لديك تغييرات غير محفوظة — اضغط حفظ لاعتمادها.',
              style: TextStyle(fontSize: 10.sp, color: Colors.orange[800], fontFamily: 'Cairo', fontWeight: FontWeight.bold),
            ),
          ],
          SizedBox(height: 1.5.h),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _whatsappSaving ? null : _saveWhatsappPrefs,
              icon: const Icon(Icons.save_outlined, color: primaryColor),
              label: Text(
                _whatsappSaving ? 'جارٍ الحفظ...' : 'حفظ تفضيلات واتساب',
                style: const TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: primaryColor, width: 1.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: EdgeInsets.symmetric(vertical: 1.2.h),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveryDurationDropdown() {
    return Padding(
      padding: EdgeInsets.only(bottom: 2.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(right: 2.w, bottom: 0.5.h),
            child: Text("مدة التوصيل المتوقعة", style: TextStyle(fontSize: 11.sp, color: Colors.grey[600], fontFamily: 'Cairo')),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 0.5.h),
            decoration: BoxDecoration(
              color: const Color(0xfff8f9fa),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: const Color(0xffe9ecef)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedDeliveryDuration,
                hint: const Text("اختر مدة التوصيل", style: TextStyle(fontFamily: 'Cairo')),
                isExpanded: true,
                icon: const Icon(Icons.timer_outlined, color: primaryColor),
                items: _deliveryOptions.map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value, style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                  );
                }).toList(),
                onChanged: (newValue) {
                  setState(() => _selectedDeliveryDuration = newValue);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogoHeader(String? logoUrl) {
    return Stack(
      alignment: Alignment.bottomRight,
      children: [
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: primaryColor.withOpacity(0.2), width: 4),
          ),
          child: CircleAvatar(
            radius: 65,
            backgroundColor: const Color(0xfff8f9fa),
            backgroundImage: (logoUrl != null && logoUrl.isNotEmpty) ? NetworkImage(logoUrl) : null,
            child: (logoUrl == null || logoUrl.isEmpty) ? Icon(Icons.store, size: 50, color: Colors.grey[400]) : null,
          ),
        ),
        CircleAvatar(
          backgroundColor: primaryColor,
          radius: 20,
          child: _isUploading
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : IconButton(
                  icon: const Icon(Icons.camera_alt, size: 20, color: Colors.white),
                  onPressed: _uploadLogo,
                ),
        )
      ],
    );
  }

  Widget _buildRoleDropdown() {
    return Container(
      margin: EdgeInsets.only(bottom: 2.h),
      padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 0.5.h),
      decoration: BoxDecoration(
        color: const Color(0xfff8f9fa),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xffe9ecef)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedSubUserRole,
          isExpanded: true,
          icon: const Icon(Icons.arrow_drop_down, color: primaryColor),
          items: const [
            DropdownMenuItem(value: 'full', child: Text('صلاحية كاملة (مدير)')),
            DropdownMenuItem(value: 'read_only', child: Text('عرض فقط (موظف)')),
          ],
          onChanged: (v) => setState(() => _selectedSubUserRole = v!),
        ),
      ),
    );
  }

  Widget _buildSubUsersList() {
    if (subUsersList.isEmpty) return const SizedBox();
    return Column(
      children: subUsersList.map((u) => Container(
            margin: EdgeInsets.only(bottom: 1.5.h),
            decoration: BoxDecoration(
                color: const Color(0xfff8f9fa),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: const Color(0xffe9ecef))),
            child: ListTile(
              leading: const CircleAvatar(backgroundColor: Colors.blueGrey, child: Icon(Icons.person, color: Colors.white)),
              title: Text(u['phone'] ?? '', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.sp)),
              subtitle: Text(u['role'] == 'full' ? 'صلاحية كاملة' : 'عرض فقط', style: TextStyle(fontSize: 11.sp)),
              trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                  onPressed: () => _removeSubUser(u['phone'])),
            ),
          )).toList(),
    );
  }

  Widget _buildModernField(String label, TextEditingController ctrl, IconData icon, {bool isNum = false}) {
    return Padding(
      padding: EdgeInsets.only(bottom: 2.h),
      child: TextField(
        controller: ctrl,
        keyboardType: isNum ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.sp),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.grey, fontWeight: FontWeight.normal),
          prefixIcon: Icon(icon, color: primaryColor, size: 20),
          filled: true,
          fillColor: const Color(0xfff8f9fa),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: Color(0xffe9ecef))),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: primaryColor, width: 1.5)),
        ),
      ),
    );
  }

  Widget _buildReadOnlyField(String label, String value, IconData icon) {
    return Padding(
      padding: EdgeInsets.only(bottom: 2.h),
      child: TextField(
        controller: TextEditingController(text: value),
        enabled: false,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: Colors.grey, size: 20),
          filled: true,
          fillColor: const Color(0xfff1f3f5),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
        ),
      ),
    );
  }

  Widget _buildMainButton(String label, IconData icon, VoidCallback onPressed, {Color color = primaryColor}) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, color: Colors.white, size: 20),
      label: Text(label, style: TextStyle(color: Colors.white, fontSize: 14.sp, fontWeight: FontWeight.bold)),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        minimumSize: Size(double.infinity, 7.h),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        elevation: 0,
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Align(
      alignment: Alignment.centerRight,
      child: Padding(
        padding: EdgeInsets.only(bottom: 2.h),
        child: Text(title, style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w900, color: Colors.black87)),
      ),
    );
  }

  void _showFloatingAlert(String message, {bool isError = false}) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: EdgeInsets.all(6.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(isError ? Icons.error_outline : Icons.check_circle_outline, color: isError ? Colors.red : primaryColor, size: 50.sp),
              SizedBox(height: 2.h),
              Text(message, textAlign: TextAlign.center, style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.bold, height: 1.5)),
              SizedBox(height: 3.h),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: isError ? Colors.red : primaryColor,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: EdgeInsets.symmetric(vertical: 1.5.h)),
                  child: const Text("استمرار", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
