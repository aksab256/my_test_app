// lib/helpers/auth_service.dart (النسخة النهائية والمحدثة بالتخزين الفعلي)

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart';
// ⭐️⭐️ تم إضافة استيراد SharedPreferences ⭐️⭐️
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  // بيانات Firebase الثابتة
  final String _notificationApiEndpoint = "https://5uex7vzy64.execute-api.us-east-1.amazonaws.com/V2/new_nofiction";

  late final FirebaseAuth _auth;
  late final FirebaseFirestore _db;

  AuthService() {
    _auth = FirebaseAuth.instance;
    _db = FirebaseFirestore.instance;
  }

  /// تسجيل الدخول بالإيميل وكلمة المرور والحصول على الدور
  Future<String> signInWithEmailAndPassword(String email, String password) async {
    try {
      // 1. تسجيل الدخول
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final User? user = userCredential.user;
      if (user == null) throw Exception("user-null");
      final uid = user.uid;

      // 2. البحث عن الدور والبيانات باستخدام الإيميل (كما في الكود الذي يعمل)
      final userData = await _getUserDataByEmail(email);

      // 🛠️ يتم استخدام فحص النوع الآمن (Type Safety) هنا
      final String userRole = userData['role'] is String ? userData['role'] : 'buyer';
      final String userAddress = userData['address'] is String ? userData['address'] : '';
      final String? userFullName = userData['fullname'] is String ? userData['fullname'] : null;
      final String? merchantName = userData['merchantName'] is String ? userData['merchantName'] : null;

      // ⭐️ [التعديل البرمجي الأصح]: توحيد صيغة الموقع قبل التخزين
      Map<String, double>? location;
      
      // أ. محاولة جلبها من حقل 'location' (سواء كان Map أو GeoPoint)
      if (userData['location'] is GeoPoint) {
         final geoPoint = userData['location'] as GeoPoint;
         location = {'lat': geoPoint.latitude, 'lng': geoPoint.longitude};
      } else if (userData['location'] is Map) {
          // التعامل مع Map العادية
         location = Map<String, double>.from(userData['location'] as Map);
      }
      
      // ب. إذا لم نجدها في 'location'، نبحث عن 'lat' و 'lng' منفصلين
      if (location == null && userData['lat'] is num && userData['lng'] is num) {
          location = {
            'lat': (userData['lat'] as num).toDouble(),
            'lng': (userData['lng'] as num).toDouble(),
          };
      }
      // 💡 الآن، 'location' إما null أو Map<String, double> موحدة.

      // ⭐️ 3. حفظ البيانات محلياً بشكل فعلي باستخدام SharedPreferences ⭐️
      await _saveUserToLocalStorage(
        id: uid,
        role: userRole,
        fullname: userFullName,
        address: userAddress,
        merchantName: merchantName,
        location: location, // يتم تمرير القيمة الموحدة
      );

      // 4. FCM (يتم تجاهل الفشل مؤقتاً)
      final fcmToken = await _requestFCMToken();
      if (fcmToken != null) {
        await _registerFcmEndpoint(uid, fcmToken, userRole, userAddress);
      }

      // إرجاع الدور للتوجيه
      return userRole;
    } on FirebaseAuthException catch (e) {
      throw e.code; // نمرر كود خطأ المصادقة
    } catch (e) {
      // لأي خطأ آخر غير المصادقة، نلقي خطأ عام
      throw 'auth/unknown-error';
    }
  }

  // 🚨🚨🚨 الدالة المضافة لإصلاح خطأ البناء 🚨🚨🚨
  /// تسجيل الخروج من Firebase ومسح البيانات المحلية
  Future<void> signOut() async {
    try {
      // 1. تسجيل الخروج من Firebase
      await _auth.signOut();

      // 2. مسح البيانات المحلية (لتسجيل الخروج الكامل)
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('loggedUser');

      // يمكنك إضافة مسح أي بيانات أخرى محفوظة محليًا هنا
    } catch (e) {
      // يجب التعامل مع الأخطاء بدون print في الإنتاج
      debugPrint("🚨 فشل تسجيل الخروج: $e");
    }
  }

  /// البحث عن المستخدم بالإيميل في جميع المجموعات (المنطق الذي يعمل)
  Future<Map<String, dynamic>> _getUserDataByEmail(String email) async {
    final collections = ['sellers', 'consumers', 'users'];

    for (var collectionName in collections) {
      try {
        final snapshot = await _db
            .collection(collectionName)
            .where('email', isEqualTo: email)
            .limit(1)
            .get();

        if (snapshot.docs.isNotEmpty) {
          final doc = snapshot.docs.first;
          final data = doc.data() as Map<String, dynamic>; // 🛠️ تأكيد النوع

          String role = 'buyer';
          if (collectionName == 'sellers') {
            role = 'seller';
          } else if (collectionName == 'consumers') {
            role = 'consumer';
          } else if (collectionName == 'users' && data.containsKey('role')) {
            role = data['role'] is String ? data['role']! : 'buyer';
          }
          return {...data, 'role': role};
        }
      } catch (e) {
        debugPrint("⚠️ فشل قراءة Firestore في $collectionName: $e");
      }
    }

    return {'role': 'buyer'}; // الافتراضي
  }

  /// حفظ البيانات محليًا (النسخة المنفذة بالتخزين الفعلي)
  Future<void> _saveUserToLocalStorage({
    required String id,
    required String role,
    String? fullname,
    String? address,
    String? merchantName,
    Map<String, double>? location,
  }) async {
    final userDataToStore = {
      'id': id,
      // 💡 المفتاح ownerId هو نفسه id (لأغراض التاجر)
      'ownerId': id,
      'role': role,
      'fullname': fullname,
      'address': address,
      'merchantName': merchantName,
      'location': location,
      // 💡 ملاحظة: المفاتيح المستخدمة هنا هي نفس المفاتيح التي تم تخزينها في HTML/JS: 'id', 'role', 'fullname', إلخ.
    };

    // ⭐️⭐️ تطبيق منطق الحفظ الفعلي باستخدام SharedPreferences ⭐️⭐️
    try {
      final prefs = await SharedPreferences.getInstance();

      // تحويل الكائن إلى سلسلة JSON (مطابقة لـ JSON.stringify)
      final jsonString = json.encode(userDataToStore);

      // تخزين سلسلة JSON تحت المفتاح 'loggedUser' (مطابقة لـ localStorage.setItem)
      await prefs.setString('loggedUser', jsonString);

      debugPrint("💾 تم حفظ بيانات المستخدم بنجاح في SharedPreferences: $jsonString");
    } catch (e) {
      debugPrint("🚨 خطأ فادح أثناء حفظ البيانات في SharedPreferences: $e");
    }
  }

  // الدوال المتعلقة بـ FCM (بدون إلقاء استثناء عند الفشل)
  Future<String?> _requestFCMToken() async {
    try {
      if (kIsWeb) {
        return null;
      }
      return await FirebaseMessaging.instance.getToken();
    } catch (e) {
      debugPrint("⚠️ FCM Token retrieval failed: $e");
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

      final response = await http.post(
        Uri.parse(_notificationApiEndpoint),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(apiData),
      );

      if (response.statusCode != 200) {
        debugPrint("⚠️ فشل تسجيل FCM Endpoint. Status: ${response.statusCode}");
      }
    } catch (err) {
      debugPrint("⚠️ خطأ أثناء استدعاء FCM API: $err");
    }
  }
}
