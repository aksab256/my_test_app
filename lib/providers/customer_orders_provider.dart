// lib/providers/customer_orders_provider.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// 💡 تم تحديث الاستيراد
import '../models/consumer_order_model.dart';
import '../constants/constants.dart';
import 'buyer_data_provider.dart';

class CustomerOrdersProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final BuyerDataProvider _buyerData;

  // حالة التحميل والرسائل
  bool _isLoading = false;
  String? _message;
  bool _isSuccess = true;
  
  // 💡 تحديث نوع قائمة الطلبات
  List<ConsumerOrderModel> _orders = [];

  // Getters
  bool get isLoading => _isLoading;
  String? get message => _message;
  bool get isSuccess => _isSuccess;
  // 💡 تحديث نوع القائمة في Getter
  List<ConsumerOrderModel> get orders => _orders;

  // Constructor
  CustomerOrdersProvider(this._buyerData) {
    fetchAndDisplayOrdersForBuyer();
  }

  // ------------------------------------
  // وظائف إدارة الحالة
  // ------------------------------------
  void showNotification(String msg, bool success) {
    _message = msg;
    _isSuccess = success;
    notifyListeners();
  }

  void clearNotification() {
    _message = null;
    notifyListeners();
  }

  void setIsLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  // ------------------------------------
  // وظائف جلب البيانات
  // ------------------------------------
  Future<void> fetchAndDisplayOrdersForBuyer() async {
    setIsLoading(true);
    clearNotification();

    final buyerId = _buyerData.loggedInUser?.id;
    
    if (buyerId == null || buyerId.isEmpty) {
      showNotification('يجب أن تكون مسجلاً كتاجر لعرض الطلبات.', false);
      setIsLoading(false);
      return;
    }
    
    debugPrint("✅ Starting Order Fetch for Buyer ID: $buyerId");

    try {
      final ordersQuery = _firestore
          .collection(CONSUMER_ORDERS_COLLECTION)
          .where("supermarketId", isEqualTo: buyerId)
          .orderBy('orderDate', descending: true)
          .get();

      final querySnapshot = await ordersQuery;

      if (querySnapshot.docs.isEmpty) {
        _orders = [];
        showNotification('لا توجد طلبات عملاء حاليًا لهذا الحساب.', true);
        setIsLoading(false);
        return;
      }

      // 💡 استخدام اسم النموذج الجديد عند التحويل
      _orders = querySnapshot.docs
          .map((doc) => ConsumerOrderModel.fromFirestore(doc))
          .toList();

      showNotification('تم جلب ${orders.length} طلب بنجاح.', true);
      
    } catch (e) {
      debugPrint("❌ Error fetching orders for Buyer (Possible Indexing Issue): $e");
      showNotification('حدث خطأ أثناء جلب الطلبات. (تحقق من الفهرسة).', false);
    }
    setIsLoading(false);
    notifyListeners();
  }

  // ------------------------------------
  // وظائف تحديث الحالة
  // ------------------------------------
  Future<void> updateOrderStatus(String orderDocId, String newStatus) async {
    clearNotification();
    
    final orderIndex = _orders.indexWhere((o) => o.id == orderDocId);

    if (orderIndex == -1) {
      showNotification('خطأ: لم يتم العثور على الطلب لتحديث حالته.', false);
      return;
    }

    // 💡 استخدام اسم النموذج الجديد
    final orderToUpdate = _orders[orderIndex];

    if (orderToUpdate.status == OrderStatuses.DELIVERED || orderToUpdate.status == OrderStatuses.CANCELLED) {
      showNotification('لا يمكن تغيير حالة طلب تم توصيله أو إلغائه.', false);
      return;
    }

    final originalStatus = orderToUpdate.status;
    // 💡 استخدام دالة copyWith على النموذج الجديد
    _orders[orderIndex] = orderToUpdate.copyWith(status: newStatus); 
    notifyListeners();

    try {
      final orderRef = _firestore.collection(CONSUMER_ORDERS_COLLECTION).doc(orderDocId);
      
      await orderRef.update({
        'status': newStatus,
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      debugPrint("✅ Order status successfully updated in Firestore: $orderDocId to $newStatus");
      showNotification('تم تحديث حالة الطلب إلى: ${getStatusDisplayName(newStatus)}', true);

    } catch (e) {
      debugPrint("❌ Error updating order status: $e");
      showNotification('حدث خطأ أثناء تحديث حالة الطلب.', false);
      
      // 💡 استخدام دالة copyWith على النموذج الجديد
      _orders[orderIndex] = orderToUpdate.copyWith(status: originalStatus);
      notifyListeners();
    }
  }
}

// 💡 تحديث اسم الكلاس الذي يتم توسيعه
extension ConsumerOrderModelExtension on ConsumerOrderModel {
    ConsumerOrderModel copyWith({
        String? status,
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
        );
    }
}

