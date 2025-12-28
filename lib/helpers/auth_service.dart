// lib/helpers/auth_service.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_test_app/services/user_session.dart';

class AuthService {
  final String _notificationApiEndpoint =
      "https://5uex7vzy64.execute-api.us-east-1.amazonaws.com/V2/new_nofiction";
  late final FirebaseAuth _auth;
  late final FirebaseFirestore _db;

  AuthService() {
    _auth = FirebaseAuth.instance;
    _db = FirebaseFirestore.instance;
  }

  Future<String> signInWithEmailAndPassword(String email, String password) async {
    try {
      // 1. محاولة تسجيل الدخول في Firebase Auth
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final User? user = userCredential.user;
      if (user == null) throw Exception("user-null");

      // 2. جلب بيانات المستخدم من Firestore
      // تم وضعها في بلوك مستقل لضمان أن أي خطأ في القراءة لا يظهر كخطأ كلمة مرور
      Map<String, dynamic> userData;
      try {
        userData = await _getUserDataByEmail(email);
      } catch (e) {
        debugPrint("⚠️ تحذير: فشل جلب البيانات الإضافية، سيتم استخدام دور افتراضي: $e");
        userData = {'role': 'buyer'};
      }

      final String userRole = userData['role'];

      // التحقق من حالة الحساب المعلق
      if (userRole == 'pending') {
        await _auth.signOut();
        throw 'auth/account-not-active';
      }

      // تجهيز البيانات للحفظ
      final String userAddress = userData['address'] ?? '';
      final String? userFullName = userData['fullname'] ?? userData['fullName'];
      final String? merchantName = userData['merchantName'];
      final String phoneToShow = userData['phone'] ?? email.split('@')[0];
      final dynamic userLocation = userData['location'];

      final String effectiveOwnerId = (userData['parentSellerId'] != null)
          ? userData['parentSellerId']
          : (userData['sellerId'] != null ? userData['sellerId'] : user.uid);

      // 3. حفظ البيانات محلياً وتحديث الجلسة
      await _saveUserToLocalStorage(
        id: user.uid,
        ownerId: effectiveOwnerId,
        role: userRole,
        fullname: userFullName,
        address: userAddress,
        merchantName: merchantName,
        phone: phoneToShow,
        location: userLocation,
        isSubUser: userData['isSubUser'] ?? false,
      );

      return userRole;
    } on FirebaseAuthException catch (e) {
      // إرسال كود الخطأ الصريح من Firebase (مثل wrong-password)
      throw e.code;
    } catch (e) {
      // معالجة الأخطاء الخاصة (مثل الحساب غير النشط) أو الأخطاء غير المتوقعة
      if (e == 'auth/account-not-active') rethrow;
      debugPrint("🚨 Error in AuthService: $e");
      throw 'auth/unknown-error';
    }
  }

  Future<void> signOut() async {
    try {
      await _auth.signOut();
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      UserSession.clear();
      debugPrint("🧹 الذاكرة نظيفة تماماً");
    } catch (e) {
      debugPrint("🚨 فشل الخروج: $e");
    }
  }

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
          String actualRole = data['role'] ?? 'seller';
          return {...data, 'role': actualRole, 'isSubUser': true};
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
          bool isSubUser = false;

          // الحفاظ على منطق تحديد الأدوار الأصلي
          if (colName == 'sellers') {
            role = 'seller';
          } else if (colName == 'subUsers') {
            isSubUser = true;
          } else if (colName == 'consumers') {
            role = 'consumer';
          } else if (colName == 'users') {
            role = 'buyer';
          } else if (colName == 'pendingSellers') {
            role = 'pending';
          }

          return {...data, 'role': role, 'isSubUser': isSubUser};
        }
      } catch (e) {
        debugPrint("⚠️ خطأ في قراءة $colName: $e");
      }
    }
    return {'role': 'buyer'};
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
  }) async {
    final data = {
      'id': id,
      'ownerId': ownerId,
      'role': role,
      'fullname': fullname,
      'address': address,
      'merchantName': merchantName,
      'phone': phone,
      'location': location,
      'isSubUser': isSubUser,
    };

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('loggedUser', json.encode(data));

    UserSession.userId = id;
    UserSession.ownerId = ownerId;
    UserSession.role = role;
    UserSession.isSubUser = isSubUser;
    UserSession.merchantName = merchantName;
    UserSession.phoneNumber = phone;

    debugPrint("✅ تم تحديث الجلسة بنجاح: $id برتبة: $role");
  }
}

