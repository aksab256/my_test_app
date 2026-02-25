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

  StreamSubscription<QuerySnapshot>? _ordersSubscription;

  // Getters
  bool get isLoading => _isLoading;
  String? get message => _message;
  bool get isSuccess => _isSuccess;
  List<ConsumerOrderModel> get orders => _orders;

  CustomerOrdersProvider(this._buyerData) {
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

  void listenToOrdersForBuyer() {
    final buyerId = _buyerData.loggedInUser?.id;

    if (buyerId == null || buyerId.isEmpty) return;

    _isLoading = true;
    notifyListeners();

    _ordersSubscription?.cancel();

    try {
      _ordersSubscription = _firestore
          .collection(CONSUMER_ORDERS_COLLECTION)
          .where("supermarketId", isEqualTo: buyerId)
          .orderBy('orderDate', descending: true)
          .snapshots()
          .listen((querySnapshot) {
        
        _orders = querySnapshot.docs.map((doc) {
          try {
            return ConsumerOrderModel.fromFirestore(doc);
          } catch (e) {
            debugPrint("🚨 Error parsing order ${doc.id}: $e");
            return null;
          }
        }).whereType<ConsumerOrderModel>().toList();

        _isLoading = false;
        _isSuccess = true;
        notifyListeners();
      }, onError: (error) {
        _isLoading = false;
        notifyListeners();
      });
    } catch (e) {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateOrderStatus(String orderDocId, String newStatus) async {
    final orderIndex = _orders.indexWhere((o) => o.id == orderDocId);
    if (orderIndex == -1) return;

    try {
      await _firestore
          .collection(CONSUMER_ORDERS_COLLECTION)
          .doc(orderDocId)
          .update({
        'status': newStatus,
        'lastUpdated': FieldValue.serverTimestamp(),
      });
      showNotification('تم تحديث الحالة بنجاح', true);
    } catch (e) {
      showNotification('فشل تحديث الحالة', false);
    }
  }

  @override
  void dispose() {
    _ordersSubscription?.cancel();
    super.dispose();
  }
}

// 💡 النسخة المصححة نهائياً: حذف الحقول التي تسبب تعارض مع الـ Constructor
extension ConsumerOrderModelExtension on ConsumerOrderModel {
  ConsumerOrderModel copyWith({
    String? status,
    String? specialRequestId,
  }) {
    // تم حذف customerLatLng وأي حقل آخر مشكوك في اسمه
    // الكلاس سيحتفظ بقيمه الأصلية من الكائن الحالي تلقائياً
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
      specialRequestId: specialRequestId ?? this.specialRequestId,
    );
  }
}
