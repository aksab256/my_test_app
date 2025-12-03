// lib/models/logged_user.dart (المُعدَّل)
import 'dart:convert';

class LoggedInUser {
  final String id;
  final String fullname;
  final String role;
  // ✅ آمن: تم جعله قابلاً للـ null (String?)
  final String? phone; 
  
  LoggedInUser({
    required this.id, 
    required this.fullname, 
    required this.role,
    this.phone, // ✅ آمن: تم جعله اختياريًا في constructor
  });

  factory LoggedInUser.fromJson(Map<String, dynamic> json) {
    return LoggedInUser(
      id: json['id'] as String,
      fullname: json['fullname'] as String,
      role: json['role'] as String,
      // ✅ آمن: يقوم بجلب القيمة كـ String?، وإذا لم تكن موجودة فستكون null
      phone: json['phone'] as String?, 
    );
  }
}
