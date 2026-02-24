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
  String _planName = 'باقة تجريبية'; 

  // 🏠 الموقع الثابت (المسجل في الحساب)
  double? _userLat;
  double? _userLng;
  String? _userAddress; 

  // 📍 الموقع المؤقت (للجلسة الحالية فقط - GPS)
  double? _sessionLat;
  double? _sessionLng;
  String? _sessionAddress;

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

  // --- Getters ---
  String get userName => _userName;
  LoggedInUser? get loggedInUser => _loggedInUser;
  String get planName => _planName; 

  // الـ Getters الأصلية للعنوان الثابت
  double? get userLat => _userLat;
  double? get userLng => _userLng;
  String? get userAddress => _userAddress; 

  // 🎯 الـ Getters الذكية (تستخدم الموقع المؤقت إذا وجد، وإلا الثابت)
  double? get effectiveLat => _sessionLat ?? _userLat;
  double? get effectiveLng => _sessionLng ?? _userLng;
  String? get effectiveAddress => _sessionAddress ?? _userAddress;
  bool get isUsingSessionLocation => _sessionLat != null;

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

  // --- Functions ---

  /// تحديث الموقع المؤقت للجلسة الحالية (لا يحفظ في Firestore أو Local)
  void setSessionLocation({required double lat, required double lng, String? address}) {
    _sessionLat = lat;
    _sessionLng = lng;
    if (address != null) _sessionAddress = address;
    notifyListeners();
  }

  /// مسح الموقع المؤقت والعودة للعنوان الثابت (للأمان)
  void clearSessionLocation() {
    _sessionLat = null;
    _sessionLng = null;
    _sessionAddress = null;
    notifyListeners();
  }

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
      clearSessionLocation(); // تأمين إضافي عند الخروج
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

  void updatePlan(String newPlan) {
    _planName = newPlan;
    notifyListeners();
  }

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
          if(docData.containsKey('planName')) _planName = docData['planName'];
          return;
        }
      }
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
