// lib/providers/product_offer_provider.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/category_model.dart';
// import '../models/offer_model.dart'; // لا حاجة لاستيراد غير مستخدم
// import '../models/logged_user.dart'; // لا حاجة لاستيراد غير مستخدم
import 'buyer_data_provider.dart';

// -------------------------------------------------------------
// 💡 نموذج بيانات المنتج (CatalogProductModel) - تم تصحيح التحويل
// -------------------------------------------------------------
class CatalogProductModel {
  final String id;
  final String name;
  final String description;
  final List<String> imageUrls;
  final List<Map<String, dynamic>> units; // الوحدات في الكتالوج
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
    final data = doc.data() as Map<String, dynamic>;

    // 💡 التصحيح النهائي: استخدام حلقة للتأكد من التحويل الآمن للعناصر داخل القائمة
    final unitsList = data['units'];
    List<Map<String, dynamic>> safeUnits = [];

    if (unitsList is List) {
        for (var item in unitsList) {
            if (item is Map) {
                // التحويل الآمن باستخدام Map<String, dynamic>.from(item)
                safeUnits.add(Map<String, dynamic>.from(item));
            } else {
                debugPrint('⚠️ Found non-Map item in units: $item'); 
            }
        }
    }

    return CatalogProductModel(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      imageUrls: List<String>.from(data['imageUrls'] ?? []),
      units: safeUnits, // استخدام القائمة المُحولة بأمان
      mainId: data['mainId'] ?? '',
      subId: data['subId'] ?? '',
    );
  }
}

// -------------------------------------------------------------
// Provider
// -------------------------------------------------------------
class ProductOfferProvider with ChangeNotifier {
  final BuyerDataProvider _buyerData;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 1. حالة حقول الأقسام والبحث
  List<CategoryModel> _mainCategories = [];
  List<CategoryModel> _subCategories = [];
  String? _selectedMainId;
  String? _selectedSubId;
  List<CatalogProductModel> _searchResults = [];
  CatalogProductModel? _selectedProduct;

  // 2. حالة رسالة النظام
  String? _message;
  bool _isSuccess = true;

  // 3. حالة الوحدات المختارة (الوحدات التي سيتم إرسالها كعرض)
  final Map<String, double> _selectedUnitPrices = {}; // Key: unitName, Value: price

  // Getters
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
      searchProducts(''); // عرض كل المنتجات في القسم الفرعي المختار
    }
  }

  void setSelectedUnitPrice(String unitName, double? price) {
    // 💡 نستخدم 0.0 كقيمة مبدئية لتفعيل الوحدة وتمكين حقل الإدخال في الـ Screen
    if (price != null && price >= 0) {
      _selectedUnitPrices[unitName] = price;
    } else {
      _selectedUnitPrices.remove(unitName);
    }
    notifyListeners();
  }

  // ------------------------------------
  // وظائف جلب البيانات والبحث
  // ------------------------------------
  Future<void> fetchMainCategories() async {
    try {
      final qSnapshot = await _firestore.collection('mainCategory').where('status', isEqualTo: 'active').get();
      _mainCategories = qSnapshot.docs.map((doc) => CategoryModel.fromFirestore(doc)).toList();
      notifyListeners();
    } catch (e) {
      showNotification('خطأ في تحميل الأقسام الرئيسية: $e', false);
    }
  }

  Future<void> fetchSubCategories(String mainId) async {
    try {
      final qSnapshot = await _firestore.collection('subCategory').where('mainId', isEqualTo: mainId).where('status', isEqualTo: 'active').get();
      _subCategories = qSnapshot.docs.map((doc) => CategoryModel.fromFirestore(doc)).toList();
      notifyListeners();
    } catch (e) {
      showNotification('خطأ في تحميل الأقسام الفرعية: $e', false);
    }
  }

  Future<void> searchProducts(String searchTerm) async {
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

  // 💡 تم تعديل: يقبل null لإلغاء اختيار المنتج
  void selectProduct(CatalogProductModel? product) {
    _selectedProduct = product;
    _searchResults = []; // إخفاء نتائج البحث
    _selectedUnitPrices.clear(); // مسح الوحدات المختارة
    notifyListeners();
  }

  // ------------------------------------
  // وظائف الإرسال
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

    // جلب اسم السوبر ماركت (باستخدام البيانات المخزنة مسبقاً)
    final supermarketName = await getSupermarketName();

    if (supermarketName == null) {
      showNotification('فشل جلب اسم السوبر ماركت. يرجى التأكد من تفعيل حسابك كتاجر.', false);
      return;
    }
    final List<Map<String, dynamic>> unitsForOffer = _selectedUnitPrices.entries.map((entry) => {
      'unitName': entry.key,
      'price': entry.value,
    }).toList();

    try {
      // 📝 ملاحظة: تم تذكر اسم المجموعة deliverySupermarkets من المعلومات المخزنة
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

  Future<String?> getSupermarketName() async {
      // 📝 ملاحظة: تم تذكر اسم المجموعة deliverySupermarkets والحقول ownerId و supermarketName
      try {
        final q = await _firestore.collection('deliverySupermarkets')
            .where('ownerId', isEqualTo: ownerId)
            .limit(1)
            .get();

        if (q.docs.isNotEmpty) {
          return q.docs.first.data()['supermarketName'];
        }
        return null;
      } catch (e) {
        debugPrint('Error fetching supermarket name: $e');
        return null;
      }
  }

  void resetForm() {
    _selectedMainId = null;
    _selectedSubId = null;
    _selectedProduct = null;
    _subCategories = [];
    _searchResults = [];
    _selectedUnitPrices.clear();
    // نعيد تحميل الأقسام الرئيسية
    fetchMainCategories();
    notifyListeners();
  }
}
