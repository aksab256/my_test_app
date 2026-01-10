import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../providers/buyer_data_provider.dart';

class CashbackProvider with ChangeNotifier {
  final BuyerDataProvider _buyerData;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CashbackProvider(this._buyerData);

  // 🎯 المسمى الأصلي كما تطلبه صفحة المحفظة
  Future<double> fetchCashbackBalance() async {
    final userId = _buyerData.currentUserId;
    if (userId == null) return 0.0;
    try {
      final userDoc = await _db.collection('users').doc(userId).get();
      if (userDoc.exists) {
        final data = userDoc.data();
        if (data != null) {
          // الحقول المتفق عليها سابقا
          return double.tryParse((data['cashback'] ?? '0').toString()) ?? 0.0;
        }
      }
      return 0.0;
    } catch (e) {
      return 0.0;
    }
  }

  // 🎯 المسمى الأصلي كما تطلبه صفحة المحفظة
  Future<List<Map<String, dynamic>>> fetchCashbackGoals() async {
    final userId = _buyerData.currentUserId;
    if (userId == null) return [];
    
    try {
      final now = DateTime.now();
      final querySnapshot = await _db.collection("cashbackRules")
          .where("status", isEqualTo: "active")
          .get();

      List<Map<String, dynamic>> goalsList = [];
      
      for (var docSnap in querySnapshot.docs) {
        final offer = docSnap.data();
        
        DateTime? startDate = (offer['startDate'] as Timestamp?)?.toDate();
        DateTime? endDate = (offer['endDate'] as Timestamp?)?.toDate();

        if (startDate == null || endDate == null) continue;
        if (now.isBefore(startDate) || now.isAfter(endDate)) continue;

        double minAmount = double.tryParse(offer['minPurchaseAmount']?.toString() ?? '0') ?? 0.0;
        String goalBasis = offer['goalBasis'] ?? 'cumulative_spending';
        
        double currentProgressAmount = 0;
        double maxOrderAmount = 0;

        final ordersQuery = await _db.collection("orders")
            .where("buyer.id", isEqualTo: userId)
            .where("status", isEqualTo: "delivered")
            .where("orderDate", isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
            .where("orderDate", isLessThanOrEqualTo: Timestamp.fromDate(endDate))
            .get();
        
        for (var orderDoc in ordersQuery.docs) {
          final orderData = orderDoc.data();
          double total = double.tryParse((orderData['totalAmount'] ?? orderData['total'] ?? '0').toString()) ?? 0.0;
          
          if (offer['appliesTo'] == 'seller' && offer['sellerId'] != null) {
            if (orderData['seller']?['id'] != offer['sellerId']) continue;
          }

          currentProgressAmount += total;
          if (total > maxOrderAmount) maxOrderAmount = total;
        }

        double finalProgressValue = (goalBasis == 'single_order') ? maxOrderAmount : currentProgressAmount;
        double progressPercentage = (minAmount > 0) ? (finalProgressValue / minAmount) * 100 : 0;

        goalsList.add({
          'id': docSnap.id,
          'title': offer['description'] ?? 'هدف كاش باك',
          'minAmount': minAmount,
          'goalBasis': goalBasis,
          'currentProgress': finalProgressValue,
          'progressPercentage': progressPercentage > 100 ? 100.0 : progressPercentage,
          'endDate': endDate,
          'value': offer['value'],
          'type': offer['type'],
          'sellerName': offer['sellerName'] ?? 'كل التجار',
        });
      }
      return goalsList;
    } catch (e) {
      return [];
    }
  }
}
