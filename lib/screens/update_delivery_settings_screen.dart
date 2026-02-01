import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/delivery_settings_provider.dart';
import '../providers/buyer_data_provider.dart'; 
import 'package:flutter/services.dart'; 
import 'subscription_plans_screen.dart'; 

class UpdateDeliverySettingsScreen extends StatelessWidget {
  const UpdateDeliverySettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => DeliverySettingsProvider(
        Provider.of<BuyerDataProvider>(context, listen: false), 
      ),
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false, 
          backgroundColor: const Color(0xFF2c3e50), 
          foregroundColor: Colors.white,
          title: const Text('تحديث إعدادات الدليفري', style: TextStyle(fontSize: 20, fontFamily: 'Cairo')),
          centerTitle: true,
          actions: [
            IconButton(
              onPressed: () => Navigator.of(context).pop(), 
              icon: const Icon(Icons.arrow_forward_ios_rounded), 
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: const UpdateDeliverySettingsForm(),
      ),
    );
  }
}

class UpdateDeliverySettingsForm extends StatefulWidget {
  const UpdateDeliverySettingsForm({super.key});

  @override
  State<UpdateDeliverySettingsForm> createState() => _UpdateDeliverySettingsFormState();
}

class _UpdateDeliverySettingsFormState extends State<UpdateDeliverySettingsForm> {
  final _formKey = GlobalKey<FormState>();

  final _hoursController = TextEditingController();
  final _whatsappController = TextEditingController();
  final _phoneController = TextEditingController();
  final _feeController = TextEditingController();
  final _minOrderController = TextEditingController();
  final _descriptionController = TextEditingController();

  @override
  void dispose() {
    _hoursController.dispose();
    _whatsappController.dispose();
    _phoneController.dispose();
    _feeController.dispose();
    _minOrderController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  // 🔴 الكارت الذكي: تم تصحيح الوصول للحالة عبر الـ dealerProfile
  Widget _buildUpgradeAccountCard(DeliverySettingsProvider provider) {
    // جلب الحالة من البروفايل الموجود في الـ provider
    final String? status = provider.dealerProfile?.subscriptionStatus;
    bool isExpired = status == 'expired';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isExpired 
              ? [const Color(0xFFe74c3c), const Color(0xFFc0392b)] 
              : [const Color(0xFF2c3e50), const Color(0xFF4b6584)], 
          begin: Alignment.centerRight,
          end: Alignment.centerLeft,
        ),
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: isExpired ? Colors.red.withOpacity(0.3) : Colors.black.withOpacity(0.2), 
            blurRadius: 8, 
            offset: const Offset(0, 4)
          )
        ],
      ),
      child: Row(
        children: [
          Icon(
            isExpired ? Icons.warning_amber_rounded : Icons.stars_rounded, 
            color: const Color(0xFFf1c40f), 
            size: 40
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isExpired ? 'متجرك متوقف حالياً!' : 'طور أعمالك مع الباقات المميزة',
                  style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
                ),
                Text(
                  isExpired 
                      ? 'انتهت صلاحية حسابك ومنتجاتك غير ظاهرة. جدد الآن.'
                      : 'ظهور أعلى، إعلانات، ومميزات حصرية لمتجرك.',
                  style: const TextStyle(color: Colors.white70, fontSize: 11, fontFamily: 'Cairo'),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SubscriptionPlansScreen()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: isExpired ? Colors.white : const Color(0xFFf1c40f),
              foregroundColor: isExpired ? const Color(0xFFc0392b) : Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(
              isExpired ? 'تجديد' : 'ترقية', 
              style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo')
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<DeliverySettingsProvider>(context);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!provider.isLoading && provider.settings != null) {
        if (_hoursController.text.isEmpty && provider.deliveryHours.isNotEmpty) {
           _hoursController.text = provider.deliveryHours;
        }
        if (_whatsappController.text.isEmpty && provider.whatsappNumber.isNotEmpty) {
           _whatsappController.text = provider.whatsappNumber;
        }
        if (_phoneController.text.isEmpty && provider.deliveryPhone.isNotEmpty) {
           _phoneController.text = provider.deliveryPhone;
        }
        if (_feeController.text.isEmpty && provider.deliveryFee != '0.00') {
           _feeController.text = provider.deliveryFee;
        }
        if (_minOrderController.text.isEmpty && provider.minimumOrderValue != '0.00') {
           _minOrderController.text = provider.minimumOrderValue;
        }
        if (_descriptionController.text.isEmpty && provider.descriptionForDelivery.isNotEmpty) {
           _descriptionController.text = provider.descriptionForDelivery;
        }
      }
    });

    return Directionality(
      textDirection: TextDirection.rtl,
      child: provider.isLoading 
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  _buildUpgradeAccountCard(provider),

                  Container(
                    padding: const EdgeInsets.all(20.0),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(15.0),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (provider.message != null)
                            Container(
                              padding: const EdgeInsets.all(12),
                              margin: const EdgeInsets.only(bottom: 15),
                              decoration: BoxDecoration(
                                color: provider.isSuccess ? Colors.green.shade100 : Colors.red.shade100,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: provider.isSuccess ? Colors.green.shade400 : Colors.red.shade400),
                              ),
                              child: Text(
                                provider.message!,
                                style: TextStyle(
                                  color: provider.isSuccess ? Colors.green.shade900 : Colors.red.shade900,
                                  fontWeight: FontWeight.w500,
                                  fontFamily: 'Cairo'
                                ),
                              ),
                            ),
                          
                          _buildReadOnlyField(
                            label: 'اسم السوبر ماركت:',
                            value: provider.dealerProfile?.name ?? 'جاري التحميل...',
                          ),
                          _buildReadOnlyField(
                            label: 'عنوان السوبر ماركت:',
                            value: provider.dealerProfile?.address ?? 'جاري التحميل...',
                            isTextArea: true,
                          ),
                          _buildLocationInfo(provider),
                          
                          const Divider(height: 40, thickness: 1, color: Color(0xFFcccccc)),

                          _buildDeliveryToggle(provider),

                          AnimatedOpacity(
                            duration: const Duration(milliseconds: 300),
                            opacity: provider.deliveryActive ? 1.0 : 0.5,
                            child: AbsorbPointer(
                              absorbing: !provider.deliveryActive,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildTextField(label: 'مواعيد العمل/التوصيل:', controller: _hoursController, placeholder: 'مثال: من 9 صباحاً إلى 11 مساءً', required: true),
                                  _buildTextField(label: 'رقم هاتف الواتساب:', controller: _whatsappController, placeholder: 'مثال: 00201XXXXXXXXX', keyboardType: TextInputType.phone, infoText: 'هذا الرقم سيظهر للمستهلكين للتواصل عبر الواتساب.', required: true),
                                  _buildTextField(label: 'رقم هاتف الدليفري:', controller: _phoneController, placeholder: 'مثال: 00201XXXXXXXXX', keyboardType: TextInputType.phone, infoText: 'هذا الرقم سيظهر للمستهلكين لإجراء مكالمات الدليفري.'),
                                  _buildNumberField(label: 'مصاريف التوصيل (بالجنيه المصري):', controller: _feeController, placeholder: 'مثال: 15.00', required: true),
                                  _buildNumberField(label: 'الحد الأدنى للطلب (بالجنيه المصري): (اختياري)', controller: _minOrderController, placeholder: 'مثال: 50.00'),
                                  _buildTextField(label: 'وصف إضافي للسوبر ماركت (يظهر للمستهلك): (اختياري)', controller: _descriptionController, placeholder: 'مثال: نقدم أفضل الخضروات الطازجة والتوصيل السريع.', isTextArea: true),
                                ],
                              ),
                            ),
                          ),
                          
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Padding(
                              padding: const EdgeInsets.only(top: 20.0),
                              child: ElevatedButton(
                                onPressed: () {
                                  // تصحيح الوصول للحالة هنا أيضاً
                                  if (provider.dealerProfile?.subscriptionStatus == 'expired') {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('عذراً، يجب تجديد الاشتراك لتتمكن من حفظ الإعدادات', style: TextStyle(fontFamily: 'Cairo')),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                    return;
                                  }
                                  
                                  if (_formKey.currentState!.validate()) {
                                    _submitForm(context, provider);
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: provider.deliveryActive ? const Color(0xFF4CAF50) : const Color(0xFFdc3545),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                child: Text(
                                  provider.deliveryActive ? 'حفظ التعديلات' : 'إيقاف خدمة الدليفري',
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, fontFamily: 'Cairo'),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  void _submitForm(BuildContext context, DeliverySettingsProvider provider) {
    provider.submitSettings(
      hours: _hoursController.text,
      whatsapp: _whatsappController.text,
      phone: _phoneController.text,
      fee: _feeController.text,
      minOrder: _minOrderController.text,
      description: _descriptionController.text,
    );
  }

  Widget _buildReadOnlyField({required String label, required String value, bool isTextArea = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 16, fontFamily: 'Cairo')),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFFf5f7fa),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFcccccc)),
            ),
            child: Text(
              value,
              style: const TextStyle(fontSize: 16, color: Color(0xFF333333), fontFamily: 'Cairo'),
              maxLines: isTextArea ? null : 1,
              overflow: TextOverflow.visible,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationInfo(DeliverySettingsProvider provider) {
    final locationText = (provider.dealerProfile?.location != null)
        ? 'خط عرض: ${provider.dealerProfile!.location!.lat.toStringAsFixed(6)}, خط طول: ${provider.dealerProfile!.location!.lng.toStringAsFixed(6)}'
        : 'الموقع غير متوفر. يرجى مراجعة ملفك الشخصي.';

    return Container(
      padding: const EdgeInsets.all(10),
      margin: const EdgeInsets.only(top: 15, bottom: 15),
      decoration: BoxDecoration(
        color: const Color(0xFF4CAF50).withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text('موقع متجرك المسجل حاليًا:', style: TextStyle(color: Color(0xFF666666), fontFamily: 'Cairo')),
          const SizedBox(height: 5),
          Text(locationText, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          const SizedBox(height: 5),
          const Text('الموقع غير قابل للتعديل من هذه الصفحة.', style: TextStyle(color: Color(0xFF888888), fontSize: 12, fontFamily: 'Cairo')),
        ],
      ),
    );
  }

  Widget _buildDeliveryToggle(DeliverySettingsProvider provider) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('حالة خدمة الدليفري:', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16, fontFamily: 'Cairo')),
          Switch(
            value: provider.deliveryActive,
            onChanged: (value) => provider.setDeliveryActive(value),
            activeColor: const Color(0xFF4CAF50),
            inactiveThumbColor: const Color(0xFFcccccc),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({required String label, required TextEditingController controller, String? placeholder, TextInputType keyboardType = TextInputType.text, String? infoText, bool isTextArea = false, bool required = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 16, fontFamily: 'Cairo')),
          if (infoText != null) Padding(padding: const EdgeInsets.only(top: 4.0, bottom: 4.0), child: Text(infoText, style: const TextStyle(fontSize: 12, color: Color(0xFF666666), fontFamily: 'Cairo'))),
          const SizedBox(height: 8),
          TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            maxLines: isTextArea ? 3 : 1,
            decoration: InputDecoration(hintText: placeholder, contentPadding: const EdgeInsets.all(12), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), fillColor: const Color(0xFFf5f7fa), filled: true),
            validator: (value) => (required && (value == null || value.isEmpty)) ? 'هذا الحقل مطلوب.' : null,
          ),
        ],
      ),
    );
  }

  Widget _buildNumberField({required String label, required TextEditingController controller, String? placeholder, bool required = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 16, fontFamily: 'Cairo')),
          const SizedBox(height: 8),
          TextFormField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
            decoration: InputDecoration(hintText: placeholder, contentPadding: const EdgeInsets.all(12), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), fillColor: const Color(0xFFf5f7fa), filled: true),
            validator: (value) {
              if (required && (value == null || value.isEmpty)) return 'هذا الحقل مطلوب.';
              if (value != null && value.isNotEmpty && double.tryParse(value) == null) return 'الرجاء إدخال رقم صحيح.';
              return null;
            },
          ),
        ],
      ),
    );
  }
}
