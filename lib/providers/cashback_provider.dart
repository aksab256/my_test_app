// lib/providers/cashback_provider.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../providers/buyer_data_provider.dart';

class CashbackProvider with ChangeNotifier {
  final BuyerDataProvider _buyerData;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // إضافة متغيرات داخلية لتخزين البيانات
  double _availableBalance = 0.0;
  List<Map<String, dynamic>> _offersList = [];
  bool _isLoading = false;

  // Getters للوصول للبيانات من الشاشة
  double get availableBalance => _availableBalance;
  List<Map<String, dynamic>> get offersList => _offersList;
  bool get isLoading => _isLoading;

  CashbackProvider(this._buyerData);

  Future<double> fetchCashbackBalance() async {
    final userId = _buyerData.currentUserId;
    if (userId == null) {
      _availableBalance = 0.0;
      return 0.0;
    }
    try {
      final userDoc = await _db.collection('users').doc(userId).get();
      if (userDoc.exists) {
        _availableBalance = double.tryParse((userDoc.data()?['cashback'] ?? '0').toString()) ?? 0.0;
      } else {
        _availableBalance = 0.0;
      }
      notifyListeners(); // إشعار الواجهة بتحديث الرصيد
      return _availableBalance;
    } catch (e) { 
      return 0.0; 
    }
  }

  Future<List<Map<String, dynamic>>> fetchAvailableOffers() async {
    final userId = _buyerData.currentUserId;
    if (userId == null) {
      _offersList = [];
      return [];
    }
    
    _isLoading = true;
    // لا نضع notifyListeners هنا لتجنب التعارض أثناء بناء الواجهة (build phase)
    
    try {
      final now = DateTime.now();
      final querySnapshot = await _db.collection("cashbackRules")
          .where("status", isEqualTo: "active")
          .orderBy('priority', descending: true)
          .get();

      List<Map<String, dynamic>> tempOffers = [];
      
      for (var docSnap in querySnapshot.docs) {
        final data = docSnap.data();
        
        DateTime? startDate = (data['startDate'] as Timestamp?)?.toDate();
        DateTime? endDate = (data['endDate'] as Timestamp?)?.toDate();

        if (startDate == null || endDate == null || now.isBefore(startDate) || now.isAfter(endDate)) continue;

        String targetType = data['targetType'] ?? 'none'; 
        double minAmount = double.tryParse(data['minPurchaseAmount']?.toString() ?? '0') ?? 0.0;
        double progressAmount = 0;

        if (targetType == 'cumulative_period') {
          final ordersQuery = await _db.collection("orders")
              .where("buyer.id", isEqualTo: userId)
              .where("status", isEqualTo: "delivered")
              .where("orderDate", isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
              .where("orderDate", isLessThanOrEqualTo: Timestamp.fromDate(endDate))
              .get();

          for (var order in ordersQuery.docs) {
            progressAmount += double.tryParse((order.data()['totalAmount'] ?? '0').toString()) ?? 0.0;
          }
        }

        tempOffers.add({
          'id': docSnap.id,
          'description': data['description'] ?? 'عرض كاش باك',
          'minAmount': minAmount,
          'targetType': targetType,
          'value': data['value'],
          'type': data['type'],
          'daysRemaining': endDate.difference(now).inDays,
          'currentProgress': progressAmount,
          'sellerName': data['sellerName'] ?? 'كل التجار',
        });
      }
      
      _offersList = tempOffers;
      _isLoading = false;
      notifyListeners(); // أهم سطر: يخبر الشاشة أن البيانات وصلت "الآن" حتى لو كانت الصفحة مفتوحة
      return _offersList;
    } catch (e) {
      debugPrint('Error: $e');
      _isLoading = false;
      notifyListeners();
      return [];
    }
  }
}
