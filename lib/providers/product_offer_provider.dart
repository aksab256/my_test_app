import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// 📌 يجب التأكد من وجود ProductOffer, UnitOffer, Product هنا
import 'package:my_test_app/models/product_offer.dart'; 
import '../models/category_model.dart'; 
import 'buyer_data_provider.dart';

// -------------------------------------------------------------
// 💡 نموذج بيانات المنتج (CatalogProductModel) - لا تغيير
// -------------------------------------------------------------
class CatalogProductModel {
  final String id;
  final String name;
  final String description;
  final List<String> imageUrls;
  final List<Map<String, dynamic>> units;
  final String mainId;
  final String subId;

  CatalogProductModel({
    required this.id,
    required this.name,
    required this.description,
    required this.imageUrls,
    required this.units,
    required this.mainId,
    required this.subId,
  });

  factory CatalogProductModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) throw Exception("Document data is null");

    final unitsList = data['units'];
    List<Map<String, dynamic>> safeUnits = [];

    if (unitsList is List) {
      for (var item in unitsList) {
        if (item is Map) {
          safeUnits.add(Map<String, dynamic>.from(item as Map));
        } else {
          debugPrint('⚠️ Found non-Map item in units: $item');
        }
      }
    }
    
    return CatalogProductModel(
      id: doc.id,
      name: data['name'] as String? ?? '',
      description: data['description'] as String? ?? '',
      imageUrls: List<String>.from(data['imageUrls'] as List? ?? []),
      units: safeUnits,
      mainId: data['mainId'] as String? ?? '',
      subId: data['subId'] as String? ?? '',
    );
  }
}

// -------------------------------------------------------------
// Provider: ProductOfferProvider (المزود المدمج)
// -------------------------------------------------------------
class ProductOfferProvider with ChangeNotifier {
  final BuyerDataProvider _buyerData;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 1. حالة حقول الكتالوج والإضافة (Existing State)
  List<CategoryModel> _mainCategories = [];
  List<CategoryModel> _subCategories = [];
  String? _selectedMainId;
  String? _selectedSubId;
  List<CatalogProductModel> _searchResults = [];
  CatalogProductModel? _selectedProduct;
  final Map<String, double> _selectedUnitPrices = {};
  
  // 2. حالة رسالة النظام (Existing State)
  String? _message;
  bool _isSuccess = true;
  
  // 3. حالة إدارة العروض (NEW State - لحل الأخطاء)
  List<ProductOffer> _offers = []; // 👈 getter: offers
  String? _supermarketName; // 👈 getter: supermarketName
  bool _isLoading = false; // 👈 getter: isLoading

  // Getters (Existing + NEW)
  List<CategoryModel> get mainCategories => _mainCategories;
  List<CategoryModel> get subCategories => _subCategories;
  String? get selectedMainId => _selectedMainId;
  String? get selectedSubId => _selectedSubId;
  List<CatalogProductModel> get searchResults => _searchResults;
  CatalogProductModel? get selectedProduct => _selectedProduct;
  String? get message => _message;
  bool get isSuccess => _isSuccess;
  Map<String, double> get selectedUnitPrices => _selectedUnitPrices;
  String? get ownerId => _buyerData.loggedInUser?.id;

  // 📌 Getters المطلوبة من الشاشة الجديدة
  List<ProductOffer> get offers => _offers; 
  String? get supermarketName => _supermarketName;
  bool get isLoading => _isLoading;

  ProductOfferProvider(this._buyerData) {
    fetchMainCategories();
  }

  // ------------------------------------
  // وظائف إدارة الحالة
  // ------------------------------------
  void showNotification(String msg, bool success) {
    _message = msg;
    _isSuccess = success;
    notifyListeners();
  }

  void clearNotification() {
    _message = null;
    notifyListeners();
  }
  
  void setSelectedMainCategory(String? id) {
    _selectedMainId = id;
    _selectedSubId = null;
    _selectedProduct = null;
    _subCategories = [];
    _searchResults = [];
    _selectedUnitPrices.clear();
    notifyListeners();
    if (id != null) {
      fetchSubCategories(id);
    }
  }

  void setSelectedSubCategory(String? id) {
    _selectedSubId = id;
    _selectedProduct = null;
    _searchResults = [];
    _selectedUnitPrices.clear();
    notifyListeners();
    if (id != null) {
      searchProducts('');
    }
  }

  void setSelectedUnitPrice(String unitName, double? price) {
    if (price != null && price >= 0) {
      _selectedUnitPrices[unitName] = price;
    } else {
      _selectedUnitPrices.remove(unitName);
    }
    notifyListeners();
  }

  // ------------------------------------
  // وظائف جلب الكتالوج والبحث (Existing)
  // ------------------------------------
  Future<void> fetchMainCategories() async {
    // ... (Your existing implementation for fetching main categories) ...
    try {
      final qSnapshot = await _firestore.collection('mainCategory').where('status', isEqualTo: 'active').get();
      _mainCategories = qSnapshot.docs.map((doc) => CategoryModel.fromFirestore(doc)).toList();
      notifyListeners();
    } catch (e) {
      showNotification('خطأ في تحميل الأقسام الرئيسية: $e', false);
    }
  }

  Future<void> fetchSubCategories(String mainId) async {
    // ... (Your existing implementation for fetching sub categories) ...
    try {
      final qSnapshot = await _firestore.collection('subCategory').where('mainId', isEqualTo: mainId).where('status', isEqualTo: 'active').get();
      _subCategories = qSnapshot.docs.map((doc) => CategoryModel.fromFirestore(doc)).toList();
      notifyListeners();
    } catch (e) {
      showNotification('خطأ في تحميل الأقسام الفرعية: $e', false);
    }
  }

  Future<void> searchProducts(String searchTerm) async {
    // ... (Your existing implementation for searching products) ...
    if (_selectedSubId == null) return;
    clearNotification();
    _searchResults.clear();
    _selectedProduct = null;
    _selectedUnitPrices.clear();

    if (searchTerm.length < 2 && searchTerm.isNotEmpty) {
      notifyListeners();
      return;
    }

    try {
      Query q = _firestore.collection('products')
          .where('subId', isEqualTo: _selectedSubId);
      
      if (searchTerm.isNotEmpty) {
        q = q.where('name', isGreaterThanOrEqualTo: searchTerm)
            .where('name', isLessThanOrEqualTo: searchTerm + '\uf8ff')
            .limit(10);
      } else {
        q = q.limit(20);
      }

      final qSnapshot = await q.get();
      _searchResults = qSnapshot.docs.map((doc) => CatalogProductModel.fromFirestore(doc)).toList();
      
      notifyListeners();

      if (searchTerm.isNotEmpty && _searchResults.isEmpty) {
        showNotification('لا توجد نتائج مطابقة في هذا القسم.', false);
      }
    } catch (e) {
      showNotification('خطأ في البحث عن المنتجات: $e', false);
    }
  }

  void selectProduct(CatalogProductModel? product) {
    // ... (Your existing implementation for selecting product) ...
    _selectedProduct = product;
    _searchResults = [];
    _selectedUnitPrices.clear();
    notifyListeners();
  }

  // ------------------------------------
  // وظائف إدارة وعرض العروض (NEW & Refactored)
  // ------------------------------------

  // دالة مساعدة خاصة لجلب اسم السوبر ماركت من Firestore
  Future<String?> _fetchSupermarketNameFromFirestore() async {
    if (ownerId == null) return null;
    try {
      final q = await _firestore.collection('deliverySupermarkets')
          .where('ownerId', isEqualTo: ownerId)
          .limit(1)
          .get();

      if (q.docs.isNotEmpty) {
        return q.docs.first.data()['supermarketName'] as String?;
      }
      return null;
    } catch (e) {
      debugPrint('Error fetching supermarket name: $e');
      return null;
    }
  }

  // 📌 NEW: دالة initializeData (مطلوبة من شاشة العرض)
  Future<void> initializeData(String ownerId) async {
    _isLoading = true;
    notifyListeners();

    // جلب وتخزين اسم السوبر ماركت لرسالة الترحيب
    _supermarketName = await _fetchSupermarketNameFromFirestore();
    
    _isLoading = false;
    notifyListeners();
  }

  // 📌 NEW: دالة fetchOffers (مطلوبة من شاشة العرض)
  Future<void> fetchOffers(String ownerId) async {
    _isLoading = true;
    notifyListeners();
    _offers = []; 

    try {
      final offersQuery = await _firestore
          .collection('marketOffer')
          .where('ownerId', isEqualTo: ownerId)
          .get();

      List<ProductOffer> fetchedOffers = [];
      for (var offerDoc in offersQuery.docs) {
        final data = offerDoc.data();
        final productId = data['productId'] as String?;

        if (productId != null) {
          final productDoc = await _firestore.collection('products').doc(productId).get();

          Product productDetails;
          if (productDoc.exists) {
            productDetails = Product.fromJson(productDoc.id, productDoc.data()!);
          } else {
            productDetails = Product(id: productId, name: 'منتج محذوف/غير معروف', imageUrls: []);
          }

          fetchedOffers.add(ProductOffer.fromFirestore(
            doc: offerDoc,
            productDetails: productDetails,
          ));
        }
      }
      _offers = fetchedOffers;
    } catch (e) {
      debugPrint('ERROR fetching offers: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // 📌 NEW: دالة deleteOffer (مطلوبة من شاشة العرض)
  Future<void> deleteOffer(String offerId) async {
    try {
      await _firestore.collection('marketOffer').doc(offerId).delete();
      // التحديث المحلي
      _offers.removeWhere((offer) => offer.id == offerId);
      notifyListeners();
    } catch (e) {
      debugPrint('ERROR deleting offer $offerId: $e');
      rethrow; 
    }
  }
  
  // 📌 NEW: دالة updateUnitPrice (مطلوبة من شاشة العرض)
  Future<void> updateUnitPrice({
    required String offerId,
    required int unitIndex,
    required double newPrice,
  }) async {
    try {
      final offerToUpdate = _offers.firstWhere((offer) => offer.id == offerId);
      final offerRef = _firestore.collection('marketOffer').doc(offerId);

      // تحديث قائمة الوحدات للـ Firestore (يجب أن تكون Map)
      final updatedUnits = [...offerToUpdate.units.map((u) => u.toMap())];

      if (unitIndex >= 0 && unitIndex < updatedUnits.length) {
        updatedUnits[unitIndex]['price'] = newPrice;

        // تحديث Firestore
        await offerRef.update({'units': updatedUnits});

        // تحديث القائمة المحلية (للتحديث الفوري للواجهة)
        _offers = _offers.map((offer) {
          if (offer.id == offerId) {
            final List<UnitOffer> newUnitOffers = updatedUnits
                .map((json) => UnitOffer.fromJson(json))
                .toList();
            
            return ProductOffer(
              id: offer.id,
              ownerId: offer.ownerId,
              productId: offer.productId,
              supermarketName: offer.supermarketName,
              createdAt: offer.createdAt,
              units: newUnitOffers, 
              productDetails: offer.productDetails,
            );
          }
          return offer;
        }).toList();

        notifyListeners();
      } else {
        throw Exception('Unit index is out of bounds.');
      }
    } catch (e) {
      debugPrint('ERROR updating unit price for $offerId: $e');
      rethrow;
    }
  }

  // ------------------------------------
  // وظائف الإرسال (Existing - تم تحديثها لاستخدام الدالة الجديدة)
  // ------------------------------------
  
  Future<void> submitOffer() async {
    if (_selectedProduct == null || ownerId == null) {
      showNotification('الرجاء اختيار منتج وتسجيل الدخول كتاجر أولاً.', false);
      return;
    }

    if (_selectedUnitPrices.isEmpty) {
      showNotification('يجب اختيار وحدة واحدة على الأقل وتحديد سعرها.', false);
      return;
    }

    // 📌 Refactored: استخدام الدالة الخاصة لجلب اسم السوبر ماركت
    final supermarketName = await _fetchSupermarketNameFromFirestore(); 

    if (supermarketName == null) {
      showNotification('فشل جلب اسم السوبر ماركت. يرجى التأكد من تفعيل حسابك كتاجر.', false);
      return;
    }
    
    final List<Map<String, dynamic>> unitsForOffer = _selectedUnitPrices.entries.map((entry) => {
      'unitName': entry.key,
      'price': entry.value,
    }).toList();

    try {
      final newOffer = {
        'createdAt': FieldValue.serverTimestamp(),
        'productId': _selectedProduct!.id,
        'units': unitsForOffer,
        'ownerId': ownerId,
        'supermarketName': supermarketName,
        'status': 'active',
      };

      await _firestore.collection('marketOffer').add(newOffer);
      showNotification('✅ تم إضافة العرض بنجاح!', true);
      resetForm();
    } catch (e) {
      showNotification('❌ حدث خطأ أثناء إضافة العرض. $e', false);
    }
  }

  void resetForm() {
    _selectedMainId = null;
    _selectedSubId = null;
    _selectedProduct = null;
    _subCategories = [];
    _searchResults = [];
    _selectedUnitPrices.clear();
    fetchMainCategories();
    notifyListeners();
  }
}
