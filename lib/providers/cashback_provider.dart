import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../providers/buyer_data_provider.dart';

class CashbackProvider with ChangeNotifier {
  final BuyerDataProvider _buyerData;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CashbackProvider(this._buyerData);

  /// جلب رصيد الكاش باك الحالي للمستخدم
  Future<double> fetchCashbackBalance() async {
    final userId = _buyerData.currentUserId;
    if (userId == null) return 0.0;
    try {
      final userDoc = await _db.collection('users').doc(userId).get();
      if (userDoc.exists) {
        // تحويل القيمة لـ double بشكل آمن
        final data = userDoc.data();
        if (data != null && data.containsKey('cashback')) {
          return double.tryParse(data['cashback'].toString()) ?? 0.0;
        }
      }
      return 0.0;
    } catch (e) {
      debugPrint('Error fetching cashback balance: $e');
      return 0.0;
    }
  }

  /// جلب أهداف الكاش باك النشطة وحساب التقدم المحرز فيها
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
        
        // تحويل الـ Timestamp لـ DateTime
        final startDate = (offer['startDate'] as Timestamp).toDate();
        final endDate = (offer['endDate'] as Timestamp).toDate();

        // التأكد من أن العرض ساري حالياً
        if (now.isBefore(startDate) || now.isAfter(endDate)) continue;

        double minAmount = (offer['minPurchaseAmount'] ?? 0).toDouble();
        String goalBasis = offer['goalBasis'] ?? 'cumulative_spending';
        double currentProgressAmount = 0;
        double maxOrderAmount = 0;

        // جلب الطلبات المكتملة في فترة العرض
        Query ordersQuery = _db.collection("orders")
            .where("buyer.id", isEqualTo: userId)
            .where("status", isEqualTo: "delivered")
            .where("orderDate", isGreaterThanOrEqualTo: startDate)
            .where("orderDate", isLessThanOrEqualTo: endDate);

        // إذا كان العرض مخصص لتاجر معين
        if (offer['appliesTo'] == 'seller' && offer['sellerId'] != null) {
          ordersQuery = ordersQuery.where("seller.id", isEqualTo: offer['sellerId']);
        }

        final ordersSnapshot = await ordersQuery.get();
        
        for (var orderDoc in ordersSnapshot.docs) {
          final orderData = orderDoc.data() as Map<String, dynamic>;
          double total = (orderData['totalAmount'] ?? orderData['total'] ?? 0).toDouble();
          currentProgressAmount += total;
          if (total > maxOrderAmount) maxOrderAmount = total;
        }

        // تحديد قيمة التقدم بناءً على نوع الهدف (تراكمي أم طلب واحد)
        double finalProgressValue = (goalBasis == 'single_order') ? maxOrderAmount : currentProgressAmount;
        
        // حساب النسبة المئوية
        double progressPercentage = (minAmount > 0) ? (finalProgressValue / minAmount) * 100 : 0;
        if (progressPercentage > 100) progressPercentage = 100;

        goalsList.add({
          'id': docSnap.id,
          'title': offer['description'] ?? 'هدف كاش باك',
          'minAmount': minAmount,
          'currentProgress': finalProgressValue,
          'progressPercentage': progressPercentage,
          'endDate': endDate,
          'value': offer['value'], // القيمة التي سيحصل عليها (مثلاً 50 ج)
          'type': offer['type'],   // نوع المكافأة (fixed_amount)
        });
      }
      return goalsList;
    } catch (e) {
      debugPrint('Error fetching cashback goals: $e');
      return [];
    }
  }
}
