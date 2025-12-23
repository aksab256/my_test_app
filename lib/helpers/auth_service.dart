// lib/helpers/auth_service.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  final String _notificationApiEndpoint = "https://5uex7vzy64.execute-api.us-east-1.amazonaws.com/V2/new_nofiction";
  late final FirebaseAuth _auth;
  late final FirebaseFirestore _db;

  AuthService() {
    _auth = FirebaseAuth.instance;
    _db = FirebaseFirestore.instance;
  }

  Future<String> signInWithEmailAndPassword(String email, String password) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      final User? user = userCredential.user;
      if (user == null) throw Exception("user-null");

      // البحث عن بيانات المستخدم كاملة في كل المجموعات بما فيها الانتظار
      final userData = await _getUserDataByEmail(email);
      final String userRole = userData['role'];

      // 🎯 منطق التحقق من الحساب المعلق (Pending)
      if (userRole == 'pending') {
        await _auth.signOut(); // طرده فوراً من النظام
        throw 'auth/account-not-active'; // إرسال كود خطأ مخصص للـ UI
      }

      final String userAddress = userData['address'] ?? '';
      final String? userFullName = userData['fullname'] ?? userData['fullName'];
      final String? merchantName = userData['merchantName'];
      final String phoneToShow = userData['phone'] ?? email.split('@')[0];
      
      // جلب اللوكيشن {lat, lng} من الفايرستور
      final dynamic userLocation = userData['location'];

      // حفظ البيانات في الذاكرة المحلية (فقط إذا كان الحساب مفعل)
      await _saveUserToLocalStorage(
        id: user.uid,
        role: userRole,
        fullname: userFullName,
        address: userAddress,
        merchantName: merchantName,
        phone: phoneToShow,
        location: userLocation,
      );

      return userRole;
    } on FirebaseAuthException catch (e) {
      throw e.code;
    } catch (e) {
      // إذا كان الخطأ هو عدم تفعيل الحساب، نمرره كما هو
      if (e == 'auth/account-not-active') throw e;
      throw 'auth/unknown-error';
    }
  }

  Future<void> signOut() async {
    try {
      await _auth.signOut();
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      debugPrint("🧹 الذاكرة نظيفة تماماً");
    } catch (e) {
      debugPrint("🚨 فشل الخروج: $e");
    }
  }

  Future<Map<String, dynamic>> _getUserDataByEmail(String email) async {
    // 🎯 أضفنا pendingSellers هنا لتكون ضمن نطاق البحث
    final collections = ['sellers', 'consumers', 'users', 'pendingSellers'];
    
    for (var colName in collections) {
      try {
        final snap = await _db.collection(colName).where('email', isEqualTo: email).limit(1).get();
        if (snap.docs.isNotEmpty) {
          final data = snap.docs.first.data();
          String role = 'buyer';

          // تحويل اسم المجموعة إلى "دور" (Role) برمي
          if (colName == 'sellers') {
            role = 'seller';
          } else if (colName == 'consumers') {
            role = 'consumer';
          } else if (colName == 'users') {
            role = 'buyer';
          } else if (colName == 'pendingSellers') {
            role = 'pending'; // 🎯 وسم الحساب كـ "معلق"
          }

          return {...data, 'role': role};
        }
      } catch (e) {
        debugPrint("⚠️ خطأ في قراءة $colName: $e");
      }
    }
    return {'role': 'buyer'};
  }

  Future<void> _saveUserToLocalStorage({
    required String id,
    required String role,
    String? fullname,
    String? address,
    String? merchantName,
    String? phone,
    dynamic location,
  }) async {
    final data = {
      'id': id,
      'ownerId': id,
      'role': role,
      'fullname': fullname,
      'address': address,
      'merchantName': merchantName,
      'phone': phone,
      'location': location,
    };
    final prefs = await SharedPreferences.getInstance();
    // 🎯 استخدام Key 'loggedUser' كما اتفقنا لضمان الثبات [2025-11-02]
    await prefs.setString('loggedUser', json.encode(data));
    debugPrint("✅ تم حفظ بيانات المستخدم واللوكيشن بنجاح");
  }

  Future<String?> _requestFCMToken() async { 
    try { 
      return await FirebaseMessaging.instance.getToken(); 
    } catch (e) { 
      return null; 
    } 
  }

  Future<void> _registerFcmEndpoint(String userId, String fcmToken, String userRole, String userAddress) async {
    try {
      final apiData = { 
        'userId': userId, 
        'fcmToken': fcmToken, 
        'role': userRole, 
        'address': userAddress 
      };
      await http.post(
        Uri.parse(_notificationApiEndpoint), 
        headers: {'Content-Type': 'application/json'}, 
        body: json.encode(apiData)
      );
    } catch (e) { 
      debugPrint("⚠️ AWS Error: $e"); 
    }
  }
}

