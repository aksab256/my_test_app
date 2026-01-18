import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:my_test_app/models/product_model.dart' hide CategoryModel;
import 'package:my_test_app/models/category_model.dart';
import 'package:my_test_app/models/user_role.dart';

class ProductRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // --- جلب التصنيفات الرئيسية ---
  Future<List<CategoryModel>> fetchMainCategories() async {
    final snapshot = await _firestore.collection('mainCategory').orderBy('order').get();
    return snapshot.docs.map((doc) {
      final data = doc.data();
      return CategoryModel(
        id: doc.id,
        name: data['name'] ?? 'قسم غير معروف',
        imageUrl: data['imageUrl'] ?? '',
        status: data['status'] == 'active',
        order: (data['order'] as num?)?.toInt() ?? 999,
      );
    }).toList();
  }

  // --- جلب التصنيفات الفرعية ---
  Future<List<CategoryModel>> fetchSubCategories(String? mainCatId) async {
    Query<Map<String, dynamic>> query = _firestore.collection('subCategory');
    if (mainCatId != null && mainCatId.isNotEmpty) {
      query = query.where('mainId', isEqualTo: mainCatId);
    }
    final snapshot = await query.get();
    return snapshot.docs.map((doc) {
      final data = doc.data();
      return CategoryModel(
        id: doc.id,
        name: data['name'] ?? 'قسم غير معروف',
        imageUrl: data['imageUrl'] ?? '',
        status: data['status'] == 'active',
        order: (data['order'] as num?)?.toInt() ?? 999,
      );
    }).toList();
  }

  // --- دالة البحث الرئيسية المخصصة للـ Buyer فقط ---
  Future<List<ProductModel>> searchProducts({
    required UserRole userRole,
    required String searchTerm,
    String? mainCategoryId,
    String? subCategoryId,
    required ProductSortOption sortOption,
  }) async {
    // 1. العمل دائماً على كولكشن العروض للتاجر
    final collectionName = 'productOffers';
    
    Query<Map<String, dynamic>> query = _firestore.collection(collectionName);

    // تصفية العروض النشطة فقط
    query = query.where('status', isEqualTo: 'active');

    // فلاتر الأقسام
    if (subCategoryId != null && subCategoryId.isNotEmpty) {
      query = query.where('subCategoryId', isEqualTo: subCategoryId);
    } else if (mainCategoryId != null && mainCategoryId.isNotEmpty) {
      query = query.where('mainCategoryId', isEqualTo: mainCategoryId);
    }

    // البحث النصي (Prefix Search) على حقل productName في كولكشن العروض
    if (searchTerm.isNotEmpty) {
      query = query.where('productName', 
          isGreaterThanOrEqualTo: searchTerm, 
          isLessThanOrEqualTo: '$searchTerm\uf8ff');
    }

    // بناء الفرز
    switch (sortOption) {
      case ProductSortOption.nameAsc:
        query = query.orderBy('productName', descending: false);
        break;
      case ProductSortOption.nameDesc:
        query = query.orderBy('productName', descending: true);
        break;
      case ProductSortOption.priceAsc:
        // الترتيب حسب السعر (لو موجود كحقل رقمي مباشر)
        query = query.orderBy('productName'); // لتجنب تعارض الـ Indexes غالباً نثبت الاسم
        break;
      default:
        query = query.orderBy('productName');
    }

    final snapshot = await query.get();

    List<ProductModel> results = [];

    for (var doc in snapshot.docs) {
      final data = doc.data();
      
      // جلب السعر من مصفوفة الوحدات (Units) كما في بياناتك
      double? displayPrice;
      final units = data['units'] as List<dynamic>?;
      if (units != null && units.isNotEmpty) {
        // نأخذ سعر أول وحدة متاحة
        displayPrice = (units.first['price'] as num?)?.toDouble();
      }

      // 🖼️ منطق الصورة: نأخذها من العرض، وإذا لم توجد نطلبها من المنتج الأصلي
      List<String> finalImages = [];
      if (data['imageUrl'] != null && data['imageUrl'].toString().isNotEmpty) {
        finalImages.add(data['imageUrl']);
      } else {
        // محاولة جلب الصورة من كولكشن products باستخدام productId الموجود في العرض
        final productId = data['productId'];
        if (productId != null) {
          final prodDoc = await _firestore.collection('products').doc(productId).get();
          if (prodDoc.exists) {
            final prodData = prodDoc.data();
            final prodImages = prodData?['imageUrls'] as List<dynamic>?;
            if (prodImages != null && prodImages.isNotEmpty) {
              finalImages = prodImages.map((e) => e.toString()).toList();
            }
          }
        }
      }

      // صورة افتراضية لو فشل كل ما سبق
      if (finalImages.isEmpty) {
        finalImages.add('https://via.placeholder.com/150?text=No+Image');
      }

      results.add(ProductModel(
        id: doc.id,
        name: data['productName'] ?? 'منتج بدون اسم',
        mainCategoryId: data['mainCategoryId'],
        subCategoryId: data['subCategoryId'],
        imageUrls: finalImages,
        displayPrice: displayPrice,
        isAvailable: true, // العروض الـ active نعتبرها متاحة
      ));
    }

    return results;
  }
}
