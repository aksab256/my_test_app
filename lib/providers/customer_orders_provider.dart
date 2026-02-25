// lib/providers/customer_orders_provider.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/consumer_order_model.dart';
import '../constants/constants.dart';
import 'buyer_data_provider.dart';

class CustomerOrdersProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final BuyerDataProvider _buyerData;

  bool _isLoading = false;
  String? _message;
  bool _isSuccess = true;
  List<ConsumerOrderModel> _orders = [];

  // ✅ إضافة اشتراك للتحكم في تدفق البيانات اللحظي
  StreamSubscription<QuerySnapshot>? _ordersSubscription;

  // Getters
  bool get isLoading => _isLoading;
  String? get message => _message;
  bool get isSuccess => _isSuccess;
  List<ConsumerOrderModel> get orders => _orders;

  CustomerOrdersProvider(this._buyerData) {
    // البدء بالاستماع فور تهيئة الـ Provider
    listenToOrdersForBuyer();
  }

  void showNotification(String msg, bool success) {
    _message = msg;
    _isSuccess = success;
    notifyListeners();
  }

  void clearNotification() {
    _message = null;
    notifyListeners();
  }

  // ------------------------------------
  // ✅ وظيفة الاستماع اللحظي (Stream)
  // ------------------------------------
  void listenToOrdersForBuyer() {
    final buyerId = _buyerData.loggedInUser?.id;

    if (buyerId == null || buyerId.isEmpty) {
      debugPrint("⚠️ No logged-in buyer ID found for streaming orders.");
      return;
    }

    _isLoading = true;
    notifyListeners();

    // إلغاء أي اشتراك قديم لتجنب تكرار البيانات أو تسريب الذاكرة
    _ordersSubscription?.cancel();

    try {
      // ✅ مراقبة مجموعة consumerorders لحظة بلحظة
      _ordersSubscription = _firestore
          .collection(CONSUMER_ORDERS_COLLECTION) // 'consumerorders'
          .where("supermarketId", isEqualTo: buyerId)
          .orderBy('orderDate', descending: true)
          .snapshots()
          .listen((querySnapshot) {
        
        if (querySnapshot.docs.isEmpty) {
          _orders = [];
          _message = 'لا توجد طلبات عملاء حاليًا.';
        } else {
          _orders = querySnapshot.docs.map((doc) {
            try {
              return ConsumerOrderModel.fromFirestore(doc);
            } catch (e) {
              debugPrint("🚨 Error parsing order ${doc.id}: $e");
              return null;
            }
          }).whereType<ConsumerOrderModel>().toList();
          
          _message = null;
        }

        _isLoading = false;
        _isSuccess = true;
        notifyListeners(); // 🚀 سيؤدي هذا لتحديث شاشة الطلبات والزر فوراً
      }, onError: (error) {
        debugPrint("❌ Stream Error: $error");
        _isLoading = false;
        _message = "حدث خطأ أثناء مزامنة البيانات.";
        _isSuccess = false;
        notifyListeners();
      });
    } catch (e) {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ------------------------------------
  // تحديث حالة الطلب
  // ------------------------------------
  Future<void> updateOrderStatus(String orderDocId, String newStatus) async {
    // البحث عن الطلب في القائمة المحلية للتأكد من وجوده
    final orderIndex = _orders.indexWhere((o) => o.id == orderDocId);
    if (orderIndex == -1) return;

    final orderToUpdate = _orders[orderIndex];
    
    if (orderToUpdate.status == 'delivered' || orderToUpdate.status == 'cancelled') {
      showNotification('لا يمكن تعديل طلب منتهي.', false);
      return;
    }

    try {
      await _firestore
          .collection(CONSUMER_ORDERS_COLLECTION)
          .doc(orderDocId)
          .update({
        'status': newStatus,
        'lastUpdated': FieldValue.serverTimestamp(),
      });
      // ملاحظة: لا حاجة لتحديث القائمة يدوياً هنا لأن الـ Stream سيقوم بذلك فوراً
      showNotification('تم تحديث الحالة بنجاح', true);
    } catch (e) {
      debugPrint("❌ Update Status Error: $e");
      showNotification('فشل تحديث الحالة في السيرفر', false);
    }
  }

  @override
  void dispose() {
    _ordersSubscription?.cancel(); // ✅ تنظيف الذاكرة عند إغلاق الـ Provider
    super.dispose();
  }
}

// 💡 نسخة محدثة من copyWith تدعم الـ specialRequestId
extension ConsumerOrderModelExtension on ConsumerOrderModel {
  ConsumerOrderModel copyWith({
    String? status,
    String? specialRequestId,
  }) {
    return ConsumerOrderModel(
      id: id,
      orderId: orderId,
      customerName: customerName,
      customerAddress: customerAddress,
      customerPhone: customerPhone,
      supermarketId: supermarketId,
      supermarketName: supermarketName,
      supermarketPhone: supermarketPhone,
      finalAmount: finalAmount,
      status: status ?? this.status,
      orderDate: orderDate,
      paymentMethod: paymentMethod,
      deliveryFee: deliveryFee,
      pointsUsed: pointsUsed,
      items: items,
      customerLatLng: customerLatLng, // تأكد من وجود الحقول الأساسية
      specialRequestId: specialRequestId ?? this.specialRequestId,
    );
  }
}
