// lib/widgets/forms/custom_input_decoration.dart
import 'package:flutter/material.dart';

// تصميم احترافي لحقول الإدخال في التطبيق
InputDecoration customInputDecoration({String? hintText, Widget? suffixIcon}) {
  const primaryColor = Color(0xff28a745);

  return InputDecoration(
    hintText: hintText,
    suffixIcon: suffixIcon,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
    fillColor: Colors.white,
    filled: true,
    
    // الحدود العادية
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8.0),
      borderSide: const BorderSide(color: Color(0xffced4da), width: 1.0),
    ),

    // الحدود عند التركيز (Focus)
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8.0),
      borderSide: const BorderSide(color: primaryColor, width: 2.0),
    ),
    
    // الحدود عند الخطأ (Error)
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8.0),
      borderSide: const BorderSide(color: Colors.red, width: 1.5),
    ),
    
    // الحدود عند التركيز مع الخطأ
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8.0),
      borderSide: const BorderSide(color: Colors.red, width: 2.0),
    ),
  );
}

