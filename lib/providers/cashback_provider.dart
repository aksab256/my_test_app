import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../providers/buyer_data_provider.dart';

class CashbackProvider with ChangeNotifier {
  final BuyerDataProvider _buyerData;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CashbackProvider(this._buyerData);

  // إصلاح 1: إعادة رصيد الكاش باك
  Future<double> fetchCashbackBalance() async {
    final userId = _buyerData.currentUserId;
    if (userId == null) return 0.0;
    try {
      final userDoc = await _db.collection('users').doc(userId).get();
      if (userDoc.exists) {
        final data = userDoc.data();
        return double.tryParse((data?['cashback'] ?? '0').toString()) ?? 0.0;
      }
      return 0.0;
    } catch (e) {
      return 0.0;
    }
  }

  // إصلاح 2: جلب العروض مع تمييز دقيق للنوع
  Future<List<Map<String, dynamic>>> fetchAvailableOffers() async {
    final userId = _buyerData.currentUserId;
    if (userId == null) return [];
    
    try {
      final now = DateTime.now();
      final querySnapshot = await _db.collection("cashbackRules")
          .where("status", isEqualTo: "active")
          .get();

      List<Map<String, dynamic>> offersList = [];
      
      for (var docSnap in querySnapshot.docs) {
        final data = docSnap.data();
        DateTime? startDate = (data['startDate'] as Timestamp?)?.toDate();
        DateTime? endDate = (data['endDate'] as Timestamp?)?.toDate();

        if (startDate == null || endDate == null || now.isBefore(startDate) || now.isAfter(endDate)) continue;

        String goalBasis = data['goalBasis'] ?? 'cumulative_spending';
        double minAmount = double.tryParse(data['minPurchaseAmount']?.toString() ?? '0') ?? 0.0;
        double progressAmount = 0;

        // حساب التقدم فقط إذا كان تراكمياً
        if (goalBasis == 'cumulative_spending') {
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

        offersList.add({
          'id': docSnap.id,
          'description': data['description'] ?? 'عرض كاش باك',
          'minAmount': minAmount,
          'goalBasis': goalBasis, // التأكد من إرسال النوع الصحيح للشاشة
          'value': data['value'],
          'type': data['type'],
          'daysRemaining': endDate.difference(now).inDays,
          'currentProgress': progressAmount,
          'sellerName': data['sellerName'] ?? 'كل التجار',
        });
      }
      return offersList;
    } catch (e) {
      return [];
    }
  }
}
