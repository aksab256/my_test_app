// lib/screens/delivery_settings_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:my_test_app/providers/buyer_data_provider.dart'; // لجلب ID واسم التاجر
import 'package:google_fonts/google_fonts.dart'; // للخط

// -----------------------------------------------------------
// 1. تعريف الشاشة كـ StatefulWidget
// -----------------------------------------------------------
class DeliverySettingsScreen extends StatefulWidget {
  static const routeName = '/deliverySettings'; // يمكن استخدام هذا المسار
  const DeliverySettingsScreen({super.key});

  @override
  State<DeliverySettingsScreen> createState() => _DeliverySettingsScreenState();
}

class _DeliverySettingsScreenState extends State<DeliverySettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firestore = FirebaseFirestore.instance;
  // حالة التبديل (المكافئ لـ deliveryToggle)
  bool _isDeliveryActive = false;
  // حالة التحميل
  bool _isLoading = true;
  // حالة الإرسال
  bool _isSubmitting = false;

  // معلومات التاجر الأساسية
  String _supermarketName = '';
  String _supermarketAddress = '';
  Map<String, dynamic>? _originalLocation; // لتخزين location: {lat, lng}
  String _originalPhoneNumber = ''; // لرقم الهاتف المسجل

  // المتحكمات (Controllers) لحقول الإدخال
  final _deliveryHoursController = TextEditingController();
  final _whatsappNumberController = TextEditingController();
  final _deliveryPhoneController = TextEditingController();
  final _deliveryFeeController = TextEditingController();
  final _minimumOrderValueController = TextEditingController();
  final _descriptionForDeliveryController = TextEditingController();

  // -----------------------------------------------------------
  // 2. دالة جلب البيانات الأساسية وإعدادات الدليفري الموجودة (JS Logic)
  // -----------------------------------------------------------
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialData();
    });
  }

  Future<void> _loadInitialData() async {
    final buyerData = Provider.of<BuyerDataProvider>(context, listen: false);
    
    // 🎯 التصحيح 1: تغيير 'user' إلى 'loggedInUser'
    final userId = buyerData.loggedInUser?.id; 

    if (userId == null) {
      // يمكنك توجيه المستخدم لصفحة تسجيل الدخول إذا لم يكن مسجلاً
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الرجاء تسجيل الدخول أولاً.')));
        setState(() => _isLoading = false);
      }
      return;
    }

    try {
      // 1. جلب بيانات التاجر الأساسية (من مجموعة 'users')
      final dealerDocSnap = await _firestore.collection('users').doc(userId).get();

      if (dealerDocSnap.exists) {
        final data = dealerDocSnap.data()!;
        _supermarketName = data['fullname'] ?? data['name'] ?? 'غير معروف';
        _supermarketAddress = data['address'] ?? 'غير متوفر';
        _originalLocation = (data['location'] is Map) ? Map<String, dynamic>.from(data['location']) : null;
        
        // 🎯 التصحيح 2: تغيير 'user' إلى 'loggedInUser'
        _originalPhoneNumber = buyerData.loggedInUser?.phone ?? ''; // افترض أن الرقم موجود في Provider/localStorage
      } else {
        if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('لم يتم العثور على بيانات السوبر ماركت الأساسية.', textDirection: TextDirection.rtl)));
      }

      // 2. جلب بيانات الدليفري الموجودة (من pendingSupermarkets)
      final pendingRequestsRef = _firestore.collection('pendingSupermarkets');
      final q = pendingRequestsRef.where("ownerId", isEqualTo: userId).limit(1);
      final querySnapshot = await q.get();

      if (querySnapshot.docs.isNotEmpty) {
        final existingData = querySnapshot.docs.first.data();

        // ملء الحقول وتفعيل التوجل
        _isDeliveryActive = true;
        _deliveryHoursController.text = existingData['deliveryHours'] ?? '';
        _whatsappNumberController.text = existingData['whatsappNumber'] ?? '';
        final existingPhone = existingData['deliveryContactPhone'] ?? '';
        // المنطق: إذا كان الرقم المسجل هو نفسه رقم التاجر الأصلي، لا تملأ الحقل (لتشجيع استخدام الافتراضي)
        if (existingPhone != _originalPhoneNumber) {
          _deliveryPhoneController.text = existingPhone;
        }
        _deliveryFeeController.text = (existingData['deliveryFee'] ?? 0.0).toString();
        _minimumOrderValueController.text = (existingData['minimumOrderValue'] ?? 0.0).toString();
        _descriptionForDeliveryController.text = existingData['descriptionForDelivery'] ?? '';
      }
    } catch (e) {
      debugPrint("Error loading initial data: $e");
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('حدث خطأ أثناء تحميل البيانات.', textDirection: TextDirection.rtl)));
    } finally {
      if(mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // -----------------------------------------------------------
  // 3. دالة إرسال النموذج (JS Submit Logic)
  // -----------------------------------------------------------
  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    if (_originalLocation == null && _isDeliveryActive) {
      _showSnackBar('موقع السوبر ماركت غير متوفر. يرجى تسجيله أولاً.', isError: true);
      return;
    }

    setState(() => _isSubmitting = true);
    
    // 🎯 التصحيح 3: تغيير 'user' إلى 'loggedInUser'
    final userId = Provider.of<BuyerDataProvider>(context, listen: false).loggedInUser?.id; 
    
    if (userId == null) {
      _showSnackBar('خطأ في بيانات المستخدم.', isError: true);
      setState(() => _isSubmitting = false);
      return;
    }

    // هنا يتم معالجة حالة الإلغاء/الإيقاف
    if (!_isDeliveryActive) {
      // بما أن إلغاء التفعيل يتم معالجته بواسطة الأدمن في JS، هنا نكتفي بالتنبيه والرجوع
      _showSnackBar('تم تحديث الإعدادات بنجاح. سيتم إيقاف خدمة الدليفري إذا كانت مفعّلة بالفعل.', isError: false);
      await Future.delayed(const Duration(seconds: 2));
      if(mounted) Navigator.of(context).pop();
      return;
    }

    // تجهيز البيانات للإرسال
    final deliveryPhone = _deliveryPhoneController.text.isEmpty
        ? _originalPhoneNumber
        : _deliveryPhoneController.text;
    final dataToSave = {
      'ownerId': userId,
      'supermarketName': _supermarketName,
      'address': _supermarketAddress,
      'location': _originalLocation,
      'deliveryHours': _deliveryHoursController.text,
      'whatsappNumber': _whatsappNumberController.text,
      'deliveryContactPhone': deliveryPhone,
      // التحويل لـ double (مكافئ parseFloat)
      'deliveryFee': double.tryParse(_deliveryFeeController.text) ?? 0.0,
      'minimumOrderValue': double.tryParse(_minimumOrderValueController.text) ?? 0.0,
      'descriptionForDelivery': _descriptionForDeliveryController.text,
      'status': 'pending',
      'requestDate': FieldValue.serverTimestamp(), // استخدم FieldValue.serverTimestamp()
    };

    try {
      final pendingRequestsRef = _firestore.collection('pendingSupermarkets');
      final q = pendingRequestsRef.where("ownerId", isEqualTo: userId).limit(1);
      final querySnapshot = await q.get();

      if (querySnapshot.docs.isNotEmpty) {
        // طلب موجود، قم بتحديثه (updateDoc)
        final docToUpdate = querySnapshot.docs.first.reference;
        await docToUpdate.update(dataToSave);
        _showSnackBar('تم تحديث طلب تفعيل الدليفري الخاص بكم. جاري المراجعة.', isError: false);
      } else {
        // لا يوجد طلب معلق، قم بإنشاء طلب جديد (setDoc باستخدام ownerId كـ ID)
        await pendingRequestsRef.doc(userId).set(dataToSave);
        _showSnackBar('تم إرسال طلب تفعيل الدليفري الخاص بكم بنجاح! جاري المراجعة.', isError: false);
      }

      await Future.delayed(const Duration(seconds: 3));
      if(mounted) Navigator.of(context).pop();
    } catch (e) {
      debugPrint("Error submitting delivery request: $e");
      _showSnackBar('حدث خطأ أثناء إرسال طلبك. يرجى المحاولة لاحقاً.', isError: true);
    } finally {
      if(mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, textDirection: TextDirection.rtl),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  @override
  void dispose() {
    _deliveryHoursController.dispose();
    _whatsappNumberController.dispose();
    _deliveryPhoneController.dispose();
    _deliveryFeeController.dispose();
    _minimumOrderValueController.dispose();
    _descriptionForDeliveryController.dispose();
    super.dispose();
  }

  // -----------------------------------------------------------
  // 4. بناء الواجهة (UI - مطابق لـ HTML)
  // -----------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    // 💡 يمكن استخدام متغيرات الثيم هنا لمحاكاة الـ CSS
    final primaryColor = Theme.of(context).colorScheme.primary;

    if (_isLoading) {
      return const Scaffold(
        appBar: DeliverySettingsAppBar(title: 'إعدادات خدمة الدليفري'),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: const DeliverySettingsAppBar(title: 'إعدادات خدمة الدليفري'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: Container(
            width: double.infinity,
            constraints: const BoxConstraints(maxWidth: 600),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context).shadowColor.withOpacity(0.1),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // اسم وعنوان السوبر ماركت (Readonly)
                  _buildReadOnlyInput(label: 'اسم السوبر ماركت:', value: _supermarketName),
                  _buildReadOnlyTextArea(label: 'عنوان السوبر ماركت:', value: _supermarketAddress),

                  // معلومات الموقع
                  Container(
                    padding: const EdgeInsets.all(10),
                    margin: const EdgeInsets.only(top: 15, bottom: 20),
                    decoration: BoxDecoration(
                      color: primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        Text('موقع متجرك المسجل حاليًا:', style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color)),
                        const SizedBox(height: 5),
                        Text(
                          _originalLocation != null
                              ? 'خط عرض: ${_originalLocation!['lat']?.toStringAsFixed(6)}, خط طول: ${_originalLocation!['lng']?.toStringAsFixed(6)}'
                              : 'الموقع غير متوفر. يرجى التأكد من تسجيله.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                        const Padding(
                          padding: EdgeInsets.only(top: 5.0),
                          child: Text(
                            'نعتمد على الموقع الذي سجلته عند إنشاء حسابك. لضمان دقة التوصيل، تأكد من صحته.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ),
                      ],
                    ),
                  ),

                  Divider(height: 40, color: Theme.of(context).dividerColor),

                  // تبديل خدمة الدليفري (Toggle Switch)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('تفعيل خدمة الدليفري:', style: TextStyle(fontWeight: FontWeight.w500)),
                      Switch(
                        value: _isDeliveryActive,
                        onChanged: (val) {
                          setState(() {
                            _isDeliveryActive = val;
                          });
                        },
                        activeColor: primaryColor,
                      ),
                    ],
                  ),
                  
                  // حقول الدليفري
                  AnimatedOpacity(
                    opacity: _isDeliveryActive ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 300),
                    child: Visibility(
                      visible: _isDeliveryActive,
                      child: Column(
                        children: [
                          const SizedBox(height: 20),
                          _buildTextInput(
                            label: 'مواعيد العمل/التوصيل:',
                            controller: _deliveryHoursController,
                            hint: 'مثال: من 9 صباحاً إلى 11 مساءً',
                          ),
                          _buildTextInput(
                            label: 'رقم هاتف الواتساب:',
                            controller: _whatsappNumberController,
                            hint: 'مثال: 00201XXXXXXXXX',
                            keyboardType: TextInputType.phone,
                            smallText: 'هذا الرقم سيظهر للمستهلكين للتواصل عبر الواتساب.',
                          ),
                          _buildTextInput(
                            label: 'رقم هاتف الدليفري:',
                            controller: _deliveryPhoneController,
                            hint: 'مثال: 00201XXXXXXXXX',
                            keyboardType: TextInputType.phone,
                            smallText: 'هذا الرقم سيظهر للمستهلكين لإجراء مكالمات الدليفري. اتركه فارغاً لاستخدام رقم حسابك المسجل (${_originalPhoneNumber.isEmpty ? 'غير متوفر' : _originalPhoneNumber.substring(_originalPhoneNumber.length - 4)}).',
                          ),
                          _buildNumberInput(
                            label: 'مصاريف التوصيل (بالجنيه المصري):',
                            controller: _deliveryFeeController,
                            hint: 'مثال: 15.00',
                          ),
                          _buildNumberInput(
                            label: 'الحد الأدنى للطلب (بالجنيه المصري): (اختياري)',
                            controller: _minimumOrderValueController,
                            hint: 'مثال: 50.00',
                          ),
                          _buildTextAreaInput(
                            label: 'وصف إضافي للسوبر ماركت (يظهر للمستهلك): (اختياري)',
                            controller: _descriptionForDeliveryController,
                            hint: 'مثال: نقدم أفضل الخضروات الطازجة والتوصيل السريع.',
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),
                  // زر الإرسال
                  Align(
                    alignment: Alignment.centerLeft, // Alignment.centerLeft في Flutter للـ RTL هو الأفضل
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _submitForm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        textStyle: GoogleFonts.tajawal(fontSize: 18, fontWeight: FontWeight.w600),
                      ),
                      child: _isSubmitting
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(_isDeliveryActive ? 'إرسال/تحديث طلب تفعيل الدليفري' : 'إلغاء تفعيل الدليفري'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ويدجت مساعدة لبناء حقول الإدخال
  Widget _buildTextInput({
    required String label,
    required TextEditingController controller,
    String? hint,
    TextInputType keyboardType = TextInputType.text,
    String? smallText,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            textAlign: TextAlign.right,
            decoration: InputDecoration(
              hintText: hint,
              contentPadding: const EdgeInsets.all(12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              fillColor: Theme.of(context).scaffoldBackgroundColor,
              filled: true,
            ),
          ),
          if (smallText != null)
            Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Text(smallText, style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ),
        ],
      ),
    );
  }

  Widget _buildNumberInput({
    required String label,
    required TextEditingController controller,
    String? hint,
  }) {
    return _buildTextInput(
      label: label,
      controller: controller,
      hint: hint,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
    );
  }

  Widget _buildTextAreaInput({
    required String label,
    required TextEditingController controller,
    String? hint,
  }) {
    return _buildTextInput(
      label: label,
      controller: controller,
      hint: hint,
      keyboardType: TextInputType.multiline,
      smallText: 'يظهر هذا الوصف للمستهلك.',
    );
  }

  Widget _buildReadOnlyInput({required String label, required String value}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          TextFormField(
            initialValue: value,
            readOnly: true,
            style: const TextStyle(fontWeight: FontWeight.bold),
            textAlign: TextAlign.right,
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.all(12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              fillColor: Theme.of(context).scaffoldBackgroundColor,
              filled: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReadOnlyTextArea({required String label, required String value}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          TextFormField(
            initialValue: value,
            readOnly: true,
            minLines: 2,
            maxLines: 3,
            style: const TextStyle(fontWeight: FontWeight.bold),
            textAlign: TextAlign.right,
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.all(12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              fillColor: Theme.of(context).scaffoldBackgroundColor,
              filled: true,
            ),
          ),
        ],
      ),
    );
  }
}

// ويدجت مخصص للـ AppBar لمحاكاة الـ Header في HTML
class DeliverySettingsAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  const DeliverySettingsAppBar({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(title),
      centerTitle: true,
      backgroundColor: Theme.of(context).colorScheme.primary, // يمكنك تخصيص gradient هنا إذا أردت
      foregroundColor: Colors.white,
      automaticallyImplyLeading: false,
      leading: IconButton(
        icon: const Icon(Icons.arrow_forward), // سهم للخلف في RTL
        onPressed: () => Navigator.of(context).pop(), // زر العودة
      ),
      // بما أن الـ Header في HTML به 3 عناصر، يمكن إضافة عنصر فارغ هنا للحفاظ على التوازن
      actions: [Container(width: 48)],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
