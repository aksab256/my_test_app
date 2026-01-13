// lib/providers/product_offer_provider.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:my_test_app/models/product_offer.dart'; 
import '../models/category_model.dart'; 
import 'buyer_data_provider.dart';

// -------------------------------------------------------------
// 💡 نموذج بيانات المنتج (CatalogProductModel) - مُحسن ومُعالج
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
    if (data == null) throw Exception("بيانات المنتج فارغة");

    // 🚨 معالجة الوحدات لضمان تحويلها من Dynamic إلى Map صريح لظهورها في الـ UI
    final dynamic rawUnits = data['units'];
    List<Map<String, dynamic>> safeUnits = [];

    if (rawUnits is List) {
      safeUnits = rawUnits.map((item) {
        if (item is Map) {
          return Map<String, dynamic>.from(item);
        }
        return <String, dynamic>{};
      }).where((element) => element.isNotEmpty).toList();
    }
    
    return CatalogProductModel(
      id: doc.id,
      name: data['name'] as String? ?? '',
      description: data['description'] as String? ?? '',
      imageUrls: List<String>.from(data['imageUrls'] as List? ?? []),
      units: safeUnits, // الوحدات الآن جاهزة للعرض
      mainId: data['mainId'] as String? ?? '',
      subId: data['subId'] as String? ?? '',
    );
  }
}

// -------------------------------------------------------------
// Provider: ProductOfferProvider (النسخة الاحترافية الكاملة)
// -------------------------------------------------------------
class ProductOfferProvider with ChangeNotifier {
  final BuyerDataProvider _buyerData;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  ProductOfferProvider(this._buyerData) {
    fetchMainCategories();
  }

  // --- الحالة (State) ---
  List<CategoryModel> _mainCategories = [];
  List<CategoryModel> _subCategories = [];
  String? _selectedMainId;
  String? _selectedSubId;
  List<CatalogProductModel> _searchResults = [];
  CatalogProductModel? _selectedProduct;
  final Map<String, double> _selectedUnitPrices = {}; // لتخزين السعر المختار لكل وحدة
  
  String? _message;
  bool _isSuccess = true;
  bool _isLoading = false;
  List<ProductOffer> _offers = [];
  String? _supermarketName;

  // --- Getters ---
  List<CategoryModel> get mainCategories => _mainCategories;
  List<CategoryModel> get subCategories => _subCategories;
  String? get selectedMainId => _selectedMainId;
  String? get selectedSubId => _selectedSubId;
  List<CatalogProductModel> get searchResults => _searchResults;
  CatalogProductModel? get selectedProduct => _selectedProduct;
  Map<String, double> get selectedUnitPrices => _selectedUnitPrices;
  String? get message => _message;
  bool get isSuccess => _isSuccess;
  bool get isLoading => _isLoading;
  List<ProductOffer> get offers => _offers;
  String? get supermarketName => _supermarketName;
  String? get ownerId => _buyerData.loggedInUser?.id;

  // ------------------------------------
  // وظائف التحكم في الاختيارات
  // ------------------------------------

  void setSelectedMainCategory(String? id) {
    _selectedMainId = id;
    _selectedSubId = null;
    _selectedProduct = null;
    _subCategories = [];
    _searchResults = [];
    _selectedUnitPrices.clear();
    notifyListeners();
    if (id != null) fetchSubCategories(id);
  }

  void setSelectedSubCategory(String? id) {
    _selectedSubId = id;
    _selectedProduct = null;
    _searchResults = [];
    _selectedUnitPrices.clear();
    notifyListeners();
    if (id != null) searchProducts('');
  }

  // اختيار المنتج وتجهيز واجهة الوحدات
  void selectProduct(CatalogProductModel? product) {
    _selectedProduct = product;
    _searchResults = [];
    _selectedUnitPrices.clear(); // تصفير الأسعار القديمة فوراً
    notifyListeners(); // 🚨 هذا السطر هو من يُظهر الوحدات في الشاشة
  }

  // تحديد سعر وحدة معينة
  void setSelectedUnitPrice(String unitName, double? price) {
    if (price != null) {
      _selectedUnitPrices[unitName] = price;
    } else {
      _selectedUnitPrices.remove(unitName);
    }
    notifyListeners();
  }

  // ------------------------------------
  // العمليات على Firebase
  // ------------------------------------

  Future<void> fetchMainCategories() async {
    try {
      final q = await _firestore.collection('mainCategory').where('status', isEqualTo: 'active').get();
      _mainCategories = q.docs.map((doc) => CategoryModel.fromFirestore(doc)).toList();
      notifyListeners();
    } catch (e) {
      debugPrint("Error Categories: $e");
    }
  }

  Future<void> fetchSubCategories(String mainId) async {
    try {
      final q = await _firestore.collection('subCategory').where('mainId', isEqualTo: mainId).where('status', isEqualTo: 'active').get();
      _subCategories = q.docs.map((doc) => CategoryModel.fromFirestore(doc)).toList();
      notifyListeners();
    } catch (e) {
      debugPrint("Error SubCategories: $e");
    }
  }

  Future<void> searchProducts(String searchTerm) async {
    if (_selectedSubId == null) return;
    _searchResults.clear();

    try {
      Query q = _firestore.collection('products').where('subId', isEqualTo: _selectedSubId);
      
      if (searchTerm.isNotEmpty) {
        q = q.where('name', isGreaterThanOrEqualTo: searchTerm)
             .where('name', isLessThanOrEqualTo: searchTerm + '\uf8ff');
      }

      final qSnapshot = await q.limit(20).get();
      _searchResults = qSnapshot.docs.map((doc) => CatalogProductModel.fromFirestore(doc)).toList();
      notifyListeners();
    } catch (e) {
      showNotification('خطأ في البحث: $e', false);
    }
  }

  // ------------------------------------
  // وظيفة إرسال العرض (Submit)
  // ------------------------------------
  Future<void> submitOffer() async {
    if (_selectedProduct == null || ownerId == null) {
      showNotification('الرجاء اختيار منتج والتأكد من تسجيل الدخول.', false);
      return;
    }

    if (_selectedUnitPrices.isEmpty) {
      showNotification('برجاء اختيار وحدة واحدة على الأقل وتحديد سعرها.', false);
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      // 1. جلب اسم السوبر ماركت (تأكد من وجود الكولكشن deliverySupermarkets)
      final marketDoc = await _firestore.collection('deliverySupermarkets')
          .where('ownerId', isEqualTo: ownerId).limit(1).get();

      if (marketDoc.docs.isEmpty) {
        throw Exception("لم يتم العثور على متجر مسجل لهذا الحساب");
      }

      final supermarketName = marketDoc.docs.first['supermarketName'];

      // 2. تجهيز مصفوفة الوحدات المختارة بأسعارها
      final List<Map<String, dynamic>> unitsToSave = _selectedUnitPrices.entries.map((e) => {
        'unitName': e.key,
        'price': e.value,
      }).toList();

      // 3. الحفظ في Firestore
      await _firestore.collection('marketOffer').add({
        'ownerId': ownerId,
        'productId': _selectedProduct!.id,
        'supermarketName': supermarketName,
        'units': unitsToSave,
        'status': 'active',
        'createdAt': FieldValue.serverTimestamp(),
      });

      showNotification('✅ تم إضافة العرض بنجاح للمتجر!', true);
      resetForm();
    } catch (e) {
      showNotification('❌ فشل الإرسال: ${e.toString()}', false);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // --- أدوات مساعدة ---
  void showNotification(String msg, bool success) {
    _message = msg;
    _isSuccess = success;
    notifyListeners();
  }

  void clearNotification() {
    _message = null;
    notifyListeners();
  }

  void resetForm() {
    _selectedProduct = null;
    _selectedUnitPrices.clear();
    _searchResults = [];
    notifyListeners();
  }
}
