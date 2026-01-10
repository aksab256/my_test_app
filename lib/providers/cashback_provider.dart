import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../providers/buyer_data_provider.dart';

class CashbackProvider with ChangeNotifier {
  final BuyerDataProvider _buyerData;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CashbackProvider(this._buyerData);

  // 1. دالة جلب الرصيد (أضفتها لتكتمل وظائف المحفظة)
  Future<double> fetchCashbackBalance() async {
    final userId = _buyerData.currentUserId;
    if (userId == null) return 0.0;
    try {
      final userDoc = await _db.collection('users').doc(userId).get();
      if (userDoc.exists) {
        final data = userDoc.data();
        if (data != null) {
          return double.tryParse((data['cashback'] ?? '0').toString()) ?? 0.0;
        }
      }
      return 0.0;
    } catch (e) {
      debugPrint('Error fetching balance: $e');
      return 0.0;
    }
  }

  // 2. الدالة التي أرسلتها أنت (بدون تغيير حرف واحد في منطقها)
  Future<List<Map<String, dynamic>>> fetchAvailableOffers() async {
    final userId = _buyerData.currentUserId;
    if (userId == null) return [];
    
    try {
      final now = DateTime.now();
      // جلب القواعد النشطة
      final querySnapshot = await _db.collection("cashbackRules")
          .where("status", isEqualTo: "active")
          .get();

      List<Map<String, dynamic>> offersList = [];
      
      for (var docSnap in querySnapshot.docs) {
        final data = docSnap.data();
        
        DateTime? startDate = (data['startDate'] as Timestamp?)?.toDate();
        DateTime? endDate = (data['endDate'] as Timestamp?)?.toDate();

        // التأكد من أن العرض ساري حالياً
        if (startDate == null || endDate == null) continue;
        if (now.isBefore(startDate) || now.isAfter(endDate)) continue;

        String goalBasis = data['goalBasis'] ?? 'cumulative_spending';
        double minAmount = double.tryParse(data['minPurchaseAmount']?.toString() ?? '0') ?? 0.0;
        
        // حساب الأيام المتبقية
        int daysRemaining = endDate.difference(now).inDays;
        
        double progressAmount = 0;
        
        // إذا كان العرض "تراكمي" فقط، نحسب ما تم شراؤه فعلياً
        if (goalBasis == 'cumulative_spending') {
          final ordersQuery = await _db.collection("orders")
              .where("buyer.id", isEqualTo: userId)
              .where("status", isEqualTo: "delivered")
              .where("orderDate", isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
              .where("orderDate", isLessThanOrEqualTo: Timestamp.fromDate(endDate))
              .get();

          for (var order in ordersQuery.docs) {
            final orderData = order.data();
            progressAmount += double.tryParse((orderData['totalAmount'] ?? orderData['total'] ?? '0').toString()) ?? 0.0;
          }
        }

        offersList.add({
          'id': docSnap.id,
          'description': data['description'] ?? 'عرض كاش باك',
          'minAmount': minAmount,
          'goalBasis': goalBasis,
          'value': data['value'],
          'type': data['type'], // percentage أو fixed
          'daysRemaining': daysRemaining,
          'currentProgress': progressAmount,
          'endDate': endDate,
          'sellerName': data['sellerName'] ?? 'كل التجار',
        });
      }
      return offersList;
    } catch (e) {
      debugPrint('Error: $e');
      return [];
    }
  }
}
