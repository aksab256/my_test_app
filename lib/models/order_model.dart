import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:my_test_app/models/buyer_details_model.dart';
import 'package:my_test_app/models/order_item_model.dart';

class OrderModel {
  final String id;
  final String sellerId;
  final DateTime orderDate;
  final String status;
  final BuyerDetailsModel buyerDetails;
  final List<OrderItemModel> items;
  final double grossTotal;
  final double cashbackApplied;
  final double totalAmount;

  OrderModel({
    required this.id,
    required this.sellerId,
    required this.orderDate,
    required this.status,
    required this.buyerDetails,
    required this.items,
    required this.grossTotal,
    required this.cashbackApplied,
    required this.totalAmount,
  });

  // 1. الـ Factory الأصلي (للموردين - كولكشن orders)
  factory OrderModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    DateTime finalOrderDate;
    final orderDateData = data['orderDate'];
    if (orderDateData is Timestamp) {
      finalOrderDate = orderDateData.toDate();
    } else if (orderDateData is String) {
      finalOrderDate = DateTime.tryParse(orderDateData) ?? DateTime.now();
    } else {
      finalOrderDate = DateTime.now();
    }

    const allowedStatuses = ['new-order', 'processing', 'shipped', 'delivered', 'cancelled'];
    String rawStatus = data['status'] ?? 'new-order';
    String validatedStatus = allowedStatuses.contains(rawStatus) ? rawStatus : 'new-order';

    final grossTotal = (data['total'] as num?)?.toDouble() ?? 0.0;
    final cashbackApplied = (data['cashbackApplied'] as num?)?.toDouble() ?? 0.0;
    final netTotal = (data['netTotal'] as num?)?.toDouble() ?? (grossTotal - cashbackApplied);

    return OrderModel(
      id: doc.id,
      sellerId: data['sellerId'] ?? data['vendorId'] ?? '',
      orderDate: finalOrderDate,
      status: validatedStatus,
      buyerDetails: BuyerDetailsModel.fromMap(data['buyer'] ?? {}),
      items: (data['items'] as List<dynamic>? ?? [])
          .map((item) => OrderItemModel.fromMap(item as Map<String, dynamic>))
          .toList(),
      grossTotal: grossTotal,
      cashbackApplied: cashbackApplied,
      totalAmount: netTotal,
    );
  }

  // 🎯 2. الـ Factory المطور للمستهلكين (كولكشن consumerorders)
  factory OrderModel.fromConsumerFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    DateTime finalDate;
    try {
      if (data['orderDate'] is Timestamp) {
        finalDate = (data['orderDate'] as Timestamp).toDate();
      } else {
        finalDate = DateTime.now();
      }
    } catch (_) {
      finalDate = DateTime.now();
    }

    final double netTotal = (data['finalAmount'] as num?)?.toDouble() ?? 0.0;
    final double subtotal = (data['subtotalPrice'] as num?)?.toDouble() ?? netTotal;

    final buyerInfo = BuyerDetailsModel(
      name: data['customerName'] ?? 'عميل مستهلك',
      phone: data['customerPhone'] ?? '',
      address: data['deliveryAddress'] ?? data['customerAddress'] ?? 'عنوان المستهلك',
    );

    // تحويل الأصناف مع مراعاة الحقول الموجودة في الـ OrderItemModel فقط
    List<OrderItemModel> parsedItems = [];
    if (data['items'] is List) {
      for (var itemData in (data['items'] as List)) {
        try {
          if (itemData is Map<String, dynamic>) {
            // نستخدم fromMap لأنها تتعامل داخلياً مع حقل 'price'
            parsedItems.add(OrderItemModel.fromMap(itemData));
          }
        } catch (e) {
          // Fallback يدوي يتطابق تماماً مع الـ Constructor بتاعك
          parsedItems.add(OrderItemModel(
            name: itemData['name'] ?? 'صنف غير معروف',
            quantity: (itemData['quantity'] ?? 0).toInt(),
            unit: itemData['unit'] ?? '',
            unitPrice: (itemData['price'] ?? 0).toDouble(),
            imageUrl: itemData['imageUrl'] ?? '',
          ));
        }
      }
    }

    return OrderModel(
      id: doc.id,
      sellerId: data['supermarketId'] ?? '', 
      orderDate: finalDate,
      status: data['status'] ?? 'new-order',
      buyerDetails: buyerInfo,
      items: parsedItems,
      grossTotal: subtotal,
      cashbackApplied: (data['pointsUsed'] as num?)?.toDouble() ?? 0.0,
      totalAmount: netTotal,
    );
  }

  String get statusText {
    switch (status) {
      case 'new-order': return 'طلب جديد';
      case 'processing': return 'قيد التجهيز';
      case 'shipped': return 'تم الشحن';
      case 'delivered': return 'تم التسليم';
      case 'cancelled': return 'ملغى';
      default: return 'طلب جديد';
    }
  }
}

