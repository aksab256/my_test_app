// lib/providers/product_offer_provider.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:my_test_app/models/product_offer.dart';
import '../models/category_model.dart';
import 'buyer_data_provider.dart';

// --- نموذج المنتج للكتالوج ---
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
    if (data == null) throw Exception("Data null");
    final List rawUnits = data['units'] as List? ?? [];
    return CatalogProductModel(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      imageUrls: List<String>.from(data['imageUrls'] ?? []),
      units: rawUnits.map((u) => Map<String, dynamic>.from(u as Map)).toList(),
      mainId: data['mainId'] ?? '',
      subId: data['subId'] ?? '',
    );
  }
}

class ProductOfferProvider with ChangeNotifier {
  final BuyerDataProvider _buyerData;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  ProductOfferProvider(this._buyerData) {
    fetchMainCategories();
  }

  // --- الحالة (State) ---
  List<CategoryModel> _mainCategories = [];
  List<CategoryModel> _subCategories = [];
  List<CatalogProductModel> _searchResults = [];
  CatalogProductModel? _selectedProduct;
  final Map<String, double> _selectedUnitPrices = {};
  List<ProductOffer> _offers = [];
  String? _supermarketName;
  bool _isLoading = false;
  String? _selectedMainId;
  String? _selectedSubId;

  String? _message;
  bool _isSuccess = true;

  // --- Getters ---
  List<CategoryModel> get mainCategories => _mainCategories;
  List<CategoryModel> get subCategories => _subCategories;
  List<CatalogProductModel> get searchResults => _searchResults;
  CatalogProductModel? get selectedProduct => _selectedProduct;
  Map<String, double> get selectedUnitPrices => _selectedUnitPrices;
  List<ProductOffer> get offers => _offers;
  String? get supermarketName => _supermarketName;
  bool get isLoading => _isLoading;
  String? get ownerId => _buyerData.loggedInUser?.id;
  String? get selectedMainId => _selectedMainId;
  String? get selectedSubId => _selectedSubId;
  String? get message => _message;
  bool get isSuccess => _isSuccess;

  // --- وظائف التنبيهات ---
  void showNotification(String msg, bool success) {
    _message = msg;
    _isSuccess = success;
    notifyListeners();
  }

  void clearNotification() {
    _message = null;
    notifyListeners();
  }

  // --- وظائف إدارة العروض ---
  Future<void> initializeData(String ownerId) async {
    _isLoading = true;
    notifyListeners();
    try {
      final q = await _firestore
          .collection('deliverySupermarkets')
          .where('ownerId', isEqualTo: ownerId)
          .limit(1)
          .get();
      if (q.docs.isNotEmpty) {
        _supermarketName = q.docs.first.data()['supermarketName'];
      }
    } catch (e) {
      debugPrint("Init Error: $e");
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> fetchOffers(String ownerId) async {
    _isLoading = true;
    _offers = [];
    notifyListeners();
    try {
      final snap = await _firestore
          .collection('marketOffer')
          .where('ownerId', isEqualTo: ownerId)
          .get();

      List<ProductOffer> fetched = [];
      for (var doc in snap.docs) {
        // إذا قمت بتعديل الموديل الخاص بـ ProductOffer ليقبل البيانات المباشرة،
        // يمكنك هنا إلغاء جلب المنتج من كولكشن products لتسريع الكود أكثر.
        final pDoc = await _firestore.collection('products').doc(doc['productId']).get();
        if (pDoc.exists) {
          fetched.add(ProductOffer.fromFirestore(
            doc: doc,
            productDetails: Product.fromJson(pDoc.id, pDoc.data()!),
          ));
        }
      }
      _offers = fetched;
    } catch (e) {
      debugPrint("Fetch Error: $e");
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> deleteOffer(String offerId) async {
    await _firestore.collection('marketOffer').doc(offerId).delete();
    _offers.removeWhere((o) => o.id == offerId);
    notifyListeners();
  }

  Future<void> updateUnitPrice(
      {required String offerId, required int unitIndex, required double newPrice}) async {
    final offer = _offers.firstWhere((o) => o.id == offerId);
    final updatedUnits = offer.units.map((u) => u.toMap()).toList();
    updatedUnits[unitIndex]['price'] = newPrice;
    await _firestore.collection('marketOffer').doc(offerId).update({'units': updatedUnits});
    await fetchOffers(ownerId!);
  }

  // --- وظائف الكتالوج والإضافة ---
  void setSelectedMainCategory(String? id) {
    _selectedMainId = id;
    _selectedSubId = null;
    if (id != null) fetchSubCategories(id);
    notifyListeners();
  }

  void setSelectedSubCategory(String? id) {
    _selectedSubId = id;
    if (id != null) searchProducts('');
    notifyListeners();
  }

  void selectProduct(CatalogProductModel? p) {
    _selectedProduct = p;
    _selectedUnitPrices.clear();
    notifyListeners();
  }

  void setSelectedUnitPrice(String name, double? price) {
    if (price != null)
      _selectedUnitPrices[name] = price;
    else
      _selectedUnitPrices.remove(name);
    notifyListeners();
  }

  Future<void> fetchMainCategories() async {
    final q = await _firestore.collection('mainCategory').where('status', isEqualTo: 'active').get();
    _mainCategories = q.docs.map((doc) => CategoryModel.fromFirestore(doc)).toList();
    notifyListeners();
  }

  Future<void> fetchSubCategories(String mainId) async {
    final q = await _firestore.collection('subCategory').where('mainId', isEqualTo: mainId).get();
    _subCategories = q.docs.map((doc) => CategoryModel.fromFirestore(doc)).toList();
    notifyListeners();
  }

  Future<void> searchProducts(String term) async {
    if (_selectedSubId == null) return;
    Query q = _firestore.collection('products').where('subId', isEqualTo: _selectedSubId);
    if (term.isNotEmpty) {
      q = q.where('name', isGreaterThanOrEqualTo: term).where('name', isLessThanOrEqualTo: term + '\uf8ff');
    }
    final snap = await q.limit(20).get();
    _searchResults = snap.docs.map((doc) => CatalogProductModel.fromFirestore(doc)).toList();
    notifyListeners();
  }

  // ✅ النسخة المعدلة من submitOffer لإرسال البيانات كاملة وتجنب اللفة الطويلة
  Future<void> submitOffer() async {
    if (_selectedProduct == null || ownerId == null) {
      showNotification("يرجى اختيار منتج أولاً", false);
      return;
    }
    if (_selectedUnitPrices.isEmpty) {
      showNotification("يرجى تحديد سعر لوحدة واحدة على الأقل", false);
      return;
    }

    _isLoading = true;
    notifyListeners();
    try {
      final units = _selectedUnitPrices.entries
          .map((e) => {'unitName': e.key, 'price': e.value})
          .toList();

      // إرسال البيانات بشكل مسطح (Flattened Data) لمجموعة marketOffer
      await _firestore.collection('marketOffer').add({
        'ownerId': ownerId,
        'productId': _selectedProduct!.id,
        'productName': _selectedProduct!.name, // إضافة الاسم مباشرة
        'productImage': _selectedProduct!.imageUrls.isNotEmpty 
            ? _selectedProduct!.imageUrls.first 
            : '', // إضافة رابط الصورة الأولى
        'mainCategoryId': _selectedProduct!.mainId, // معرف القسم الرئيسي
        'subCategoryId': _selectedProduct!.subId, // معرف القسم الفرعي
        'supermarketName': _supermarketName ?? 'متجر غير معروف',
        'units': units,
        'status': 'active',
        'createdAt': FieldValue.serverTimestamp(),
      });

      showNotification("تم إضافة العرض بنجاح", true);
      _selectedProduct = null;
      _selectedUnitPrices.clear();
    } catch (e) {
      showNotification("خطأ أثناء الإضافة: $e", false);
    }
    _isLoading = false;
    notifyListeners();
  }
}

