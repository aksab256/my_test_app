// lib/screens/auth/client_details_step.dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:sizer/sizer.dart';
import 'package:permission_handler/permission_handler.dart';

class ClientDetailsStep extends StatefulWidget {
  final Map<String, TextEditingController> controllers;
  final String selectedUserType;
  final bool isSaving;
  final Function({required double lat, required double lng}) onLocationChanged;
  final Function({required String field, required String url}) onUploadComplete;
  final VoidCallback onRegister;
  final VoidCallback onGoBack;

  const ClientDetailsStep({
    super.key,
    required this.controllers,
    required this.selectedUserType,
    required this.isSaving,
    required this.onLocationChanged,
    required this.onUploadComplete,
    required this.onRegister,
    required this.onGoBack,
  });

  @override
  State<ClientDetailsStep> createState() => _ClientDetailsStepState();
}

class _ClientDetailsStepState extends State<ClientDetailsStep> {
  final _formKey = GlobalKey<FormState>();
  late final MapController _mapController;
  
  LatLng _selectedPosition = const LatLng(30.0444, 31.2357); // كبداية فقط
  bool _locationPicked = false;
  bool _isUploading = false;
  bool _obscurePassword = true;
  bool _termsAgreed = false;
  String? _selectedBusinessType;
  
  File? _logoPreview, _crPreview, _tcPreview;
  final String mapboxToken = "pk.eyJ1IjoiYW1yc2hpcGwiLCJhIjoiY21lajRweGdjMDB0eDJsczdiemdzdXV6biJ9.E--si9vOB93NGcAq7uVgGw";

  final List<String> _businessTypes = [
    "تجارة مواد غذائية", "تجارة مواد غذائية ومنظفات", "تجارة ملابس",
    "تجارة اكسسورات", "تجارة اجهزة وادوات", "متنوع"
  ];

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
  }

  // ✅ الخطوة 1: رسالة الإفصاح (متطلب جوجل بلاي)
  Future<void> _handleMapOpeningSequence() async {
    bool? proceed = await showDialog<bool>(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text("استخدام الموقع الجغرافي", style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
          content: const Text(
            "يحتاج تطبيق 'أكسب' للوصول إلى موقعك لتحديد عنوان نشاطك بدقة على الخريطة وتسهيل وصول المناديب والعملاء إليك.",
            style: TextStyle(fontFamily: 'Cairo'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("ليس الآن")),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2D9E68), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              onPressed: () => Navigator.pop(context, true), 
              child: const Text("موافق", style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );

    if (proceed == true) {
      // ✅ الخطوة 2: طلب إذن النظام
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
        // ✅ الخطوة 3: جلب الموقع وفتح الخريطة
        Position position = await Geolocator.getCurrentPosition();
        setState(() {
          _selectedPosition = LatLng(position.latitude, position.longitude);
        });
        _openMapPicker();
      }
    }
  }

  // ✅ الخطوة 4: فتح الخريطة مع رسالة التوجيه
  void _openMapPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            height: 85.h,
            decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
            child: Column(
              children: [
                Container(margin: const EdgeInsets.symmetric(vertical: 12), width: 50, height: 5, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
                // رسالة التوجيه المطلوبة
                Container(
                  width: double.infinity,
                  color: const Color(0xFFF0F7F3),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: const Text(
                    "لحظات.. حرك الخريطة لتغيير مكان المؤشر أو موقعك بدقة",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontFamily: 'Cairo', fontSize: 11, color: Color(0xFF2D9E68), fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  child: FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: _selectedPosition,
                      initialZoom: 16.5,
                      onTap: (tapPos, point) {
                        setModalState(() => _selectedPosition = point);
                        _handleLocationChange(point);
                      },
                    ),
                    children: [
                      TileLayer(urlTemplate: "https://api.mapbox.com/styles/v1/mapbox/outdoors-v12/tiles/{z}/{x}/{y}?access_token=$mapboxToken"),
                      MarkerLayer(markers: [Marker(point: _selectedPosition, width: 60, height: 60, child: const Icon(Icons.location_pin, size: 50, color: Colors.red))]),
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.all(5.w),
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2D9E68), padding: const EdgeInsets.symmetric(vertical: 18), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                    onPressed: () {
                      setState(() => _locationPicked = true);
                      Navigator.pop(context);
                    },
                    child: const Text("تأكيد موقع النشاط", style: TextStyle(fontFamily: 'Cairo', color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          );
        }
      ),
    );
  }

  // دالة تغيير الموقع وتحديث العنوان يدوياً
  void _handleLocationChange(LatLng point) {
    setState(() => _selectedPosition = point);
    _updateAddressText(point);
    widget.onLocationChanged(lat: point.latitude, lng: point.longitude);
  }

  Future<void> _updateAddressText(LatLng position) async {
    try {
      final placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        setState(() {
          widget.controllers['address']!.text = "${place.street ?? ''}, ${place.locality ?? ''}";
        });
      }
    } catch (e) {}
  }

  // باقي الدوال (الرفع، اختيار الملفات، إلخ) كما هي في نسختك الأصلية
  Future<void> _uploadFileToCloudinary(File file, String field) async {
    setState(() => _isUploading = true);
    try {
      var request = http.MultipartRequest('POST', Uri.parse('https://api.cloudinary.com/v1_1/dgmmx6jbu/image/upload'));
      request.fields['upload_preset'] = "commerce";
      request.files.add(await http.MultipartFile.fromPath('file', file.path));
      var response = await request.send();
      if (response.statusCode == 200) {
        var responseData = await response.stream.toBytes();
        var json = jsonDecode(String.fromCharCodes(responseData));
        widget.onUploadComplete(field: field, url: json['secure_url']);
      }
    } catch (e) {
      debugPrint("Error: $e");
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _pickFile(String field) async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 50);
    if (pickedFile != null) {
      final file = File(pickedFile.path);
      setState(() {
        if (field == 'logo') _logoPreview = file;
        if (field == 'cr') _crPreview = file;
        if (field == 'tc') _tcPreview = file;
      });
      await _uploadFileToCloudinary(file, field);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('إكمال بيانات الحساب', style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.w900, color: const Color(0xFF2D9E68)), textAlign: TextAlign.center),
              SizedBox(height: 3.h),
              _buildSectionHeader('المعلومات الأساسية', Icons.badge_rounded),
              _buildInputField('fullname', 'الاسم الكامل', Icons.person_rounded),
              _buildInputField('phone', 'رقم الهاتف', Icons.phone_android_rounded, keyboardType: TextInputType.phone),
              _buildSectionHeader('الموقع الجغرافي', Icons.map_rounded),
              
              // زرار فتح الخريطة بالتسلسل الجديد
              _buildLocationPickerButton(),
              _buildInputField('address', 'العنوان بالتفصيل (يدوي)', Icons.location_on_rounded),
              
              _buildSectionHeader('الأمان', Icons.security_rounded),
              _buildInputField('password', 'كلمة المرور', Icons.lock_open_rounded, isPassword: true),
              _buildInputField('confirmPassword', 'تأكيد كلمة المرور', Icons.lock_rounded, isPassword: true),
              if (widget.selectedUserType == 'seller') ...[SizedBox(height: 2.h), _buildSellerSpecificFields()],
              SizedBox(height: 2.h),
              _buildTermsCheckbox(),
              _buildSubmitButton(),
              TextButton(onPressed: widget.onGoBack, child: Text('العودة لتعديل نوع الحساب', style: TextStyle(color: Colors.grey.shade400, fontSize: 11.sp))),
              SizedBox(height: 5.h),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLocationPickerButton() {
    return InkWell(
      onTap: _handleMapOpeningSequence,
      child: Container(
        padding: const EdgeInsets.all(18),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: _locationPicked ? const Color(0xFFF0F7F3) : Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: _locationPicked ? const Color(0xFF2D9E68) : Colors.grey.shade300, width: 2),
        ),
        child: Row(
          children: [
            Icon(Icons.map_rounded, color: _locationPicked ? const Color(0xFF2D9E68) : Colors.grey),
            const SizedBox(width: 15),
            Expanded(child: Text(_locationPicked ? "تم تحديد الموقع بنجاح ✅" : "اضغط لتحديد موقعك على الخريطة *", style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold))),
            const Icon(Icons.open_in_new_rounded, size: 18, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  // (باقي المكونات _buildInputField, _buildSellerSpecificFields إلخ كما هي)
  Widget _buildInputField(String key, String label, IconData icon, {bool isPassword = false, TextInputType keyboardType = TextInputType.text}) {
    return Padding(
      padding: EdgeInsets.only(bottom: 1.5.h),
      child: TextFormField(
        controller: widget.controllers[key],
        obscureText: isPassword && _obscurePassword,
        keyboardType: keyboardType,
        validator: (value) => (value == null || value.isEmpty) ? "هذا الحقل مطلوب" : null,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: const Color(0xFF2D9E68)),
          suffixIcon: isPassword ? IconButton(icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility), onPressed: () => setState(() => _obscurePassword = !_obscurePassword)) : null,
          filled: true, fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: Colors.grey.shade200)),
        ),
      ),
    );
  }

  Widget _buildSellerSpecificFields() {
    return Container(
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(color: const Color(0xFFF0F7F3), borderRadius: BorderRadius.circular(20)),
      child: Column(
        children: [
          _buildInputField('merchantName', 'اسم النشاط التجاري', Icons.storefront_rounded),
          _buildBusinessTypeDropdown(),
          _buildUploadItem('شعار النشاط / اللوجو', 'logo', _logoPreview),
          _buildUploadItem('صورة السجل التجاري', 'cr', _crPreview),
          _buildUploadItem('صورة البطاقة الضريبية', 'tc', _tcPreview),
        ],
      ),
    );
  }

  Widget _buildBusinessTypeDropdown() {
    return Container(
      margin: EdgeInsets.only(bottom: 2.h), padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.grey.shade300)),
      child: DropdownButtonFormField<String>(
        value: _selectedBusinessType,
        validator: (value) => (value == null || value.isEmpty) ? "يرجى تحديد نوع النشاط" : null,
        decoration: const InputDecoration(border: InputBorder.none, hintText: "نوع النشاط التجاري *"),
        items: _businessTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
        onChanged: (val) {
          setState(() => _selectedBusinessType = val);
          widget.controllers['businessType']?.text = val ?? "";
        },
      ),
    );
  }

  Widget _buildUploadItem(String label, String field, File? file) {
    return GestureDetector(
      onTap: () => _pickFile(field),
      child: Container(
        margin: EdgeInsets.only(bottom: 1.5.h), padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: file != null ? Colors.green : Colors.grey.shade200, width: 1.5)),
        child: Row(children: [
          Icon(file != null ? Icons.check_circle : Icons.upload_file, color: file != null ? Colors.green : Colors.grey, size: 28),
          const SizedBox(width: 15),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Cairo'))),
        ]),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 1.5.h),
      child: Row(children: [Icon(icon, size: 20, color: const Color(0xFF2D9E68)), const SizedBox(width: 8), Text(title, style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.bold, fontFamily: 'Cairo'))]),
    );
  }

  Widget _buildTermsCheckbox() {
    return CheckboxListTile(
      value: _termsAgreed, onChanged: (v) => setState(() => _termsAgreed = v!), activeColor: const Color(0xFF2D9E68),
      title: Text("أوافق على الشروط والأحكام", style: TextStyle(fontSize: 10.sp, fontFamily: 'Cairo')),
      controlAffinity: ListTileControlAffinity.leading,
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: (widget.isSaving || !_termsAgreed || _isUploading) ? null : () {
          if (!_locationPicked) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("يرجى تحديد موقعك أولاً", style: TextStyle(fontFamily: 'Cairo'))));
            return;
          }
          if (_formKey.currentState!.validate()) widget.onRegister();
        },
        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2D9E68), padding: const EdgeInsets.symmetric(vertical: 18), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
        child: (widget.isSaving || _isUploading) ? const CircularProgressIndicator(color: Colors.white) : const Text('إتمام التسجيل والبدء', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
      ),
    );
  }
}
