// lib/screens/delivery_settings_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:my_test_app/providers/buyer_data_provider.dart';
import 'package:google_fonts/google_fonts.dart';

class DeliverySettingsScreen extends StatefulWidget {
  static const routeName = '/deliverySettings';
  const DeliverySettingsScreen({super.key});

  @override
  State<DeliverySettingsScreen> createState() => _DeliverySettingsScreenState();
}

class _DeliverySettingsScreenState extends State<DeliverySettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firestore = FirebaseFirestore.instance;
  
  bool _isDeliveryActive = false;
  bool _isLoading = true;
  bool _isSubmitting = false;

  // الحقول الجديدة
  String? _selectedStoreType; // لتخزين نوع النشاط
  
  // التصنيفات المقترحة
  final List<Map<String, String>> _storeCategories = [
    {'id': 'supermarket', 'title': 'سوبر ماركت', 'icon': '🛍️'},
    {'id': 'restaurant', 'title': 'مطعم / كافيه', 'icon': '🍔'},
    {'id': 'pharmacy', 'title': 'صيدلية', 'icon': '💊'},
    {'id': 'vegetables', 'title': 'خضروات وفاكهة', 'icon': '🥦'},
    {'id': 'butcher', 'title': 'جزارة / دواجن', 'icon': '🥩'},
    {'id': 'houseware', 'title': 'أدوات منزلية ومنظفات', 'icon': '🧼'},
  ];

  String _supermarketName = '';
  String _supermarketAddress = '';
  Map<String, dynamic>? _originalLocation;
  String _originalPhoneNumber = '';

  final _deliveryHoursController = TextEditingController();
  final _whatsappNumberController = TextEditingController();
  final _deliveryPhoneController = TextEditingController();
  final _deliveryFeeController = TextEditingController();
  final _minimumOrderValueController = TextEditingController();
  final _descriptionForDeliveryController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    final buyerData = Provider.of<BuyerDataProvider>(context, listen: false);
    final userId = buyerData.loggedInUser?.id;

    if (userId == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      // 1. جلب بيانات التاجر الأساسية
      final dealerDocSnap = await _firestore.collection('users').doc(userId).get();
      if (dealerDocSnap.exists) {
        final data = dealerDocSnap.data()!;
        _supermarketName = data['fullname'] ?? data['name'] ?? 'متجر غير مسمى';
        _supermarketAddress = data['address'] ?? 'العنوان غير مسجل';
        _originalLocation = (data['location'] is Map) ? Map<String, dynamic>.from(data['location']) : null;
        _originalPhoneNumber = buyerData.loggedInUser?.phone ?? '';
      }

      // 2. جلب إعدادات الدليفري
      final q = await _firestore.collection('pendingSupermarkets').where("ownerId", isEqualTo: userId).limit(1).get();
      if (q.docs.isNotEmpty) {
        final existingData = q.docs.first.data();
        setState(() {
          _isDeliveryActive = true;
          _selectedStoreType = existingData['storeType']; // تحميل النوع المسجل سابقاً
          _deliveryHoursController.text = existingData['deliveryHours'] ?? '';
          _whatsappNumberController.text = existingData['whatsappNumber'] ?? '';
          _deliveryPhoneController.text = (existingData['deliveryContactPhone'] == _originalPhoneNumber) ? '' : (existingData['deliveryContactPhone'] ?? '');
          _deliveryFeeController.text = (existingData['deliveryFee'] ?? 0.0).toString();
          _minimumOrderValueController.text = (existingData['minimumOrderValue'] ?? 0.0).toString();
          _descriptionForDeliveryController.text = existingData['descriptionForDelivery'] ?? '';
        });
      }
    } catch (e) {
      debugPrint("Error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isDeliveryActive && _selectedStoreType == null) {
      _showSnackBar('يرجى اختيار نوع النشاط أولاً', isError: true);
      return;
    }

    setState(() => _isSubmitting = true);
    final userId = Provider.of<BuyerDataProvider>(context, listen: false).loggedInUser?.id;

    final dataToSave = {
      'ownerId': userId,
      'supermarketName': _supermarketName,
      'storeType': _selectedStoreType, // حفظ نوع النشاط للتصنيف
      'address': _supermarketAddress,
      'location': _originalLocation,
      'deliveryHours': _deliveryHoursController.text,
      'whatsappNumber': _whatsappNumberController.text,
      'deliveryContactPhone': _deliveryPhoneController.text.isEmpty ? _originalPhoneNumber : _deliveryPhoneController.text,
      'deliveryFee': double.tryParse(_deliveryFeeController.text) ?? 0.0,
      'minimumOrderValue': double.tryParse(_minimumOrderValueController.text) ?? 0.0,
      'descriptionForDelivery': _descriptionForDeliveryController.text,
      'status': 'pending',
      'isActive': _isDeliveryActive,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    try {
      await _firestore.collection('pendingSupermarkets').doc(userId).set(dataToSave, SetOptions(merge: true));
      _showSnackBar('تم حفظ الإعدادات بنجاح! جاري المراجعة.', isError: false);
      Future.delayed(const Duration(seconds: 2), () => Navigator.pop(context));
    } catch (e) {
      _showSnackBar('حدث خطأ في الحفظ', isError: true);
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text('إعدادات المتجر والدليفري', style: GoogleFonts.notoSansArabic(fontWeight: FontWeight.w900, fontSize: 20)),
          backgroundColor: const Color(0xFF2c3e50),
          foregroundColor: Colors.white,
          centerTitle: true,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                // كارت معلومات المتجر
                _buildInfoCard(),
                const SizedBox(height: 20),

                // قسم التفعيل
                _buildToggleSection(),
                
                if (_isDeliveryActive) ...[
                  const SizedBox(height: 20),
                  _buildStoreTypeDropdown(), // المنسدلة الجديدة
                  const SizedBox(height: 20),
                  _buildDeliveryFields(),
                ],

                const SizedBox(height: 30),
                _buildSubmitButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.grey[300]!)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_supermarketName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 19)),
          const SizedBox(height: 5),
          Text(_supermarketAddress, style: const TextStyle(color: Colors.grey, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildToggleSection() {
    return SwitchListTile(
      title: const Text("تفعيل استقبال طلبات الدليفري", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
      value: _isDeliveryActive,
      onChanged: (v) => setState(() => _isDeliveryActive = v),
      activeColor: Colors.green,
      secondary: Icon(Icons.delivery_dining, color: _isDeliveryActive ? Colors.green : Colors.grey, size: 30),
    );
  }

  Widget _buildStoreTypeDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("نوع النشاط التجاري:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          value: _selectedStoreType,
          decoration: InputDecoration(
            filled: true, fillColor: Colors.blue.withOpacity(0.05),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.blue[200]!)),
          ),
          hint: const Text("اختر نوع المحل"),
          items: _storeCategories.map((cat) {
            return DropdownMenuItem(
              value: cat['id'],
              child: Text("${cat['icon']}  ${cat['title']}", style: const TextStyle(fontSize: 18)),
            );
          }).toList(),
          onChanged: (val) => setState(() => _selectedStoreType = val),
        ),
      ],
    );
  }

  Widget _buildDeliveryFields() {
    return Column(
      children: [
        _customField("مواعيد التوصيل", _deliveryHoursController, Icons.access_time, "مثال: 10ص - 11م"),
        _customField("رقم الواتساب للطلبات", _whatsappNumberController, Icons.chat, "01XXXXXXXXX", keyboard: TextInputType.phone),
        _customField("سعر التوصيل (جنيه)", _deliveryFeeController, Icons.money, "0.00", keyboard: TextInputType.number),
        _customField("الحد الأدنى للطلب (جنيه)", _minimumOrderValueController, Icons.shopping_cart_checkout, "اختياري", keyboard: TextInputType.number),
        _customField("وصف/رسالة للمشتري", _descriptionForDeliveryController, Icons.description, "مثال: توصيل مجاني للمناطق المجاورة", lines: 2),
      ],
    );
  }

  Widget _customField(String label, TextEditingController controller, IconData icon, String hint, {TextInputType keyboard = TextInputType.text, int lines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboard,
        maxLines: lines,
        style: const TextStyle(fontSize: 18),
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: Color(0xFF2c3e50)),
          hintText: hint,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton(
        onPressed: _isSubmitting ? null : _submitForm,
        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2c3e50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
        child: _isSubmitting ? const CircularProgressIndicator(color: Colors.white) : const Text("حفظ الإعدادات وإرسال للمراجعة", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
      ),
    );
  }

  void _showSnackBar(String m, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), backgroundColor: isError ? Colors.red : Colors.green));
  }
}

