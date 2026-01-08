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
  late MapController _mapController;
  LatLng _selectedPosition = const LatLng(30.0444, 31.2357); // القاهرة كافتراضي
  
  // 🔑 Mapbox Access Token
  final String mapboxToken = "pk.eyJ1IjoiYW1yc2hpcGwiLCJhIjoiY21lajRweGdjMDB0eDJsczdiemdzdXV6biJ9.E--si9vOB93NGcAq7uVgGw";

  File? _logoPreview, _crPreview, _tcPreview;
  bool _termsAgreed = false;
  bool _isMapActive = false;
  bool _obscurePassword = true;
  bool _isUploading = false;

  String? _selectedBusinessType;
  final List<String> _businessTypes = [
    "تجارة مواد غذائية",
    "تجارة مواد غذائية ومنظفات",
    "تجارة ملابس",
    "تجارة اكسسورات",
    "تجارة اجهزة وادوات",
    "متنوع"
  ];

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    // إرسال الموقع الافتراضي في البداية
    widget.onLocationChanged(lat: _selectedPosition.latitude, lng: _selectedPosition.longitude);
  }

  // --- Cloudinary Upload Logic ---
  Future<void> _uploadFileToCloudinary(File file, String field) async {
    setState(() => _isUploading = true);
    const String cloudName = "dgmmx6jbu";
    const String uploadPreset = "commerce";

    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload'),
      );
      request.fields['upload_preset'] = uploadPreset;
      request.files.add(await http.MultipartFile.fromPath('file', file.path));

      var response = await request.send();
      if (response.statusCode == 200) {
        var responseData = await response.stream.toBytes();
        var responseString = String.fromCharCodes(responseData);
        var json = jsonDecode(responseString);
        String secureUrl = json['secure_url'];
        widget.onUploadComplete(field: field, url: secureUrl);
      }
    } catch (e) {
      debugPrint("Cloudinary Error: $e");
    } finally {
      setState(() => _isUploading = false);
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
              Text('إكمال بيانات الحساب', 
                style: TextStyle(fontSize: 22.sp, fontWeight: FontWeight.w900, color: const Color(0xFF2D9E68)), 
                textAlign: TextAlign.center),
              SizedBox(height: 4.h),
              
              _buildSectionHeader('المعلومات الأساسية', Icons.badge_rounded),
              _buildInputField('fullname', 'الاسم الكامل', Icons.person_rounded),
              _buildInputField('phone', 'رقم الهاتف', Icons.phone_android_rounded, keyboardType: TextInputType.phone),
              
              _buildSectionHeader('العنوان والموقع التجاري', Icons.map_rounded),
              _buildInputField('address', 'العنوان بالتفصيل (أو اختر من الخريطة)', Icons.location_on_rounded),
              _buildMapContainer(),
              
              _buildSectionHeader('الأمان', Icons.security_rounded),
              _buildInputField('password', 'كلمة المرور', Icons.lock_open_rounded, isPassword: true),
              _buildInputField('confirmPassword', 'تأكيد كلمة المرور', Icons.lock_rounded, isPassword: true),

              if (widget.selectedUserType == 'seller') ...[
                SizedBox(height: 3.h),
                _buildSellerSpecificFields(),
              ],
              
              SizedBox(height: 3.h),
              _buildTermsCheckbox(),
              SizedBox(height: 4.h),
              _buildSubmitButton(),
              
              TextButton(
                onPressed: widget.onGoBack,
                child: Text('العودة لتعديل نوع الحساب', style: TextStyle(color: Colors.grey.shade400, fontSize: 13.sp)),
              ),
              SizedBox(height: 5.h),
            ],
          ),
        ),
      ),
    );
  }

  // الخريطة باستخدام Mapbox والتحكم في الدبوس
  Widget _buildMapContainer() {
    return Column(
      children: [
        Container(
          height: 35.h,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(25),
            border: Border.all(color: Colors.grey.shade200, width: 2),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(23),
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _selectedPosition,
                    initialZoom: 13.0,
                    onTap: (tapPosition, point) {
                      _handleLocationChange(point);
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: "https://api.mapbox.com/styles/v1/mapbox/outdoors-v12/tiles/{z}/{x}/{y}?access_token=$mapboxToken",
                      userAgentPackageName: 'com.example.app',
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: _selectedPosition,
                          width: 80,
                          height: 80,
                          child: const Icon(Icons.location_pin, size: 50, color: Colors.red),
                        ),
                      ],
                    ),
                  ],
                ),
                // زر تحديد الموقع الحالي
                Positioned(
                  bottom: 15,
                  right: 15,
                  child: FloatingActionButton(
                    mini: true,
                    backgroundColor: const Color(0xFF2D9E68),
                    onPressed: _goToCurrentLocation,
                    child: const Icon(Icons.my_location, color: Colors.white),
                  ),
                ),
                if (!_isMapActive) 
                  Container(
                    color: Colors.white.withOpacity(0.4),
                    child: Center(
                      child: Text("اضغط لتفعيل الخريطة وتحديد موقعك", 
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10.sp, backgroundColor: Colors.white70))
                    ),
                  ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text("يمكنك تحريك الخريطة والضغط لتغيير مكان الدبوس بدقة", 
            style: TextStyle(fontSize: 9.sp, color: Colors.grey)),
        ),
      ],
    );
  }

  // --- دوال التحكم في الموقع ---
  void _handleLocationChange(LatLng point) {
    setState(() {
      _selectedPosition = point;
      _isMapActive = true;
    });
    _updateAddressText(point);
    widget.onLocationChanged(lat: point.latitude, lng: point.longitude);
  }

  Future<void> _updateAddressText(LatLng position) async {
    try {
      final placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        setState(() {
          widget.controllers['address']!.text = 
            "${place.street ?? ''}, ${place.locality ?? ''}, ${place.administrativeArea ?? ''}";
        });
      }
    } catch (e) {
      debugPrint("Geocoding error: $e");
    }
  }

  Future<void> _goToCurrentLocation() async {
    if (await Permission.location.request().isGranted) {
      Position position = await Geolocator.getCurrentPosition();
      final newPos = LatLng(position.latitude, position.longitude);
      _mapController.move(newPos, 16.0); // الزوم المطلوب
      _handleLocationChange(newPos);
    }
  }

  // --- بقية الـ Widgets (البائع، المدخلات، الأزرار) ---

  Widget _buildSellerSpecificFields() {
    return Container(
      padding: EdgeInsets.all(5.w),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F7F3),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: const Color(0xFF2D9E68).withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Text('بيانات النشاط التجاري', style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold, color: const Color(0xFF2D9E68))),
          SizedBox(height: 3.h),
          _buildInputField('merchantName', 'اسم النشاط / الشركة', Icons.storefront_rounded),
          _buildBusinessTypeDropdown(),
          _buildUploadItem('شعار العلامة التجارية', 'logo', _logoPreview),
          _buildUploadItem('صورة السجل التجاري', 'cr', _crPreview),
          _buildUploadItem('صورة البطاقة الضريبية', 'tc', _tcPreview),
        ],
      ),
    );
  }

  Widget _buildBusinessTypeDropdown() {
    return Container(
      margin: EdgeInsets.only(bottom: 2.h),
      padding: const EdgeInsets.symmetric(horizontal: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: DropdownButtonFormField<String>(
        value: _selectedBusinessType,
        decoration: const InputDecoration(border: InputBorder.none, hintText: "نوع النشاط"),
        items: _businessTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
        onChanged: (val) {
          setState(() => _selectedBusinessType = val);
          widget.controllers['businessType']?.text = val ?? "";
        },
      ),
    );
  }

  Widget _buildInputField(String key, String label, IconData icon, {bool isPassword = false, TextInputType keyboardType = TextInputType.text}) {
    return Padding(
      padding: EdgeInsets.only(bottom: 2.h),
      child: TextFormField(
        controller: widget.controllers[key],
        obscureText: isPassword && _obscurePassword,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: const Color(0xFF2D9E68)),
          suffixIcon: isPassword ? IconButton(icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility), onPressed: () => setState(() => _obscurePassword = !_obscurePassword)) : null,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: Colors.grey.shade200)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: Colors.grey.shade200)),
        ),
      ),
    );
  }

  Widget _buildUploadItem(String label, String field, File? file) {
    return GestureDetector(
      onTap: () => _pickFile(field),
      child: Container(
        margin: EdgeInsets.only(bottom: 1.5.h),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: file != null ? Colors.green : Colors.grey.shade300, width: 1),
        ),
        child: Row(children: [
          Icon(file != null ? Icons.check_circle : Icons.upload_file, color: file != null ? Colors.green : Colors.grey),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: TextStyle(fontSize: 11.sp))),
          if (file != null) ClipRRect(borderRadius: BorderRadius.circular(5), child: Image.file(file, width: 40, height: 40, fit: BoxFit.cover)),
        ]),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding:
