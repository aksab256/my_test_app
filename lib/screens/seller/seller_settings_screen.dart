// lib/screens/seller/seller_settings_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; // 🎯 لإدارة بوابة الدخول
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:sizer/sizer.dart';

const Color primaryColor = Color(0xff28a745);
const String CLOUDINARY_URL = "https://api.cloudinary.com/v1_1/dcl96v8p6/image/upload";
const String UPLOAD_PRESET = "aksab_presets";

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
  final _merchantNameController = TextEditingController();
  final _minOrderTotalController = TextEditingController();
  final _deliveryFeeController = TextEditingController();
  final _subUserPhoneController = TextEditingController();

  String _selectedSubUserRole = 'read_only';

  @override
  void initState() {
    super.initState();
    _loadSellerData();
  }

  Future<void> _loadSellerData() async {
    setState(() => _isLoading = true);
    try {
      final doc = await _firestore.collection("sellers").doc(widget.currentSellerId).get();
      if (doc.exists) {
        setState(() {
          sellerDataCache = doc.data()!;
          _merchantNameController.text = sellerDataCache['merchantName'] ?? '';
          _minOrderTotalController.text = (sellerDataCache['minOrderTotal'] ?? 0.0).toString();
          _deliveryFeeController.text = (sellerDataCache['deliveryFee'] ?? 0.0).toString();
        });
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // 🎯 تحديث الحد الأدنى ومصاريف التوصيل
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

  // 🗑️ حذف الموظف من القائمة
  Future<void> _removeSubUser(Map u) async {
    try {
      await _firestore.collection("sellers").doc(widget.currentSellerId).update({
        'subUsers': FieldValue.arrayRemove([u])
      });
      _loadSellerData();
      _showFloatingAlert("🗑️ تم حذف الموظف من القائمة");
    } catch (e) {
      _showFloatingAlert("❌ خطأ أثناء الحذف", isError: true);
    }
  }

  // ➕ إضافة موظف جديد + إنشاء حساب Auth تلقائياً
  Future<void> _addSubUser() async {
    final phone = _subUserPhoneController.text.trim();
    if (phone.isEmpty) {
      _showFloatingAlert("⚠️ يرجى إدخال رقم هاتف الموظف", isError: true);
      return;
    }

    setState(() => _isLoading = true);
    try {
      // 1. 🔑 الخطوة الأهم: إنشاء الإيميل الوهمي والحساب في بوابة الدخول
      String fakeEmail = "$phone@aswaq.com";
      try {
        await _auth.createUserWithEmailAndPassword(
          email: fakeEmail,
          password: "123456", // كلمة المرور الافتراضية
        );
      } catch (authError) {
        // إذا كان الحساب موجوداً مسبقاً لا نتوقف، فقط نحدث بياناته في Firestore
        debugPrint("Auth Error (User might exist): $authError");
      }

      // 2. 📝 إضافة الموظف في Firestore
      final newSub = {
        'phone': phone,
        'role': _selectedSubUserRole,
        'mustChangePassword': true,
        'addedAt': DateTime.now().toIso8601String(),
      };

      await _firestore.collection("sellers").doc(widget.currentSellerId).update({
        'subUsers': FieldValue.arrayUnion([newSub])
      });

      _subUserPhoneController.clear();
      _loadSellerData();
      _showFloatingAlert("✅ تمت إضافة الموظف وتفعيل حسابه.\nكلمة المرور: 123456");
    } catch (e) {
      _showFloatingAlert("❌ فشل في إضافة الموظف: $e", isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showFloatingAlert(String message, {bool isError = false}) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(25),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(isError ? Icons.error_outline : Icons.check_circle_outline,
                   color: isError ? Colors.red : primaryColor, size: 60),
              const SizedBox(height: 20),
              Text(message, textAlign: TextAlign.center,
                   style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.bold, height: 1.5)),
              const SizedBox(height: 25),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isError ? Colors.red : primaryColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12)
                  ),
                  child: const Text("استمرار", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          elevation: 0,
          title: const Text('إعدادات الحساب', style: TextStyle(fontWeight: FontWeight.w900)),
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          centerTitle: true,
        ),
        body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: primaryColor))
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              child: Column(
                children: [
                  _buildLogoHeader(),
                  const SizedBox(height: 30),
                  _buildSectionTitle("بيانات العمل"),
                  _buildModernField("اسم النشاط", _merchantNameController, Icons.storefront),
                  _buildReadOnlyField("نوع النشاط", sellerDataCache['businessType'] ?? 'فلاتر', Icons.category),
                  Row(
                    children: [
                      Expanded(child: _buildModernField("الحد الأدنى للطلب", _minOrderTotalController, Icons.shopping_basket, isNum: true)),
                      const SizedBox(width: 15),
                      Expanded(child: _buildModernField("مصاريف الشحن", _deliveryFeeController, Icons.local_shipping, isNum: true)),
                    ],
                  ),
                  _buildMainButton("حفظ الإعدادات", Icons.check_circle, _updateSettings),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 25),
                    child: Divider(color: Color(0xfff1f1f1)),
                  ),
                  _buildSectionTitle("الموظفين (الصلاحيات)"),
                  _buildModernField("رقم هاتف الموظف", _subUserPhoneController, Icons.phone_android, isNum: true),
                  Container(
                    margin: const EdgeInsets.only(bottom: 15),
                    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xfff8f9fa),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: const Color(0xffe9ecef)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedSubUserRole,
                        isExpanded: true,
                        items: const [
                          DropdownMenuItem(value: 'full', child: Text('صلاحية كاملة (مدير)')),
                          DropdownMenuItem(value: 'read_only', child: Text('صلاحية عرض فقط (موظف)')),
                        ],
                        onChanged: (v) => setState(() => _selectedSubUserRole = v!),
                      ),
                    ),
                  ),
                  _buildMainButton("إضافة موظف", Icons.person_add, _addSubUser, color: Colors.blueGrey[700]!),
                  const SizedBox(height: 25),
                  _buildSubUsersList(),
                  const SizedBox(height: 40),
                ],
              ),
            ),
      ),
    );
  }

  // --- UI Components ---
  Widget _buildModernField(String label, TextEditingController ctrl, IconData icon, {bool isNum = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: TextField(
        controller: ctrl,
        keyboardType: isNum ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
        decoration: InputDecoration(
          labelText: label,
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
      padding: const EdgeInsets.only(bottom: 15),
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
      icon: Icon(icon, color: Colors.white, size: 22),
      label: Text(label, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        minimumSize: const Size(double.infinity, 58),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        elevation: 0,
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Align(
      alignment: Alignment.centerRight,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 15),
        child: Text(title, style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w900, color: Colors.black87)),
      ),
    );
  }

  Widget _buildLogoHeader() {
    return Stack(
      alignment: Alignment.bottomRight,
      children: [
        CircleAvatar(
          radius: 60,
          backgroundColor: const Color(0xfff8f9fa),
          backgroundImage: sellerDataCache['merchantLogoUrl'] != null ? NetworkImage(sellerDataCache['merchantLogoUrl']) : null,
          child: sellerDataCache['merchantLogoUrl'] == null ? const Icon(Icons.store, size: 50, color: Colors.grey) : null,
        ),
        CircleAvatar(
          backgroundColor: primaryColor,
          radius: 18,
          child: IconButton(
            icon: const Icon(Icons.camera_alt, size: 18, color: Colors.white),
            onPressed: _isUploading ? null : _uploadLogo,
          ),
        )
      ],
    );
  }

  Widget _buildSubUsersList() {
    final List users = sellerDataCache['subUsers'] as List? ?? [];
    return Column(
      children: users.map((u) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(color: const Color(0xfff8f9fa), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xffe9ecef))),
        child: ListTile(
          leading: const CircleAvatar(backgroundColor: Colors.blueGrey, child: Icon(Icons.person, color: Colors.white)),
          title: Text(u['phone'], style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text(u['role'] == 'full' ? 'صلاحية كاملة' : 'عرض فقط'),
          trailing: IconButton(icon: const Icon(Icons.delete_outline, color: Colors.redAccent), onPressed: () => _removeSubUser(u)),
        ),
      )).toList(),
    );
  }

  Future<void> _uploadLogo() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 50);
    if (image == null) return;
    setState(() => _isUploading = true);
    try {
      var request = http.MultipartRequest('POST', Uri.parse(CLOUDINARY_URL));
      request.fields['upload_preset'] = UPLOAD_PRESET;
      request.files.add(await http.MultipartFile.fromPath('file', image.path));
      var res = await request.send();
      if (res.statusCode == 200) {
        var responseData = await res.stream.bytesToString();
        var jsonRes = json.decode(responseData);
        await _firestore.collection("sellers").doc(widget.currentSellerId).update({'merchantLogoUrl': jsonRes['secure_url']});
        _loadSellerData();
        _showFloatingAlert("✅ تم تحديث الشعار بنجاح");
      }
    } finally {
      setState(() => _isUploading = false);
    }
  }
}

