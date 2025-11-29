// lib/data_sources/client_data_source.dart

import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';

// 🛑 قم بتغيير هذه القيم إلى قيم مشروعك الفعلية
const String NOTIFICATION_API_ENDPOINT = "https://5uex7vzy64.execute-api.us-east-1.amazonaws.com/V2/new_nofiction";
const String CLOUDINARY_CLOUD_NAME = "your_cloudinary_cloud_name"; // يجب تحديث هذا
const String CLOUDINARY_UPLOAD_PRESET = "your_cloudinary_upload_preset"; // يجب تحديث هذا

class ClientDataSource {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;

  // 1. دالة رفع الصورة إلى Cloudinary
  Future<String?> uploadImageToCloudinary(File imageFile) async {
    try {
      final uri = Uri.parse('https://api.cloudinary.com/v1_1/$CLOUDINARY_CLOUD_NAME/image/upload');
      
      final request = http.MultipartRequest('POST', uri)
        ..fields['upload_preset'] = CLOUDINARY_UPLOAD_PRESET
        ..files.add(await http.MultipartFile.fromPath('file', imageFile.path));

      final response = await request.send();

      if (response.statusCode == 200) {
        final responseData = await response.stream.bytesToString();
        final data = json.decode(responseData);
        return data['secure_url'];
      } else {
        print('Cloudinary upload failed with status: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Cloudinary upload error: $e');
      return null;
    }
  }

  // 2. دالة تسجيل المستخدم في Auth و Firestore
  Future<User?> registerAndSaveUser({
    required String email,
    required String password,
    required Map<String, dynamic> data,
  }) async {
    try {
      // إنشاء المستخدم في Firebase Authentication
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = userCredential.user;
      if (user == null) return null;

      // تحديد المجموعة ونوع التحويل
      final role = data['role'] as String;
      final targetCollectionName = _getCollectionNameForRole(role);
      
      // حفظ بيانات المستخدم في Firestore
      await _firestore.collection(targetCollectionName).doc(user.uid).set(data);

      // استدعاء دالة تسجيل FCM في الـ API
      _registerFCMTokenApi(user.uid, role, data['address'] as String);

      return user;
    } on FirebaseAuthException catch (e) {
      // إعادة رمي الخطأ ليتم معالجته في الشاشة
      throw e;
    } catch (e) {
      throw Exception('فشل في تسجيل المستخدم أو حفظ البيانات: $e');
    }
  }

  // 3. دالة تحديد اسم المجموعة بناءً على الدور
  String _getCollectionNameForRole(String role) {
    switch (role) {
      case 'seller':
        return 'pendingSellers'; // تاجر جملة: يحتاج للمراجعة
      case 'consumer':
        return 'consumers'; // مستهلك
      case 'buyer':
        return 'users'; // تاجر تجزئة (مستخدم نشط)
      default:
        return 'users';
    }
  }

  // 4. دالة استدعاء API لتسجيل رمز FCM
  Future<void> _registerFCMTokenApi(String userId, String role, String address) async {
    try {
      final fcmToken = await _fcm.getToken();
      
      if (fcmToken == null) {
        print('FCM Token not available. Skipping notification registration.');
        return;
      }

      final apiData = {
        'userId': userId,
        'fcmToken': fcmToken,
        'role': role,
        'address': address
      };
      
      final response = await http.post(
        Uri.parse(NOTIFICATION_API_ENDPOINT),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(apiData),
      );

      if (response.statusCode != 200) {
        print('FCM API call failed: ${response.body}');
      } else {
        final apiResult = json.decode(response.body);
        if (apiResult['success'] != true) {
          print('FCM registration failed: ${apiResult['message']}');
        } else {
          print('FCM registration successful.');
        }
      }
    } catch (e) {
      print('Error calling Notification API: $e');
    }
  }
}
