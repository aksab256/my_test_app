// lib/services/consumer_data_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:my_test_app/screens/consumer/consumer_data_models.dart';
// نستخدم ConsumerDataService بدلاً من Provider/Riverpod مباشرة في هذه المرحلة

class ConsumerDataService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 1. جلب بيانات الأقسام المميزة (Categories)
  Future<List<ConsumerCategory>> fetchMainCategories() async {
    try {
      // 💡 المجموعات والحقول حرفيا من كود الـ HTML المرفق:
      final qSnapshot = await _firestore.collection("mainCategory")
          .where("status", isEqualTo: "active")
          .where("offerBehavior", isEqualTo: "supermarket_offers") // فلترة السوبر ماركت
          .orderBy("order", descending: false)
          .get();

      if (qSnapshot.docs.isEmpty) {
        return [];
      }

      return qSnapshot.docs.map((doc) {
        final data = doc.data();
        return ConsumerCategory(
          id: doc.id,
          name: data['name'] ?? 'اسم القسم',
          imageUrl: data['imageUrl'] ?? 'https://via.placeholder.com/85',
          link: data['link'] ?? '#', // يمكن أن يكون الرابط هو المسار
        );
      }).toList();

    } catch (e) {
      print("[ConsumerDataService] Error fetching main categories: $e");
      // في حالة الخطأ، نرجع قائمة فارغة أو نرمي خطأ
      return [];
    }
  }

  // 2. جلب بانرات العروض الحصرية (Banners)
  Future<List<ConsumerBanner>> fetchPromoBanners() async {
    try {
      // 💡 المجموعات والحقول حرفيا من كود الـ HTML المرفق:
      final qSnapshot = await _firestore.collection("consumerBanners")
          .where("status", isEqualTo: "active")
          .where("targetAudience", isEqualTo: "general") // عرض البانرات العامة فقط
          .orderBy("order", descending: false)
          .get();

      if (qSnapshot.docs.isEmpty) {
        return [];
      }

      return qSnapshot.docs.map((doc) {
        final data = doc.data();
        return ConsumerBanner(
          id: doc.id,
          imageUrl: data['imageUrl'] ?? 'https://via.placeholder.com/460x180',
          link: data['link'] ?? '#', // الرابط الذي يوجه إليه البانر
        );
      }).toList();

    } catch (e) {
      print("[ConsumerDataService] Error fetching promo banners: $e");
      return [];
    }
  }

  // 3. جلب بيانات المستخدم (للتكامل مع الشاشة الرئيسية)
  // هذه دالة أساسية تمثل منطق fetchUserData
  Future<Map<String, dynamic>?> fetchConsumerData(String userId) async {
    try {
      final docRef = _firestore.collection("consumers").doc(userId);
      final docSnapshot = await docRef.get();

      if (docSnapshot.exists) {
        return docSnapshot.data();
      }
      return null;
    } catch (e) {
      print("[ConsumerDataService] Error fetching user data: $e");
      return null;
    }
  }
}
