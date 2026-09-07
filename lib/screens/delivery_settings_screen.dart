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

  String? _selectedStoreType; 
  
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
  String _ownerPhone = ''; // هاتف المالك الأساسي

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
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (userDoc.exists) {
        final data = userDoc.data()!;
        _supermarketName = data['fullname'] ?? data['name'] ?? 'متجر غير مسمى';
        _supermarketAddress = data['address'] ?? 'العنوان غير مسجل';
        _ownerPhone = data['phone'] ?? ''; // سحب هاتف المالك للضرورة
        _originalLocation = (data['location'] is Map) ? Map<String, dynamic>.from(data['location']) : null;
      }

      final q = await _firestore.collection('pendingSupermarkets').doc(userId).get();
      if (q.exists) {
        final existingData = q.data()!;
        setState(() {
          _isDeliveryActive = true;
          _selectedStoreType = existingData['storeType']; 
          _deliveryHoursController.text = existingData['deliveryHours'] ?? '';
          _whatsappNumberController.text = existingData['whatsappNumber'] ?? '';
          _deliveryPhoneController.text = (existingData['deliveryContactPhone'] == _ownerPhone) ? '' : (existingData['deliveryContactPhone'] ?? '');
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

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(25),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.verified_user_rounded, color: Colors.green, size: 70),
              const SizedBox(height: 15),
              Text("تم إرسال الطلب", style: GoogleFonts.notoSansArabic(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              const Text("بياناتك قيد المراجعة الجغرافية (نطاق 5 كم). سيتم تفعيلك قريباً.", textAlign: TextAlign.center),
              const SizedBox(height: 20),
              const CircularProgressIndicator(strokeWidth: 2, color: Colors.green),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isDeliveryActive && _selectedStoreType == null) {
      _showSnackBar('يرجى اختيار نوع النشاط لتصنيف المحل', isError: true);
      return;
    }

    setState(() => _isSubmitting = true);
    final userId = Provider.of<BuyerDataProvider>(context, listen: false).loggedInUser?.id;

    // الحصول على الأيقونة الموافقة للنوع المختار لضمان تناسق شكل المتجر
    final selectedCat = _storeCategories.firstWhere((c) => c['id'] == _selectedStoreType, orElse: () => {'icon': '🏪'});

    final dataToSave = {
      'ownerId': userId,
      'supermarketName': _supermarketName,
      'storeType': _selectedStoreType,
      'storeIcon': selectedCat['icon'], // حفظ الأيقونة كبديل للصورة لتنسيق الـ UI
      'address': _supermarketAddress,
      'location': _originalLocation,
      'ownerPhone': _ownerPhone, // ضروري للتواصل الإداري
      'deliveryHours': _deliveryHoursController.text,
      'whatsappNumber': _whatsappNumberController.text,
      'deliveryContactPhone': _deliveryPhoneController.text.isEmpty ? _ownerPhone : _deliveryPhoneController.text,
      'deliveryFee': double.tryParse(_deliveryFeeController.text) ?? 0.0,
      'minimumOrderValue': double.tryParse(_minimumOrderValueController.text) ?? 0.0,
      'descriptionForDelivery': _descriptionForDeliveryController.text,
      'status': 'pending',
      'isActive': false,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    try {
      await _firestore.collection('pendingSupermarkets').doc(userId).set(dataToSave, SetOptions(merge: true));
      if (mounted) {
        setState(() => _isSubmitting = false);
        _showSuccessDialog();
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            Navigator.pop(context); // قفل الدايلوج
            Navigator.pop(context); // العودة للهوم
          }
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isSubmitting = false);
      _showSnackBar('خطأ في الاتصال، حاول مرة أخرى');
    }
  }

  // --- دوال بناء الواجهة (نفس المنطق السابق مع تحسينات بسيطة) ---
  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text('تفعيل خدمة الدليفري', style: GoogleFonts.notoSansArabic(fontWeight: FontWeight.bold)),
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
                _buildInfoCard(),
                const SizedBox(height: 20),
                _buildToggleSection(),
                if (_isDeliveryActive) ...[
                  const SizedBox(height: 20),
                  _buildStoreTypeDropdown(),
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
      decoration: BoxDecoration(color: Colors.blueGrey[50], borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.blueGrey[100]!)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_supermarketName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 19)),
          const SizedBox(height: 5),
          Text("📍 $_supermarketAddress", style: const TextStyle(color: Colors.blueGrey, fontSize: 14)),
          Text("📞 هاتف المالك: $_ownerPhone", style: const TextStyle(color: Colors.blueGrey, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildToggleSection() => SwitchListTile(
    title: const Text("استقبال طلبات توصيل", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
    value: _isDeliveryActive,
    onChanged: (v) => setState(() => _isDeliveryActive = v),
    activeColor: Colors.green,
    secondary: Icon(Icons.local_shipping, color: _isDeliveryActive ? Colors.green : Colors.grey),
  );

  Widget _buildStoreTypeDropdown() => DropdownButtonFormField<String>(
    value: _selectedStoreType,
    decoration: InputDecoration(
      labelText: "نوع النشاط التجاري",
      filled: true, fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    ),
    items: _storeCategories.map((cat) => DropdownMenuItem(value: cat['id'], child: Text("${cat['icon']}  ${cat['title']}"))).toList(),
    onChanged: (val) => setState(() => _selectedStoreType = val),
  );

  Widget _buildDeliveryFields() => Column(
    children: [
      _customField("مواعيد العمل", _deliveryHoursController, Icons.access_time, "مثال: 9ص إلى 12م"),
      _customField("واتساب الطلبات", _whatsappNumberController, Icons.chat, "سيتواصل العميل معك هنا", keyboard: TextInputType.phone),
      _customField("سعر التوصيل", _deliveryFeeController, Icons.delivery_dining, "0.00", keyboard: TextInputType.number),
      _customField("رسالة للمشترين", _descriptionForDeliveryController, Icons.info_outline, "مثال: متاح الدفع عند الاستلام", lines: 2),
    ],
  );

  Widget _customField(String label, TextEditingController controller, IconData icon, String hint, {TextInputType keyboard = TextInputType.text, int lines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(top: 15),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboard,
        maxLines: lines,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          hintText: hint,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Widget _buildSubmitButton() => SizedBox(
    width: double.infinity, height: 60,
    child: ElevatedButton(
      onPressed: _isSubmitting ? null : _submitForm,
      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2c3e50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
      child: _isSubmitting ? const CircularProgressIndicator(color: Colors.white) : const Text("تأكيد وحفظ الإعدادات", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
    ),
  );

  void _showSnackBar(String m, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), backgroundColor: isError ? Colors.red : Colors.green));
  }
}

