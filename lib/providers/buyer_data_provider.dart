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

  double? _userLat;
  double? _userLng;
  // 🟢 [إضافة]: المتغير النصي للعنوان لإصلاح خطأ الـ Build والـ UI
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

  double? get userLat => _userLat;
  double? get userLng => _userLng;
  // 🟢 [إضافة]: Getter العنوان الذي تستخدمه شاشة البحث (الرادار)
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
                 final lat = locationData['lat'] is num ? (locationData['lat'] as num).toDouble() : null;
                 final lng = locationData['lng'] is num ? (locationData['lng'] as num).toDouble() : null;

                 _userLat = lat;
                 _userLng = lng;
                 
                 // 🟢 [تعديل]: استخراج نص العنوان من الحقول المحتملة في الـ JSON
                 _userAddress = locationData['address']?.toString() ?? 
                                locationData['addressName']?.toString() ?? 
                                userData['address']?.toString();

                 print('BuyerDataProvider: Loaded Lat: $_userLat, Lng: $_userLng, Address: $_userAddress');
              } else {
                 _userLat = null; _userLng = null; _userAddress = null;
              }
          }
      } catch (e) {
          print('Error loading user location: $e');
          _userLat = null; _userLng = null; _userAddress = null;
      }

    } else {
      _loggedInUser = null;
      _userName = 'مرحباً بك!';
      _userLat = null; _userLng = null; _userAddress = null;
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

  void _updateCartCountFromLocal() {
    _cartCount = 3;
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
          return;
        }
      }

      final pendingQ = await _firestore.collection('pendingSupermarkets')
          .where("ownerId", isEqualTo: currentDealerId).get();

      if (pendingQ.docs.isEmpty) {
        _deliverySettingsAvailable = true;
      }
    } catch (e) {
      print('Delivery Status Error: $e');
    }
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
    } catch (e) {
      _newOrdersCount = 0;
    }
  }

  Future<void> _monitorUserOrdersStatusChanges(String? currentUserId) async {
    if (currentUserId == null || currentUserId.isEmpty) return;
    _ordersChanged = true;
  }

  Future<void> _loadCategoriesAndBanners() async {
    try {
      final categoriesSnapshot = await _firestore
          .collection('mainCategory')
          .where('status', isEqualTo: 'active')
          .orderBy('order', descending: false).get();

      _categories = categoriesSnapshot.docs.map((doc) {
        final data = doc.data();
        return Category(id: doc.id, name: data['name'] ?? 'قسم غير مسمى', imageUrl: data['imageUrl'] ?? '');
      }).toList();

      final bannersSnapshot = await _firestore
          .collection('retailerBanners')
          .where('status', isEqualTo: 'active')
          .orderBy('order', descending: false).get();

      _banners = bannersSnapshot.docs.map((doc) {
        final data = doc.data();
        return BannerItem(id: doc.id, name: data['name'] ?? 'إعلان', imageUrl: data['imageUrl'] ?? '', link: data['link']);
      }).toList();
    } catch (e) {
      _errorMessage = 'فشل في تحميل البيانات: $e';
    }
  }
}
