// lib/providers/product_offer_provider.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:my_test_app/models/product_offer.dart'; 
import '../models/category_model.dart'; 
import 'buyer_data_provider.dart';

// --- نموذج بيانات الكتالوج ---
class CatalogProductModel {
  final String id;
  final String name;
  final String description;
  final List<String> imageUrls;
  final List<Map<String, dynamic>> units;
  final String mainId;
  final String subId;

  CatalogProductModel({
    required this.id, required this.name, required this.description,
    required this.imageUrls, required this.units, required this.mainId, required this.subId,
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

  // الحالة (State)
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

  // Getters
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

  // 1. دالة تهيئة البيانات (حل الخطأ الأول)
  Future<void> initializeData(String ownerId) async {
    _isLoading = true;
    notifyListeners();
    try {
      final q = await _firestore.collection('deliverySupermarkets')
          .where('ownerId', isEqualTo: ownerId).limit(1).get();
      if (q.docs.isNotEmpty) {
        _supermarketName = q.docs.first.data()['supermarketName'];
      }
    } catch (e) {
      debugPrint("Init Error: $e");
    }
    _isLoading = false;
    notifyListeners();
  }

  // 2. دالة جلب العروض (حل الخطأ الثاني)
  Future<void> fetchOffers(String ownerId) async {
    _isLoading = true;
    _offers = [];
    notifyListeners();
    try {
      final snap = await _firestore.collection('marketOffer')
          .where('ownerId', isEqualTo: ownerId).get();

      List<ProductOffer> fetched = [];
      for (var doc in snap.docs) {
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

  // 3. دالة الحذف (حل الخطأ الثالث)
  Future<void> deleteOffer(String offerId) async {
    await _firestore.collection('marketOffer').doc(offerId).delete();
    _offers.removeWhere((o) => o.id == offerId);
    notifyListeners();
  }

  // 4. دالة تحديث السعر (حل الخطأ الرابع)
  Future<void> updateUnitPrice({required String offerId, required int unitIndex, required double newPrice}) async {
    final offer = _offers.firstWhere((o) => o.id == offerId);
    final updatedUnits = offer.units.map((u) => u.toMap()).toList();
    updatedUnits[unitIndex]['price'] = newPrice;

    await _firestore.collection('marketOffer').doc(offerId).update({'units': updatedUnits});
    await fetchOffers(ownerId!); // تحديث القائمة
  }

  // --- دوال الكتالوج والإضافة ---
  void setSelectedMainCategory(String? id) {
    _selectedMainId = id; _selectedSubId = null;
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
    notifyListeners();
  }

  void setSelectedUnitPrice(String name, double? price) {
    if (price != null) _selectedUnitPrices[name] = price;
    else _selectedUnitPrices.remove(name);
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
    final q = await _firestore.collection('products').where('subId', isEqualTo: _selectedSubId).get();
    _searchResults = q.docs.map((doc) => CatalogProductModel.fromFirestore(doc)).toList();
    notifyListeners();
  }

  Future<void> submitOffer() async {
    if (_selectedProduct == null || ownerId == null) return;
    final units = _selectedUnitPrices.entries.map((e) => {'unitName': e.key, 'price': e.value}).toList();
    await _firestore.collection('marketOffer').add({
      'ownerId': ownerId,
      'productId': _selectedProduct!.id,
      'supermarketName': _supermarketName ?? 'متجر',
      'units': units,
      'status': 'active',
      'createdAt': FieldValue.serverTimestamp(),
    });
    _selectedProduct = null;
    _selectedUnitPrices.clear();
    notifyListeners();
  }
}
