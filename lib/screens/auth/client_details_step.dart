// lib/screens/auth/client_details_step.dart

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart'; // مكتبة OpenStreetMap
import 'package:latlong2/latlong.dart'; // لتحديد الإحداثيات
import 'package:geocoding/geocoding.dart'; // للبحث عن العنوان من الإحداثيات
import 'package:geolocator/geolocator.dart'; // لتحديد الموقع الحالي
import 'package:image_picker/image_picker.dart';
import 'dart:io'; 
import 'package:my_test_app/widgets/form_widgets.dart'; // افترض وجود هذه الويدجت
import 'package:cloud_firestore/cloud_firestore.dart'; // نحتاجها لاستخدام FieldValue

class ClientDetailsStep extends StatefulWidget {
  final Map<String, TextEditingController> controllers;
  final String selectedUserType;
  final bool isSaving;
  final ValueChanged<String?> onBusinessTypeChanged;
  final Function({required double lat, required double lng}) onLocationChanged;
  final Function({required String field, required File file}) onFilePicked;
  final VoidCallback onRegister;
  final VoidCallback onGoBack;

  const ClientDetailsStep({
    super.key,
    required this.controllers,
    required this.selectedUserType,
    required this.isSaving,
    required this.onBusinessTypeChanged,
    required this.onLocationChanged,
    required this.onFilePicked,
    required this.onRegister,
    required this.onGoBack,
  });

  @override
  State<ClientDetailsStep> createState() => _ClientDetailsStepState();
}

class _ClientDetailsStepState extends State<ClientDetailsStep> {
  final _formKey = GlobalKey<FormState>();

  late MapController _mapController;

  LatLng _initialPosition = const LatLng(30.0444, 31.2357); // Cairo default

  File? _logoPreview;
  File? _crPreview;
  File? _tcPreview;

  bool _termsAgreed = false;
  bool _isMapActive = false; // يحدد ما إذا كان overlay تفعيل الموقع مرئياً

  @override
  void initState() {
    super.initState();
    // تهيئة متحكم الخريطة
    _mapController = MapController();
    // إرسال الموقع الافتراضي
    widget.onLocationChanged(lat: _initialPosition.latitude, lng: _initialPosition.longitude);
  }

  // 1. وظيفة تحديث العنوان من الإحداثيات (Geocoding) - تستخدم مكتبة geocoding
  Future<void> _updateAddress(LatLng position) async {
    try {
      final placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        final address = [place.street, place.subLocality, place.locality, place.country].where((e) => e != null && e.isNotEmpty).join(', ');
        widget.controllers['address']!.text = address;
      } else {
        widget.controllers['address']!.text = 'خط عرض: ${position.latitude.toStringAsFixed(4)}, خط طول: ${position.longitude.toStringAsFixed(4)}';
      }
      widget.onLocationChanged(lat: position.latitude, lng: position.longitude);
    } catch (e) {
      print("Geocoding Error: $e");
    }
  }

  // 2. وظيفة تحديد الموقع الحالي (Geolocation) - تستخدم مكتبة geolocator
  Future<void> _goToCurrentLocation() async {
    try {
      // 🚨 خطوة 1: التحقق من الأذونات
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('يرجى تفعيل خدمة الموقع (GPS).')));
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم رفض إذن الموقع، يرجى تفعيله يدوياً.')));
          return;
        }
      }
      // خطوة 2: جلب الموقع الفعلي
      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      final newPosition = LatLng(position.latitude, position.longitude);

      // خطوة 3: تحديث الخريطة والمؤشر
      _mapController.move(newPosition, 14); // استخدام move بدلاً من animateTo
      _updateMarker(newPosition);

      // خطوة 4: إزالة الـ Overlay
      setState(() => _isMapActive = true);
    } catch (e) {
      print("Geolocation Error: $e");
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشل تحديد الموقع: ${e.toString()}')));
    }
  }

  // 3. وظيفة تحديث الـ Marker عند السحب أو النقر
  void _updateMarker(LatLng position) {
    setState(() {
      _initialPosition = position; // تحديث الموقع الذي يظهر عليه المؤشر
      _updateAddress(position);
    });
  }

  // 4. وظيفة التقاط/اختيار الصورة
  Future<void> _pickFile(String field) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      final file = File(pickedFile.path);
      widget.onFilePicked(field: field, file: file);

      setState(() {
        if (field == 'logo') _logoPreview = file;
        if (field == 'cr') _crPreview = file;
        if (field == 'tc') _tcPreview = file;
      });
    }
  }

  // 5. وظيفة إرسال النموذج
  void _submitForm() {
    // 💡 تم تحسين التحقق من حقول البائع هنا ليطابق المنطق في الشاشة الرئيسية (للتأكد فقط)
    if (widget.selectedUserType == 'seller') {
      if (widget.controllers['merchantName']!.text.isEmpty || widget.controllers['businessType']!.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الرجاء إدخال اسم الشركة ونوع النشاط التجاري.')));
        return;
      }
    }
    
    if (_formKey.currentState!.validate() && _termsAgreed) {
      widget.onRegister();
    } else if (!_termsAgreed) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('يجب الموافقة على الشروط والأحكام.')));
    }
  }


  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.stretch,

          children: [
            const Text(
              'أدخل بياناتك',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700), // 💡 تحسين حجم ووزن الخط
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),

            // 1. الحقول الأساسية
            _buildInputField(context, 'fullname', Icons.person_rounded), // 💡 أيقونة M3
            _buildInputField(context, 'email', Icons.email_rounded), // 💡 أيقونة M3
            // 💡 ملاحظة: حقل العنوان (Address) تم وضعه قبل الخريطة مباشرة
            _buildInputField(context, 'address', Icons.location_on_rounded, readOnly: true), // العنوان للقراءة فقط
            
            // 2. الخرائط والموقع
            _buildMapContainer(context),
            
            _buildInputField(context, 'password', Icons.lock_rounded, isPassword: true), // 💡 أيقونة M3
            _buildInputField(context, 'confirmPassword', Icons.lock_rounded, isPassword: true, validator: (value) { // 💡 أيقونة M3
              if (value != widget.controllers['password']!.text) {
                return 'كلمة المرور غير متطابقة';
              }
              return null;
            }),

            // 3. حقول تاجر الجملة (Conditional Fields)
            if (widget.selectedUserType == 'seller') _buildSellerFields(context),

            // 4. الشروط والأحكام
            _buildTermsCheckbox(context),       
            
            // 5. زر التسجيل
            ElevatedButton(
              onPressed: widget.isSaving ? null : _submitForm,
              style: ElevatedButton.styleFrom(
                // 💡 تحسينات M3: ارتفاع، شكل، وظل بسيط
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), // زوايا أكثر استدارة
                elevation: 4, // ظل M3
              ),
              child: widget.isSaving
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3)) // 💡 تحسين حجم المؤشر
                  : const Text('إنشاء حساب', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),

            // 6. زر العودة
            TextButton.icon(
              onPressed: widget.onGoBack,
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.grey, size: 20), // 💡 أيقونة M3
              label: const Text('العودة', style: TextStyle(color: Colors.grey, fontSize: 16, fontWeight: FontWeight.w500)),
            ),
          ],                                            
        ),
      ),                                            
    );
  }                                             
  
  // دالة بناء حقل الإدخال                        
  Widget _buildInputField(BuildContext context, String key, IconData icon, {bool isPassword = false, bool readOnly = false, String? Function(String?)? validator}) {                                
    return Padding(                                   
      padding: const EdgeInsets.only(bottom: 20.0), // 💡 تقليل المسافة قليلاً بين الحقول
      child: CustomInputField( // نستخدم CustomInputField المفترضة
        controller: widget.controllers[key]!,
        label: key == 'fullname' ? 'الاسم الكامل' : key == 'email' ? 'البريد الإلكتروني' : key == 'address' ? 'العنوان' : key == 'password' ? 'كلمة المرور' : key == 'confirmPassword' ? 'تأكيد كلمة المرور' : key == 'merchantName' ? 'اسم الشركة / المتجر' : key == 'additionalPhone' ? 'هاتف إضافي (اختياري)' : key,
        icon: icon,                                     
        isPassword: isPassword,
        isReadOnly: readOnly,                           
        keyboardType: key == 'email' ? TextInputType.emailAddress : isPassword ? TextInputType.text : (key.contains('phone') ? TextInputType.phone : TextInputType.text),                               
        validator: validator ?? (value) {
          // استثناء حقل الهاتف الإضافي من التحقق الإلزامي
          if (key == 'additionalPhone') return null;
                                                          
          if (value == null || value.isEmpty) {
            return 'هذا الحقل مطلوب';                     
          }
          return null;
        },
      ),
    );
  }

  // 💡 مكون الخريطة المُحدَّث (FlutterMap)
  Widget _buildMapContainer(BuildContext context) {
    // المؤشر (Marker) الذي سيظهر على الخريطة
    final currentMarker = Marker(
      width: 40.0,
      height: 40.0,
      point: _initialPosition, // يستخدم الموقع الحالي الذي حدده المستخدم/الخريطة
      // 🎯 تم التعديل: استخدام builder بدلاً من child                                                 
      builder: (context) => const Icon(Icons.location_pin, size: 40, color: Colors.redAccent), // 💡 لون المؤشر
    );
                                                    
    return Padding(
      padding: const EdgeInsets.only(bottom: 25.0),
      child: Container(
        // 💡 التعديل الأهم: تقليل ارتفاع الخريطة لتقليل الـ overflow
        height: 180, 
        decoration: BoxDecoration(                        
          borderRadius: BorderRadius.circular(16), // 💡 حواف M3
          border: Border.all(color: Colors.grey.shade300, width: 2),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),                                                        
          child: Stack(
            children: [
              FlutterMap( 
                mapController: _mapController,
                options: MapOptions(
                  center: _initialPosition, 
                  zoom: 12.0, // 💡 تكبير الزوم قليلاً
                  onTap: (tapPosition, latLng) {
                    _updateMarker(latLng); // تحديث المؤشر عند النقر
                    setState(() => _isMapActive = true); // إزالة الـ overlay عند التفاعل                         
                  },
                  onPositionChanged: (position, hasGesture) {
                    // إذا كان المستخدم يحرك الخريطة يدوياً، يمكن إزالة الـ overlay                                  
                    if (hasGesture == true) {
                      setState(() => _isMapActive = true);
                    }
                  }                                             
                ),                                              
                children: [                                       
                  TileLayer(
                    // استخدام OpenStreetMap كمصدر للخرائط                                                          
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.app',
                  ),
                  // طبقة الـ Marker
                  MarkerLayer(                                      
                    markers: [currentMarker],
                  ),
                ],
              ),
              if (!_isMapActive) // يحاكي الـ map-overlay
                Positioned.fill(
                  child: Container(                                 
                    color: Colors.white.withOpacity(0.95), // 💡 لون أفتح للـ Overlay
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [                                       
                        const Text(
                          'اضغط على الزر لتحديد موقعك أو اختيار موقع يدويًا',
                          style: TextStyle(fontSize: 15, color: Colors.black87)
                        ),                                  
                        const SizedBox(height: 15),                                                                     
                        ElevatedButton.icon(
                          onPressed: _goToCurrentLocation,                                                                
                          icon: const Icon(Icons.my_location_rounded, color: Colors.white), // 💡 أيقونة M3
                          label: const Text('تحديد موقعي', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).colorScheme.secondary, // 💡 استخدام لون ثانوي لتمييزه عن زر التسجيل
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 3,
                          ),
                        ),                                            
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),                                            
    );                                            
  }

  // 💡 حقول تاجر الجملة
  Widget _buildSellerFields(BuildContext context) {                                                 
    // قائمة أنواع النشاط التجاري
    final List<String> businessTypes = [
      'تجارة مواد غذائية',
      'تجارة مواد غذائية ومنظفات',                    
      'تجارة ملابس',
      'تجارة اكسسورات',
      'تجارة اجهزة وادوات',
      'متنوع'
    ];
    
    // 💡 تغليف حقول البائع في حاوية لتمييزها بصرياً
    return Padding(
      padding: const EdgeInsets.only(top: 10.0, bottom: 10.0),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.1), // 💡 خلفية خفيفة
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Theme.of(context).colorScheme.primary, width: 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'بيانات التاجر/المتجر',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
              textAlign: TextAlign.center,
            ),
            const Divider(height: 30, thickness: 1),
            
            _buildInputField(context, 'merchantName', Icons.store_rounded, validator: (value) => value == null || value.isEmpty ? 'اسم الشركة مطلوب' : null),
                                                        
            Padding(
              padding: const EdgeInsets.only(bottom: 25.0),
              child: CustomSelectBox<String, String>(
                label: 'نوع النشاط التجاري',
                hintText: 'اختر نوع النشاط التجاري',
                items: businessTypes,
                itemLabel: (item) => item,
                // 🚨 تمرير القيمة للـ controller لاستخدامها في التحقق
                onChanged: (dynamic value) {
                  widget.onBusinessTypeChanged(value as String?);                                                 
                  widget.controllers['businessType']!.text = value ?? '';                                       
                },                                              
                // يجب إضافة controller لـ CustomSelectBox للمزامنة مع controllers['businessType']!
              ),
            ),

            // حقل هاتف إضافي (لا يحتاج validator صارم لأنه اختياري)
            _buildInputField(context, 'additionalPhone', Icons.phone_rounded),                              
            
            const SizedBox(height: 10),
            const Text(
              'وثائق الشركة', 
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black54),
            ),
            const Divider(height: 15, thickness: 0.5),

            // رفع الملفات
            _buildFileInputGroup(context, 'الشعار', Icons.image_rounded, 'logo', _logoPreview),
            _buildFileInputGroup(context, 'السجل التجاري', Icons.credit_card_rounded, 'cr', _crPreview),
            _buildFileInputGroup(context, 'البطاقة الضريبية', Icons.article_rounded, 'tc', _tcPreview),
          ],
        ),
      ),
    );
  }
                                                  
  // 💡 مكون رفع الملف
  Widget _buildFileInputGroup(BuildContext context, String label, IconData icon, String field, File? previewFile) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15.0), // 💡 تقليل المسافة
      child: Column(                                    
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary), // 💡 أيقونة بلون أساسي
              const SizedBox(width: 8),
              Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
              const Spacer(),
              if (previewFile != null)
                Text('تم الاختيار', style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.w500)),
            ],                                            
          ),                                              
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
            decoration: BoxDecoration(
              color: Colors.grey.shade50, // 💡 خلفية بيضاء خفيفة
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade300, width: 1),
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(                       
                    onPressed: () => _pickFile(field),                                                              
                    icon: const Icon(Icons.cloud_upload_rounded),
                    label: Text(previewFile != null ? 'تغيير الملف' : 'اختر صورة/ملف'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      foregroundColor: Theme.of(context).colorScheme.primary, // 💡 لون أساسي
                      side: BorderSide(color: Theme.of(context).colorScheme.primary.withOpacity(0.5)),
                    ),                                            
                  ),
                ),                                              
                if (previewFile != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 15.0),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(
                        previewFile,
                        width: 50, // 💡 تصغير حجم المعاينة
                        height: 50,                                     
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),                                          
              ],
            ),
          ),                                            
        ],
      ),
    );                                            
  }

  // 💡 صندوق الشروط والأحكام
  Widget _buildTermsCheckbox(BuildContext context) {                                                
    return Padding(                                   
      padding: const EdgeInsets.only(top: 15.0, bottom: 25.0),                                        
      child: Row(                                       
        mainAxisAlignment: MainAxisAlignment.start, // 💡 محاذاة لليسار
        children: [
          SizedBox(
            width: 24.0,
            height: 24.0,
            child: Checkbox(
              value: _termsAgreed,
              onChanged: (bool? value) {
                setState(() {                                     
                  _termsAgreed = value ?? false;
                });                                           
              },
              activeColor: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(width: 8), // مسافة بسيطة بعد المربع
          Flexible(
            child: GestureDetector(
              onTap: () {
                // ... (فتح صفحة الشروط والأحكام)
              },                                              
              child: Text.rich(                                 
                TextSpan(                                         
                  text: 'أوافق على ',
                  style: const TextStyle(fontSize: 15),                                                           
                  children: [
                    TextSpan(                                         
                      text: 'الشروط والأحكام وسياسة الخصوصية', // 💡 إضافة تفصيل أكثر
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,                                                   
                        fontWeight: FontWeight.w600,                                                                    
                        decoration: TextDecoration.underline,                                                         
                      ),
                    ),
                  ],                                            
                ),
              ),
            ),
          ),                                            
        ],                                            
      ),                                            
    );
  }
}
