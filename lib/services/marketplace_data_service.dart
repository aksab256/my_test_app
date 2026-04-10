// lib/services/marketplace_data_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:my_test_app/models/banner_model.dart';
import 'package:my_test_app/models/category_model.dart';
import 'package:my_test_app/models/product_model.dart';
import 'package:my_test_app/models/offer_model.dart';

class MarketplaceDataService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // 1. جلب البانرات لمتجر معين (بدون تغيير)
  Future<List<BannerModel>> fetchBanners(String ownerId) async {
    try {
      final bannersQuery = await _db
          .collection('consumerBanners')
          .where('status', isEqualTo: 'active')
          .where('ownerId', isEqualTo: ownerId)
          .orderBy('order', descending: false)
          .get();

      return bannersQuery.docs.map((doc) {
        final data = doc.data();
        return BannerModel(
          id: doc.id,
          imageUrl: data['imageUrl'] ?? '',
          url: data['url'],
          altText: data['altText'],
          order: (data['order'] as num?)?.toInt() ?? 0,
          status: 'active',
        );
      }).toList();
    } catch (e) {
      throw Exception('فشل جلب البانرات: $e');
    }
  }

  // 2. [تعديل الطلقة 🚀] جلب الأقسام بناءً على عروض المتجر مباشرة
  Future<List<CategoryModel>> fetchCategoriesByOffers(String ownerId) async {
    try {
      // بنجيب العروض اللي فيها mainCategoryId محشور جواها
      final offersSnapshot = await _db
          .collection('marketOffer')
          .where('ownerId', isEqualTo: ownerId)
          .where('status', isEqualTo: 'active')
          .get();

      if (offersSnapshot.docs.isEmpty) return [];

      // سحب المعرفات مباشرة من العرض (وفرنا لفة كولكشن products)
      final mainCategoryIds = offersSnapshot.docs
          .map((doc) => doc.data() as Map<String, dynamic>)
          .where((data) => data.containsKey('mainCategoryId'))
          .map((data) => data['mainCategoryId'] as String)
          .toSet();

      if (mainCategoryIds.isEmpty) return [];

      // جلب بيانات الأقسام في طلب واحد للسيرفر
      final categoriesSnapshots = await _db
          .collection('mainCategory')
          .where(FieldPath.documentId, whereIn: mainCategoryIds.toList())
          .get();

      final List<CategoryModel> activeCategories = categoriesSnapshots.docs.map((docSnap) {
        final data = docSnap.data();
        return CategoryModel(
          id: docSnap.id,
          name: data['name'] ?? 'قسم غير مسمى',
          imageUrl: data['imageUrl'] ?? '',
          order: (data['order'] as num?)?.toInt() ?? 0,
          status: data['status']?.toString().toLowerCase() == 'active',
        );
      }).where((cat) => cat.status).toList();

      activeCategories.sort((a, b) => a.order.compareTo(b.order));
      return activeCategories;
    } catch (e) {
      throw Exception('فشل جلب الأقسام بناءً على العروض: $e');
    }
  }

  // 3. [تعديل الطلقة 🚀] جلب الأقسام الفرعية بناءً على عروض المتجر والقسم الرئيسي
  Future<List<CategoryModel>> fetchSubCategoriesByOffers(String mainCategoryId, String ownerId) async {
    try {
      final offersSnapshot = await _db
          .collection('marketOffer')
          .where('ownerId', isEqualTo: ownerId)
          .where('mainCategoryId', isEqualTo: mainCategoryId)
          .where('status', isEqualTo: 'active')
          .get();

      if (offersSnapshot.docs.isEmpty) return [];

      // سحب معرف القسم الفرعي مباشرة من العرض
      final subCategoryIds = offersSnapshot.docs
          .map((doc) => doc.data() as Map<String, dynamic>)
          .where((data) => data.containsKey('subCategoryId'))
          .map((data) => data['subCategoryId'] as String)
          .toSet();

      if (subCategoryIds.isEmpty) return [];

      final subCategoriesDocs = await _db
          .collection('subCategory')
          .where(FieldPath.documentId, whereIn: subCategoryIds.toList())
          .get();

      final List<CategoryModel> activeSubCategories = subCategoriesDocs.docs.map((docSnap) {
        final data = docSnap.data();
        return CategoryModel(
          id: docSnap.id,
          name: data['name'] ?? 'قسم فرعي غير مسمى',
          imageUrl: data['imageUrl'] ?? '',
          order: (data['order'] as num?)?.toInt() ?? 0,
          status: data['status']?.toString().toLowerCase() == 'active',
        );
      }).where((sub) => sub.status).toList();

      activeSubCategories.sort((a, b) => a.order.compareTo(b.order));
      return activeSubCategories;
    } catch (e) {
      throw Exception('فشل جلب الأقسام الفرعية بناءً على العروض: $e');
    }
  }

  // 4. جلب المنتجات والعروض (تم تحسين الاستعلام)
  Future<List<Map<String, dynamic>>> fetchProductsAndOffersBySubCategory({
    required String ownerId,
    required String mainId,
    required String subId,
  }) async {
    try {
      final offersSnapshot = await _db
          .collection('marketOffer')
          .where('ownerId', isEqualTo: ownerId)
          .where('mainCategoryId', isEqualTo: mainId)
          .where('subCategoryId', isEqualTo: subId)
          .where('status', isEqualTo: 'active')
          .get();

      if (offersSnapshot.docs.isEmpty) return [];

      // هنا نقدر نعرض المنتجات فوراً من بيانات العرض لو حابب، 
      // بس هنخلي الهيكل ده شغال لو احتجت بيانات تفصيلية زيادة من كولكشن products
      final List<Map<String, dynamic>> results = [];
      for (var offerDoc in offersSnapshot.docs) {
        final offerData = offerDoc.data();
        
        // استخدام البيانات المسطحة اللي خزنّاها في العرض (الاسم والصورة)
        final productModel = ProductModel(
          id: offerData['productId'],
          name: offerData['productName'] ?? 'منتج غير مسمى',
          mainCategoryId: offerData['mainCategoryId'],
          subCategoryId: offerData['subCategoryId'],
          imageUrls: [offerData['productImage'] ?? ''],
          displayPrice: 0.0, // الأسعار موجودة في الـ units داخل الـ offer
          isAvailable: true,
        );

        final offerModel = ProductOfferModel.fromFirestore(offerData, offerDoc.id);

        results.add({
          'product': productModel,
          'offer': offerModel,
        });
      }
      return results;
    } catch (e) {
      throw Exception('فشل جلب المنتجات والعروض: $e');
    }
  }

  // 5. جلب اسم البائع (بدون تغيير)
  Future<String> fetchSupermarketNameById(String ownerId) async {
    try {
      final docSnap = await _db.collection('deliverySupermarkets').doc(ownerId).get();
      if (docSnap.exists) {
        final data = docSnap.data();
        return data?['supermarketName'] as String? ?? 'بائع (سوبر ماركت)';
      }
    } catch (e) {}
    try {
      final docSnap = await _db.collection('sellers').doc(ownerId).get();
      if (docSnap.exists) {
        final data = docSnap.data();
        return data?['name'] as String? ?? 'بائع (مورد)';
      }
    } catch (e) {}
    throw Exception('فشل جلب اسم البائع للمعرف $ownerId');
  }
}

