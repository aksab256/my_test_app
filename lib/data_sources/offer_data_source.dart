// lib/data_sources/offer_data_source.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:my_test_app/models/offer_model.dart';

class OfferDataSource {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 💡 دالة جديدة لجلب بيانات المنتج لاستخراج الصورة واسم المنتج
  Future<Map<String, dynamic>?> _fetchProductDetails(String productId) async {
    try {
      final productDoc = await _firestore.collection('products').doc(productId).get();
      if (productDoc.exists) {
        return productDoc.data();
      }
    } catch (e) {
      // التعامل مع الأخطاء هنا أو تجاهلها
      print('Error fetching product details for $productId: $e');
    }
    return null;
  }

  // ⭐️ الدالة المعدلة لجلب العروض مع دمج بيانات المنتج ⭐️
  Future<List<ProductOfferModel>> loadSellerOffers(String sellerId) async {
    if (sellerId.isEmpty) return [];

    try {
      final offersQuery = _firestore.collection('productOffers')
          .where('sellerId', isEqualTo: sellerId)
          .get();

      final querySnapshot = await offersQuery;

      if (querySnapshot.docs.isEmpty) {
        return [];
      }

      final List<ProductOfferModel> offers = [];
      final Set<String> productIds = {};

      // 1. جلب وتحويل بيانات العروض وتجميع IDs المنتجات
      for (var doc in querySnapshot.docs) {
        final offer = ProductOfferModel.fromFirestore(doc.data(), doc.id);
        offers.add(offer);
        productIds.add(offer.productId);
      }

      // 2. جلب تفاصيل جميع المنتجات المطلوبة دفعة واحدة (Concurrent Fetching)
      // يتم استخدام Future.wait لتسريع العملية
      final productDetailsFutures = productIds.map((id) => _fetchProductDetails(id)).toList();
      final productDetailsList = await Future.wait(productDetailsFutures);

      final Map<String, Map<String, dynamic>> productDetailsMap = {};
      int index = 0;
      for (var id in productIds) {
        if (productDetailsList[index] != null) {
          productDetailsMap[id] = productDetailsList[index]!;
        }
        index++;
      }

      // 3. دمج بيانات المنتج (الاسم والصورة) مع العروض
      // نستخدم List<ProductOfferModel> offers مباشرة للتعديل على العناصر
      for (var i = 0; i < offers.length; i++) {
        var offer = offers[i];
        final productData = productDetailsMap[offer.productId];
        
        if (productData != null) {
          
          // ⭐️ التصحيح: جلب أول رابط صورة بأمان أكبر ⭐️
          String? fetchedImageUrl;
          final imageUrls = productData['imageUrls'];

          if (imageUrls is List && imageUrls.isNotEmpty) {
            // نستخدم .toString() بدلاً من as String لتجنب فشل التحويل القسري (Casting)
            // إذا كان العنصر الأول هو dynamic أو String
            fetchedImageUrl = imageUrls[0]?.toString(); 
          }

          // إعادة بناء الموديل باستخدام البيانات المكتملة
          offers[i] = ProductOfferModel(
            id: offer.id,
            sellerId: offer.sellerId,
            sellerName: offer.sellerName,
            productId: offer.productId,
            productName: productData['name'] ?? offer.productName, // تحديث اسم المنتج
            deliveryZones: offer.deliveryZones,
            units: offer.units,
            minOrder: offer.minOrder,
            maxOrder: offer.maxOrder,
            lowStockThreshold: offer.lowStockThreshold,
            status: offer.status,
            createdAt: offer.createdAt,
            // 💡 استخدام الرابط المُستخلَص والمصحح
            imageUrl: fetchedImageUrl, 
          );
        }
      }

      // 4. إرجاع القائمة المحدثة
      return offers;

    } catch (e) {
      print('Error loading offers with product details: $e');
      throw Exception('فشل في تحميل العروض أو تفاصيل المنتجات: $e');
    }
  }

  // دالة تحديث العرض
  Future<void> updateOffer(String offerId, Map<String, dynamic> data) async {
    try {
      await _firestore.collection('productOffers').doc(offerId).update(data);
    } catch (e) {
      throw Exception('فشل تحديث العرض: $e');
    }
  }

  // دالة حذف العرض
  Future<void> deleteOffer(String offerId) async {
    try {
      await _firestore.collection('productOffers').doc(offerId).delete();
    } catch (e) {
      throw Exception('فشل حذف العرض: $e');
    }
  }
}

