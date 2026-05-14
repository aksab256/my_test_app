// lib/services/auth_service.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_test_app/services/user_session.dart';

class AuthService {
  // 💡 تم تحديث الرابط الميت هنا ليكون متوافقاً مع رابط الـ Firebase Cloud Function الجديد المرفوع بنجاح
  final String _notificationApiEndpoint =
      "https://us-central1-aksab-erp.cloudfunctions.net/registerFCMToken";
      
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

      Map<String, dynamic> userData;
      try {
        userData = await _getUserDataByEmail(email);
      } catch (e) {
        debugPrint("⚠️ تحذير: فشل جلب البيانات الإضافية: $e");
        userData = {'role': 'buyer'};
      }

      final String userRole = userData['role'];

      if (userRole == 'pending') {
        await _auth.signOut();
        throw 'auth/account-not-active';
      }

      final String? repCode = userData['repCode'];
      final String? repName = userData['repName'];
      final String userAddress = userData['address'] ?? '';
      final String? userFullName = userData['fullname'] ?? userData['fullName'];
      final String? merchantName = userData['merchantName'];
      final String phoneToShow = userData['phone'] ?? email.split('@')[0];
      
      // ✅ استخراج الموقع الجغرافي بشكل دقيق للتوافق مع الرادار
      final dynamic userLocation = userData['location'];

      final String effectiveOwnerId = (userData['parentSellerId'] != null)
          ? userData['parentSellerId']
          : (userData['sellerId'] != null ? userData['sellerId'] : user.uid);

      // 3. حفظ البيانات مع إضافة حقول المندوب والموقع الجغرافي
      await _saveUserToLocalStorage(
        id: user.uid,
        ownerId: effectiveOwnerId,
        role: userRole,
        fullname: userFullName,
        address: userAddress,
        merchantName: merchantName,
        phone: phoneToShow,
        location: userLocation, // 👈 ممرر لداخل الدالة
        isSubUser: userData['isSubUser'] ?? false,
        repCode: repCode,
        repName: repName,
      );

      return userRole;
    } on FirebaseAuthException catch (e) {
      throw e.code;
    } catch (e) {
      if (e == 'auth/account-not-active') rethrow;
      debugPrint("🚨 Error in AuthService: $e");
      throw 'auth/unknown-error';
    }
  }

  Future<void> _saveUserToLocalStorage({
    required String id,
    required String ownerId,
    required String role,
    String? fullname,
    String? address,
    String? merchantName,
    String? phone,
    dynamic location,
    bool isSubUser = false,
    String? repCode,
    String? repName,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    // ✅ استخلاص خطوط الطول والعرض لحفظها بشكل منفصل للرادار
    double? lat;
    double? lng;

    if (location != null) {
      if (location is Map) {
        lat = (location['lat'] ?? location['latitude'] as num?)?.toDouble();
        lng = (location['lng'] ?? location['longitude'] as num?)?.toDouble();
      } else if (location is GeoPoint) {
        lat = location.latitude;
        lng = location.longitude;
      }
    }

    // حفظ الاحداثيات بشكل منفصل لضمان عمل كود "عنواني المسجل" في الرادار
    if (lat != null && lng != null) {
      await prefs.setDouble('user_lat', lat);
      await prefs.setDouble('user_lng', lng);
    }

    final data = {
      'id': id,
      'ownerId': ownerId,
      'role': role,
      'fullname': fullname,
      'address': address,
      'merchantName': merchantName,
      'phone': phone,
      'location': location is GeoPoint ? {'lat': lat, 'lng': lng} : location,
      'isSubUser': isSubUser,
      'repCode': repCode,
      'repName': repName,
    };

    // حفظ الكائن الكامل لاستخدامه في الـ Checkout
    await prefs.setString('loggedUser', json.encode(data));

    // تحديث الجلسة النشطة
    UserSession.userId = id;
    UserSession.ownerId = ownerId;
    UserSession.role = role;
    UserSession.isSubUser = isSubUser;
    UserSession.merchantName = merchantName;
    UserSession.phoneNumber = phone;

    debugPrint("✅ تم تحديث الجلسة والموقع الجغرافي: $lat, $lng");
  }

  Future<void> signOut() async {
    try {
      await _auth.signOut();
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear(); // مسح كامل للذاكرة لضمان الأمان
      UserSession.clear();
    } catch (e) {
      debugPrint("🚨 فشل الخروج: $e");
    }
  }

  // دالة جلب البيانات تبقى كما هي دون تغيير لضمان استقرار جلب البيانات من المجموعات المختلفة
  Future<Map<String, dynamic>> _getUserDataByEmail(String email) async {
    final collections = ['sellers', 'consumers', 'users', 'pendingSellers', 'subUsers'];
    final phoneFromEmail = email.split('@')[0];

    for (var colName in collections) {
      try {
        DocumentSnapshot? docSnap;
        if (colName == 'subUsers') {
          docSnap = await _db.collection(colName).doc(phoneFromEmail).get();
        }

        if (docSnap != null && docSnap.exists) {
          final Map<String, dynamic> data = docSnap.data() as Map<String, dynamic>;
          return {...data, 'role': data['role'] ?? 'seller', 'isSubUser': true};
        }

        final snap = await _db
            .collection(colName)
            .where('phone', isEqualTo: phoneFromEmail)
            .limit(1)
            .get();

        QuerySnapshot snapToUse = snap;
        if (snapToUse.docs.isEmpty) {
          snapToUse = await _db
              .collection(colName)
              .where('email', isEqualTo: email)
              .limit(1)
              .get();
        }

        if (snapToUse.docs.isNotEmpty) {
          final Map<String, dynamic> data =
              snapToUse.docs.first.data() as Map<String, dynamic>;

          String role = data['role'] ?? 'buyer';
          if (colName == 'sellers') role = 'seller';
          else if (colName == 'consumers') role = 'consumer';

          return {...data, 'role': role, 'isSubUser': false};
        }
      } catch (e) {
        debugPrint("⚠️ خطأ في قراءة $colName: $e");
      }
    }
    return {'role': 'buyer'};
  }
}