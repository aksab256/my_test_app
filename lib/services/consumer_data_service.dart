// lib/services/consumer_data_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:my_test_app/screens/consumer/consumer_data_models.dart';

class ConsumerDataService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 1. جلب بيانات الأقسام المميزة (كما هي بدون تغيير مؤثر)
  Future<List<ConsumerCategory>> fetchMainCategories() async {
    try {
      final qSnapshot = await _firestore.collection("mainCategory")
          .where("status", isEqualTo: "active")
          .where("offerBehavior", isEqualTo: "supermarket_offers")
          .orderBy("order", descending: false)
          .get();

      if (qSnapshot.docs.isEmpty) return [];

      return qSnapshot.docs.map((doc) {
        final data = doc.data();
        return ConsumerCategory(
          id: doc.id,
          name: data['name'] ?? 'اسم القسم',
          imageUrl: data['imageUrl'] ?? 'https://via.placeholder.com/85',
          link: data['link'] ?? '#',
        );
      }).toList();
    } catch (e) {
      print("[ConsumerDataService] Error fetching main categories: $e");
      return [];
    }
  }

  // 2. جلب بانرات العروض الحصرية (التعديل هنا لربط التوجيه)
  Future<List<ConsumerBanner>> fetchPromoBanners() async {
    try {
      final qSnapshot = await _firestore.collection("consumerBanners")
          .where("status", isEqualTo: "active")
          .where("targetAudience", isEqualTo: "general")
          .orderBy("order", descending: false)
          .get();

      if (qSnapshot.docs.isEmpty) return [];

      return qSnapshot.docs.map((doc) {
        // نستخدم الـ Factory لضمان قراءة linkType و targetId و targetType
        // مع الحفاظ على الحقل القديم link كما هو
        return ConsumerBanner.fromFirestore(doc);
      }).toList();

    } catch (e) {
      print("[ConsumerDataService] Error fetching promo banners: $e");
      return [];
    }
  }

  // 3. جلب بيانات المستخدم
  Future<Map<String, dynamic>?> fetchConsumerData(String userId) async {
    try {
      final docRef = _firestore.collection("consumers").doc(userId);
      final docSnapshot = await docRef.get();
      return docSnapshot.exists ? docSnapshot.data() : null;
    } catch (e) {
      print("[ConsumerDataService] Error fetching user data: $e");
      return null;
    }
  }
}
