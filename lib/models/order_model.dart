// lib/models/order_model.dart
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

  factory OrderModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    // 1. معالجة التاريخ المرنة (String أو Timestamp)
    DateTime finalOrderDate;
    final orderDateData = data['orderDate'];
    if (orderDateData is Timestamp) {
      finalOrderDate = orderDateData.toDate();
    } else if (orderDateData is String) {
      finalOrderDate = DateTime.tryParse(orderDateData) ?? DateTime.now();
    } else {
      finalOrderDate = DateTime.now();
    }

    // 2. معالجة الحالة (Status) لضمان توافقها مع Dropdown ومنع الانهيار
    // نحدد الحالات المسموح بها في السيستم
    const allowedStatuses = ['new-order', 'processing', 'shipped', 'delivered', 'cancelled'];
    String rawStatus = data['status'] ?? 'new-order';
    
    // إذا كانت الحالة القادمة من Firebase غير معروفة، نجعلها 'new-order' كأمان
    String validatedStatus = allowedStatuses.contains(rawStatus) ? rawStatus : 'new-order';

    // 3. جلب المبالغ المالية
    final grossTotal = (data['total'] as num?)?.toDouble() ?? 0.0;
    final cashbackApplied = (data['cashbackApplied'] as num?)?.toDouble() ?? 0.0;
    final netTotal = (data['netTotal'] as num?)?.toDouble() ?? (grossTotal - cashbackApplied);

    return OrderModel(
      id: doc.id,
      sellerId: data['sellerId'] ?? data['vendorId'] ?? '', // دعم مسميين للـ ID
      orderDate: finalOrderDate,
      status: validatedStatus, // القيمة المفلترة والمضمونة
      buyerDetails: BuyerDetailsModel.fromMap(data['buyer'] ?? {}),
      items: (data['items'] as List<dynamic>? ?? [])
          .map((item) => OrderItemModel.fromMap(item as Map<String, dynamic>))
          .toList(),
      grossTotal: grossTotal,
      cashbackApplied: cashbackApplied,
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
      default: return 'طلب جديد'; // ضمان عدم الرجوع بنص غريب
    }
  }
}
