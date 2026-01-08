// lib/screens/auth/client_details_step.dart

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:sizer/sizer.dart';

class ClientDetailsStep extends StatefulWidget {
  final Map<String, TextEditingController> controllers;
  final String selectedUserType;
  final bool isSaving;
  final Function({required double lat, required double lng}) onLocationChanged;
  final Function({required String field, required File file}) onFilePicked;
  final VoidCallback onRegister;
  final VoidCallback onGoBack;

  const ClientDetailsStep({
    super.key,
    required this.controllers,
    required this.selectedUserType,
    required this.isSaving,
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
  LatLng _initialPosition = const LatLng(30.0444, 31.2357);
  String? _selectedBusinessType; // حقل نوع النشاط الجديد
  bool _termsAgreed = false;
  File? _logoPreview, _crPreview, _tcPreview;

  // قائمة أنواع النشاط كما في الـ HTML
  final List<String> _businessTypes = [
    "تجارة مواد غذائية",
    "تجارة مواد غذائية ومنظفات",
    "تجارة ملابس",
    "تجارة اكسسورات",
    "تجارة اجهزة وادوات",
    "متنوع"
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(4.w),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            Text('إكمال بيانات الحساب', style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.bold, color: const Color(0xFF2D9E68))),
            SizedBox(height: 3.h),
            
            // الاسم الكامل
            _buildInputField('fullname', 'الاسم الكامل', Icons.person),
            
            // رقم الهاتف (الذي سيتحول لميل)
            _buildInputField('phone', 'رقم الهاتف (سيكون هو المعرف)', Icons.phone, keyboardType: TextInputType.phone),

            // العنوان (يحدث تلقائيا من الخريطة)
            _buildInputField('address', 'العنوان الحالي', Icons.location_on, readOnly: true),

            if (widget.selectedUserType == 'seller') ...[
              const Divider(height: 40),
              _buildInputField('merchantName', 'اسم الشركة / النشاط', Icons.business),
              
              // حقل نوع النشاط (Dropdown) - مطابق للـ HTML
              _buildDropdownField(),

              const SizedBox(height: 20),
              _buildUploadItem('شعار المورد (Cloudinary)', 'logo', _logoPreview),
              _buildUploadItem('السجل التجاري', 'cr', _crPreview),
              _buildUploadItem('البطاقة الضريبية', 'tc', _tcPreview),
            ],

            // حقل كلمة المرور
            _buildInputField('password', 'كلمة المرور', Icons.lock, isPassword: true),
            
            _buildTermsCheckbox(),
            
            SizedBox(height: 3.h),
            _buildSubmitButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdownField() {
    return Container(
      margin: EdgeInsets.only(bottom: 2.h),
      padding: const EdgeInsets.symmetric(horizontal: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          hint: const Text("اختر نوع النشاط التجاري"),
          value: _selectedBusinessType,
          items: _businessTypes.map((type) {
            return DropdownMenuItem(value: type, child: Text(type));
          }).toList(),
          onChanged: (val) {
            setState(() => _selectedBusinessType = val);
            // نقوم بتخزين القيمة في الـ controllers لتصل لدالة التسجيل
            widget.controllers['businessType'] = TextEditingController(text: val);
          },
        ),
      ),
    );
  }

  // ... (بقية الـ Widgets مثل _buildInputField و _buildUploadItem كما في الكود السابق)
  // مع ملاحظة استدعاء widget.onFilePicked عند اختيار صورة
}
