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

  // ... (دالة signInWithEmailAndPassword تبقى كما هي بدون تغيير)
  Future<String> signInWithEmailAndPassword(String email, String password) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final User? user = userCredential.user;
      if (user == null) throw Exception("user-null");
      final uid = user.uid;

      String phoneFromEmail = email.split('@')[0];
      final userData = await _getUserDataByPhone(phoneFromEmail);

      final String userRole = userData['role'] is String ? userData['role'] : 'buyer';
      final String userAddress = userData['address'] is String ? userData['address'] : '';
      final String? userFullName = userData['fullname'] is String ? userData['fullname'] : null;
      final String? merchantName = userData['merchantName'] is String ? userData['merchantName'] : null;
      final String phoneToShow = userData['phone'] is String ? userData['phone'] : phoneFromEmail;

      Map<String, double>? location;
      if (userData['location'] is GeoPoint) {
         final geoPoint = userData['location'] as GeoPoint;
         location = {'lat': geoPoint.latitude, 'lng': geoPoint.longitude};
      } else if (userData['location'] is Map) {
         location = Map<String, double>.from(userData['location'] as Map);
      }
      if (location == null && userData['lat'] is num && userData['lng'] is num) {
          location = { 'lat': (userData['lat'] as num).toDouble(), 'lng': (userData['lng'] as num).toDouble() };
      }

      await _saveUserToLocalStorage(
        id: uid,
        role: userRole,
        fullname: userFullName,
        address: userAddress,
        merchantName: merchantName,
        phone: phoneToShow,
        location: location,
      );

      final fcmToken = await _requestFCMToken();
      if (fcmToken != null) {
        await _registerFcmEndpoint(uid, fcmToken, userRole, userAddress);
      }

      return userRole;
    } on FirebaseAuthException catch (e) {
      throw e.code;
    } catch (e) {
      throw 'auth/unknown-error';
    }
  }

  /// 🛡️ التعديل الأهم: تسجيل الخروج الآمن والكامل
  Future<void> signOut() async {
    try {
      // 1. تسجيل الخروج من Firebase لجلسة العمل الحالية
      await _auth.signOut();
      
      // 2. الوصول لمساحة التخزين المحلية
      final prefs = await SharedPreferences.getInstance();
      
      // 3. 🎯 تنظيف جذري: مسح كل البيانات (clear) وليس فقط loggedUser
      // لضمان عدم وجود أي تداخل بين حسابين مختلفين على نفس الجهاز
      await prefs.clear(); 
      
      debugPrint("🧹 تم تنظيف الذاكرة المحلية بالكامل (Full Wipe)");
    } catch (e) {
      debugPrint("🚨 فشل تسجيل الخروج: $e");
    }
  }

  // ... (بقية الدوال _getUserDataByPhone و _saveUserToLocalStorage و _requestFCMToken و _registerFcmEndpoint تبقى كما هي)
  
  Future<Map<String, dynamic>> _getUserDataByPhone(String phone) async {
    final collections = ['sellers', 'consumers', 'users'];
    for (var collectionName in collections) {
      try {
        final snapshot = await _db.collection(collectionName).where('phone', isEqualTo: phone).limit(1).get();
        if (snapshot.docs.isNotEmpty) {
          final doc = snapshot.docs.first;
          final data = doc.data() as Map<String, dynamic>;
          String role = 'buyer';
          if (collectionName == 'sellers') role = 'seller';
          else if (collectionName == 'consumers') role = 'consumer';
          else if (collectionName == 'users' && data.containsKey('role')) {
            role = data['role'] is String ? data['role']! : 'buyer';
          }
          return {...data, 'role': role};
        }
      } catch (e) {
        debugPrint("⚠️ فشل قراءة Firestore في $collectionName: $e");
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
    Map<String, double>? location,
  }) async {
    final userDataToStore = {
      'id': id,
      'ownerId': id,
      'role': role,
      'fullname': fullname,
      'address': address,
      'merchantName': merchantName,
      'phone': phone,
      'location': location,
    };
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('loggedUser', json.encode(userDataToStore));
      debugPrint("💾 تم حفظ البيانات بنجاح");
    } catch (e) {
      debugPrint("🚨 خطأ في SharedPreferences: $e");
    }
  }

  Future<String?> _requestFCMToken() async {
    try { if (kIsWeb) return null; return await FirebaseMessaging.instance.getToken(); } 
    catch (e) { return null; }
  }

  Future<void> _registerFcmEndpoint(String userId, String fcmToken, String userRole, String userAddress) async {
    try {
      final apiData = { 'userId': userId, 'fcmToken': fcmToken, 'role': userRole, 'address': userAddress };
      await http.post(Uri.parse(_notificationApiEndpoint), headers: {'Content-Type': 'application/json'}, body: json.encode(apiData));
    } catch (err) { debugPrint("⚠️ AWS Error: $err"); }
  }
}
