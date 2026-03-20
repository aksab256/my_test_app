// lib/controllers/seller_dashboard_controller.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:my_test_app/models/seller_dashboard_data.dart';
import 'package:my_test_app/screens/login_screen.dart';
import 'package:my_test_app/models/delivery_area_model.dart';
import 'package:my_test_app/data_sources/delivery_area_data_source.dart';

class SellerDashboardController with ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DeliveryAreaDataSource _deliveryAreaDataSource = DeliveryAreaDataSource();

  SellerDashboardData _data = SellerDashboardData.loading();
  List<DeliveryAreaModel> _deliveryAreas = [];
  bool _isLoading = true;
  String? _errorMessage;
  String? _sellerName;
  String? _accountStatus; // ✅ إضافة متغير لحفظ حالة الحساب
  Map<String, dynamic>? _sellerData;

  // Getters
  SellerDashboardData get data => _data;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String get welcomeMessage => 'مرحبًا بك يا ${_sellerName ?? 'بائع'} في لوحة تحكم البائع';
  List<DeliveryAreaModel> get deliveryAreas => _deliveryAreas;
  String get sellerId => _auth.currentUser?.uid ?? '';
  Map<String, dynamic>? get sellerData => _sellerData;

  Future<void> fetchSellerData() async {
    final user = _auth.currentUser;
    if (user == null) return;
    try {
      final userDoc = await _db.collection("sellers").doc(user.uid).get();
      if (userDoc.exists) {
        _sellerData = userDoc.data();
        _sellerName = _sellerData?['fullname'] as String?;
        // ✅ جلب حالة الحساب من الفايربيز (status)
        _accountStatus = _sellerData?['status'] as String? ?? 'inactive';
      }
    } catch (e) {
      debugPrint('🚨 Error fetching seller data: $e');
    }
  }

  Future<void> loadDashboardData(String sId) async {
    final targetId = sId.isNotEmpty ? sId : sellerId;
    if (targetId.isEmpty) {
      _isLoading = false;
      notifyListeners();
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // 1. جلب بيانات البائع الأساسية (بما فيها الحالة)
      await fetchSellerData();

      // 2. جلب الطلبات من المجموعتين بالتوازي لسرعة الأداء
      final results = await Future.wait([
        _db.collection("orders").where("sellerId", isEqualTo: targetId).get(),
        _db.collection("consumerorders").where("supermarketId", isEqualTo: targetId).get(),
      ]);

      int totalOrders = 0;
      double completedSales = 0.0;
      int pendingOrders = 0;
      int newOrders = 0;

      for (var snapshot in results) {
        for (var doc in snapshot.docs) {
          final orderData = doc.data();
          totalOrders++;

          final status = orderData['status']?.toString().toLowerCase().trim() ?? '';

          if (status == 'delivered' || status == 'تم التوصيل') {
            completedSales += (orderData['total'] is num) ? (orderData['total'] as num).toDouble() : 0.0;
          } else {
            const cancelledStatuses = {'ملغى', 'cancelled', 'rejected', 'failed'};
            if (!cancelledStatuses.contains(status)) {
              pendingOrders++;
            }
          }

          if (status == 'new-order' || status == 'جديد' || status == 'new') {
            newOrders++;
          }
        }
      }

      // 3. تحديث البيانات النهائية للكروت مع إضافة حقل الـ status
      _data = SellerDashboardData(
        totalOrders: totalOrders,
        completedSalesAmount: completedSales,
        pendingOrdersCount: pendingOrders,
        newOrdersCount: newOrders,
        sellerName: _sellerName ?? 'المورد',
        status: _accountStatus ?? 'inactive', // ✅ تمرير الحالة للموديل
      );

    } on FirebaseException catch (e) {
      _errorMessage = 'خطأ في قاعدة البيانات: ${e.message}';
    } catch (e) {
      _errorMessage = 'حدث خطأ غير متوقع.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _signOutAndRedirect(BuildContext context, String message) async {
    await _auth.signOut();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    Navigator.of(context).pushNamedAndRemoveUntil(LoginScreen.routeName, (route) => false);
  }

  Future<void> logout(BuildContext context) async {
    try {
      await _auth.signOut();
      _signOutAndRedirect(context, "تم تسجيل الخروج بنجاح.");
    } catch (e) {
      debugPrint("🚨 Error signing out: $e");
    }
  }
}
