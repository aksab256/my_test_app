// lib/providers/buyer_data_provider.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:my_test_app/models/logged_user.dart';   

class Category {
  final String id;
  final String name;
  final String imageUrl;
  Category({required this.id, required this.name, required this.imageUrl});
}

class BannerItem {
  final String id;
  final String name;
  final String imageUrl;
  final String? link;
  BannerItem({required this.id, required this.name, required this.imageUrl, this.link});
}

class BuyerDataProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String _userName = 'مرحباً بك!';
  LoggedInUser? _loggedInUser;
  String? _userId;
  String _planName = 'باقة تجريبية'; // ✨ [إضافة] لتجنب خطأ الـ Build

  double? _userLat;
  double? _userLng;
  String? _userAddress; 

  String _userRole = 'buyer';
  bool _deliveryIsActive = false;
  int _newOrdersCount = 0;
  int _cartCount = 0;
  bool _ordersChanged = false;
  List<Category> _categories = [];
  List<BannerItem> _banners = [];
  bool _isLoading = false;
  String? _errorMessage;

  bool _deliverySettingsAvailable = false;
  bool _deliveryPricesAvailable = false;

  String get userName => _userName;
  LoggedInUser? get loggedInUser => _loggedInUser;
  String get planName => _planName; // ✨ [إضافة] Getter اللازم للداش بورد

  double? get userLat => _userLat;
  double? get userLng => _userLng;
  String? get userAddress => _userAddress; 

  String? get currentUserId => _userId;
  String get userClassification => _userRole;
  String get userRole => _userRole;
  bool get deliveryIsActive => _deliveryIsActive;
  int get newOrdersCount => _newOrdersCount;
  int get cartCount => _cartCount;
  bool get ordersChanged => _ordersChanged;
  List<Category> get categories => _categories;
  List<BannerItem> get banners => _banners;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  bool get deliverySettingsAvailable => _deliverySettingsAvailable;
  bool get deliveryPricesAvailable => _deliveryPricesAvailable;

  Future<void> initializeData(String? currentUserId, String? currentDealerId, String? fullName) async {
    _isLoading = true;
    _errorMessage = null;
    _userId = currentUserId;

    if (currentUserId != null && fullName != null) {
      _loggedInUser = LoggedInUser(id: currentUserId, fullname: fullName, role: _userRole);
      _userName = 'أهلاً بك، $fullName!';

      try {
          final prefs = await SharedPreferences.getInstance();
          final userDataJson = prefs.getString('loggedUser');

          if (userDataJson != null) {
              final userData = json.decode(userDataJson);
              final locationData = userData['location'];

              if (locationData is Map) {
                 _userLat = locationData['lat'] is num ? (locationData['lat'] as num).toDouble() : null;
                 _userLng = locationData['lng'] is num ? (locationData['lng'] as num).toDouble() : null;
                 _userAddress = locationData['address']?.toString() ?? 
                                locationData['addressName']?.toString() ?? 
                                userData['address']?.toString();
              }
              // ✨ [إضافة] تحديث اسم الخطة لو موجود في الـ Local Storage
              if (userData.containsKey('planName')) {
                _planName = userData['planName'];
              }
          }
      } catch (e) {
          debugPrint('Error loading user location: $e');
      }

    } else {
      _loggedInUser = null;
      _userName = 'مرحباً بك!';
    }

    notifyListeners();

    _updateCartCountFromLocal();
    await _checkDeliveryStatusAndDisplayIcons(currentDealerId);
    await _updateNewDealerOrdersCount(currentDealerId);
    await _monitorUserOrdersStatusChanges(currentUserId);
    await _loadCategoriesAndBanners();

    _isLoading = false;
    notifyListeners();
  }

  // ✨ [إضافة] دالة لتحديث الخطة ديناميكياً من أي مكان
  void updatePlan(String newPlan) {
    _planName = newPlan;
    notifyListeners();
  }

  // ... بقية الدوال (_checkDeliveryStatusAndDisplayIcons, إلخ) كما هي في ملفك الأصلي
  Future<void> _checkDeliveryStatusAndDisplayIcons(String? currentDealerId) async {
    _deliverySettingsAvailable = false;
    _deliveryPricesAvailable = false;
    _deliveryIsActive = false;
    if (currentDealerId == null || currentDealerId.isEmpty) return;

    try {
      final approvedQ = await _firestore.collection('deliverySupermarkets')
          .where("ownerId", isEqualTo: currentDealerId).get();

      if (approvedQ.docs.isNotEmpty) {
        final docData = approvedQ.docs[0].data();
        if (docData['isActive'] == true) {
          _deliveryPricesAvailable = true;
          _deliveryIsActive = true;
          // تحديث الخطة من الداتا لو موجودة
          if(docData.containsKey('planName')) _planName = docData['planName'];
          return;
        }
      }
      // ... بقية الكود
    } catch (e) { print(e); }
  }

  Future<void> _updateNewDealerOrdersCount(String? currentDealerId) async {
     if (currentDealerId == null || currentDealerId.isEmpty || !_deliveryIsActive) {
      _newOrdersCount = 0;
      return;
    }
    try {
      final ordersQ = await _firestore.collection('consumerorders')
          .where("supermarketId", isEqualTo: currentDealerId)
          .where("status", isEqualTo: "new-order").get();
      _newOrdersCount = ordersQ.docs.length;
    } catch (e) { _newOrdersCount = 0; }
  }

  Future<void> _monitorUserOrdersStatusChanges(String? currentUserId) async {
    if (currentUserId == null || currentUserId.isEmpty) return;
    _ordersChanged = true;
  }

  Future<void> _loadCategoriesAndBanners() async {
    try {
      final categoriesSnapshot = await _firestore.collection('mainCategory').where('status', isEqualTo: 'active').orderBy('order', descending: false).get();
      _categories = categoriesSnapshot.docs.map((doc) => Category(id: doc.id, name: doc.data()['name'] ?? '', imageUrl: doc.data()['imageUrl'] ?? '')).toList();
      
      final bannersSnapshot = await _firestore.collection('retailerBanners').where('status', isEqualTo: 'active').orderBy('order', descending: false).get();
      _banners = bannersSnapshot.docs.map((doc) => BannerItem(id: doc.id, name: doc.data()['name'] ?? '', imageUrl: doc.data()['imageUrl'] ?? '', link: doc.data()['link'])).toList();
    } catch (e) { _errorMessage = e.toString(); }
  }

  void _updateCartCountFromLocal() { _cartCount = 3; }
}
