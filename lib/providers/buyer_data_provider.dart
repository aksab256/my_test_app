// lib/providers/buyer_data_provider.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// ⭐️ [إضافة]: استيراد المكتبات اللازمة لقراءة SharedPreferences
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:my_test_app/models/logged_user.dart';   

// ---------------------------------------------------------------------
// تعريفات النماذج (Models)
// ---------------------------------------------------------------------
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

// ---------------------------------------------------------------------
// Buyer Data Provider
// ---------------------------------------------------------------------
class BuyerDataProvider with ChangeNotifier {

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ⭐️ المتغيرات الخاصة (Private Fields) ⭐️
  String _userName = 'مرحباً بك!';
  LoggedInUser? _loggedInUser;
  String? _userId;

  // 🟢 [إضافة]: متغيرات الموقع المفقودة لحل أخطاء البحث 🟢
  double? _userLat;
  double? _userLng;

  // ⭐️⭐️ متغير الدور (يستخدم الآن كـ userClassification) ⭐️⭐️
  String _userRole = 'buyer';
  bool _deliveryIsActive = false;
  int _newOrdersCount = 0;
  int _cartCount = 0;
  bool _ordersChanged = false;
  List<Category> _categories = [];
  List<BannerItem> _banners = [];
  bool _isLoading = false;
  String? _errorMessage;

  // ⭐️ متغيرات حالة ظهور روابط الدليفري ⭐️
  bool _deliverySettingsAvailable = false;
  bool _deliveryPricesAvailable = false;

  // ⭐️ Getters للسماح للـ Widgets بالوصول إلى الحالة ⭐️
  String get userName => _userName;
  LoggedInUser? get loggedInUser => _loggedInUser;

  // 🟢 [إضافة]: Getters لموقع المستخدم 🟢
  double? get userLat => _userLat;
  double? get userLng => _userLng;

  String? get currentUserId => _userId;
  String get userClassification => _userRole; // نستخدم _userRole كتصنيف

  // ⭐️ Getter الدور ⭐️
  String get userRole => _userRole;
  bool get deliveryIsActive => _deliveryIsActive;
  int get newOrdersCount => _newOrdersCount;
  int get cartCount => _cartCount;
  bool get ordersChanged => _ordersChanged;
  List<Category> get categories => _categories;
  List<BannerItem> get banners => _banners;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // ⭐️ Getters لروابط الدليفري ⭐️
  bool get deliverySettingsAvailable => _deliverySettingsAvailable;
  bool get deliveryPricesAvailable => _deliveryPricesAvailable;

  // ⭐️ دالة التهيئة والتحميل الرئيسية ⭐️
  Future<void> initializeData(String? currentUserId, String? currentDealerId, String? fullName) async {
    _isLoading = true;
    _errorMessage = null;
    _userId = currentUserId;

    // ⭐️⭐️ تعيين قيمة لـ _loggedInUser والـ userName ⭐️⭐️
    if (currentUserId != null && fullName != null) {
      _loggedInUser = LoggedInUser(id: currentUserId, fullname: fullName, role: _userRole);
      _userName = 'أهلاً بك، $fullName!';

      // 💡 [التعديل]: قراءة الموقع الموحد من SharedPreferences 💡
      try {
          final prefs = await SharedPreferences.getInstance();
          // المفتاح المستخدم للتخزين من قبل AuthService
          final userDataJson = prefs.getString('loggedUser');

          if (userDataJson != null) {
              final userData = json.decode(userDataJson);

              // البحث عن مفتاح 'location' الموحد
              final locationData = userData['location'];

              if (locationData is Map) {
                 // التحقق من القيم والأصناف (locationData['lat'] يمكن أن تكون int أو double)
                 final lat = locationData['lat'] is num ? (locationData['lat'] as num).toDouble() : null;
                 final lng = locationData['lng'] is num ? (locationData['lng'] as num).toDouble() : null;

                 _userLat = lat;
                 _userLng = lng;

                 print('BuyerDataProvider: Loaded Lat: $_userLat, Lng: $_userLng from SharedPreferences');
              } else {
                 _userLat = null;
                 _userLng = null;
              }
          }
      } catch (e) {
          print('Error loading user location from SharedPreferences: $e');
          _userLat = null;
          _userLng = null;
      }

    } else {
      _loggedInUser = null;
      _userName = 'مرحباً بك!';
      _userLat = null;
      _userLng = null;
    }

    notifyListeners(); // إظهار بيانات المستخدم الأساسية والموقع مبكراً

    // تشغيل جميع وظائف جلب الحالة بناءً على منطق HTML/JS الأصلي
    _updateCartCountFromLocal();
    await _checkDeliveryStatusAndDisplayIcons(currentDealerId);
    await _updateNewDealerOrdersCount(currentDealerId);
    await _monitorUserOrdersStatusChanges(currentUserId);
    await _loadCategoriesAndBanners();

    _isLoading = false;
    notifyListeners();
  }

  // 🛠️ ---------------------------------------------
  // 🛠️ الدوال المساعدة (مطابقة لمنطق الـ HTML/JS)
  // 🛠️ ---------------------------------------------
  // 🛠️ محاكاة لوظيفة updateCartCount
  void _updateCartCountFromLocal() {
    _cartCount = 3;
    // لا نحتاج لـ notifyListeners هنا إذا كانت ستحدث في نهاية initializeData
  }


  // 🛠️ دالة checkDeliveryStatusAndDisplayIcons
  Future<void> _checkDeliveryStatusAndDisplayIcons(String? currentDealerId) async {

    _deliverySettingsAvailable = false;
    _deliveryPricesAvailable = false;
    _deliveryIsActive = false;

    if (currentDealerId == null || currentDealerId.isEmpty) { return; }

    try {
      // 💡 ملاحظة: الاعتماد على الثوابت المحفوظة (deliverySupermarkets)
      final approvedQ = await _firestore.collection('deliverySupermarkets')
          .where("ownerId", isEqualTo: currentDealerId).get();

      if (approvedQ.docs.isNotEmpty) {
        final docData = approvedQ.docs[0].data();
        if (docData['isActive'] == true) {
          _deliveryPricesAvailable = true;
          _deliveryIsActive = true;
          return;
        } else {
          _deliveryIsActive = false;
          return;
        }
      }

      final pendingQ = await _firestore.collection('pendingSupermarkets')
          .where("ownerId", isEqualTo: currentDealerId).get();

      if (!pendingQ.docs.isEmpty) {
        _deliveryIsActive = false;
        return;
      }

      _deliverySettingsAvailable = true;
      _deliveryIsActive = false;

    } catch (e) {
      print('Delivery Status Error: $e');
      _deliveryIsActive = false;
    }
    // notifyListeners() يتم استدعاؤه في نهاية initializeData، يمكن حذفه هنا لتجنب التكرار
  }

  // 🛠️ دالة updateNewDealerOrdersCount
  Future<void> _updateNewDealerOrdersCount(String? currentDealerId) async {
    if (currentDealerId == null || currentDealerId.isEmpty || !_deliveryIsActive) {
      _newOrdersCount = 0;
      // notifyListeners(); // يمكن حذفه
      return;
    }
    try {
      final ordersQ = await _firestore.collection('consumerorders')
          .where("supermarketId", isEqualTo: currentDealerId)
          .where("status", isEqualTo: "new-order").get();

      _newOrdersCount = ordersQ.docs.length;
    } catch (e) {
      print('New Orders Count Error: $e');
      _newOrdersCount = 0;
    }
    // notifyListeners(); // يمكن حذفه
  }

  // 🛠️ دالة monitorUserOrdersStatusChanges
  Future<void> _monitorUserOrdersStatusChanges(String? currentUserId) async {
    if (currentUserId == null || currentUserId.isEmpty) { return; }

    try {
      // لا تحتاج فعلياً للحصول على البيانات، يكفي التحقق من التغير أو جلبها
      final querySnapshot = await _firestore.collection('consumerorders')
          .where("userId", isEqualTo: currentUserId)
          .orderBy("orderDate", descending: true)
          .get();
      _ordersChanged = true;

    } catch (e) {
      print('Monitor Orders Error: $e');
      _ordersChanged = false;
    }
    // notifyListeners(); // يمكن حذفه
  }

  // 🛠️ دالة loadCategoriesAndBanners
  Future<void> _loadCategoriesAndBanners() async {
    try {
      // 1. جلب الأقسام (mainCategory)
      final categoriesQuery = _firestore
          .collection('mainCategory')
          .where('status', isEqualTo: 'active')
          .orderBy('order', descending: false);

      final categoriesSnapshot = await categoriesQuery.get();

      _categories = categoriesSnapshot.docs.map((doc) {
        final data = doc.data();
        return Category(
          id: doc.id,
          name: data['name'] ?? 'قسم غير مسمى',
          imageUrl: data['imageUrl'] ?? '',
        );
      }).toList();

      // 2. جلب الإعلانات (retailerBanners)
      final bannersQuery = _firestore
          .collection('retailerBanners')
          .where('status', isEqualTo: 'active')
          .orderBy('order', descending: false);

      final bannersSnapshot = await bannersQuery.get();

      _banners = bannersSnapshot.docs.map((doc) {
        final data = doc.data();
        return BannerItem(
          id: doc.id,
          name: data['name'] ?? 'إعلان',
          imageUrl: data['imageUrl'] ?? '',
          link: data['link'],
        );
      }).toList();

    } catch (e) {
      _errorMessage = 'فشل في تحميل البيانات: $e';
      _categories = [];
      _banners = [];
      print('Firebase Load Error: $e');
    }
    // notifyListeners(); // يمكن حذفه
  }
}
