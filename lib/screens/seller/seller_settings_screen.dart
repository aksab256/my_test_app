// lib/screens/seller/seller_settings_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:sizer/sizer.dart';

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

  Map<String, dynamic> sellerDataCache = {};
  List<Map<String, dynamic>> subUsersList = [];

  final _merchantNameController = TextEditingController();
  final _minOrderTotalController = TextEditingController();
  final _deliveryFeeController = TextEditingController();
  final _subUserPhoneController = TextEditingController();

  String _selectedSubUserRole = 'read_only';

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  Future<void> _refreshData() async {
    setState(() => _isLoading = true);
    await _loadSellerData();
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

  Future<void> _updateSettings() async {
    setState(() => _isLoading = true);
    try {
      await _firestore.collection("sellers").doc(widget.currentSellerId).update({
        'merchantName': _merchantNameController.text.trim(),
        'minOrderTotal': double.tryParse(_minOrderTotalController.text) ?? 0.0,
        'deliveryFee': double.tryParse(_deliveryFeeController.text) ?? 0.0,
      });
      _showFloatingAlert("✅ تم تحديث بيانات العمل بنجاح");
    } catch (e) {
      _showFloatingAlert("❌ فشل التحديث: تأكد من الاتصال بالإنترنت", isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _uploadLogo() async {
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

  // 🎯 دالة حذف الحساب (Soft Delete) استجابةً لمتطلبات جوجل بلاي
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
      // تنفيذ الحذف الناعم في Firestore
      await _firestore.collection("sellers").doc(widget.currentSellerId).update({
        'isDeleted': true,
        'deletedAt': FieldValue.serverTimestamp(),
        'status': 'delete_requested',
      });

      // تسجيل الخروج والعودة للبداية
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
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: primaryColor))
            : SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 2.h),
                child: Column(
                  children: [
                    _buildLogoHeader(logoUrl),
                    SizedBox(height: 4.h),
                    _buildSectionTitle("بيانات العمل"),
                    _buildModernField("اسم النشاط", _merchantNameController, Icons.storefront),
                    _buildReadOnlyField("نوع النشاط", sellerDataCache['businessType'] ?? 'غير محدد', Icons.category),
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
                    _buildMainButton("إضافة موظف جديد", Icons.person_add, _addSubUser, color: Colors.blueGrey[800]!),
                    SizedBox(height: 3.h),
                    _buildSubUsersList(),
                    
                    // 🎯 قسم حذف الحساب (متطلب جوجل بلاي)
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
