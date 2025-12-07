// lib/models/order_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:my_test_app/models/buyer_details_model.dart';
import 'package:my_test_app/models/order_item_model.dart';

class OrderModel {
  final String id;
  // ⭐️ حقول البائع والوقت ⭐️
  final String sellerId;
  final DateTime orderDate;
  final String status;

  // ⭐️ حقول التفاصيل ⭐️
  final BuyerDetailsModel buyerDetails;
  final List<OrderItemModel> items;

  // ⭐️ حقول المبالغ المالية (مطابقة للـ HTML) ⭐️
  final double grossTotal; // (order.total || 0) -> الإجمالي قبل الخصم
  final double cashbackApplied; // (order.cashbackApplied || 0) -> خصم الكاش باك
  final double totalAmount; // (order.netTotal || grossTotal - cashback) -> المبلغ الصافي

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
    final data = doc.data() as Map<String, dynamic>;
    
    // 1. جلب التواريخ (تم تحسين التحقق)
    DateTime finalOrderDate;
    final orderDateData = data['orderDate'];

    if (orderDateData is Timestamp) {
      // الحالة 1: تم استلامها كـ Timestamp (الطريقة المفضلة من FireStore SDK)
      finalOrderDate = orderDateData.toDate();
    } else if (orderDateData is String) {
      // الحالة 2: تم استلامها كسلسلة نصية (إذا تم إرسالها كـ JSON عادي)
      try {
        finalOrderDate = DateTime.parse(orderDateData);
      } catch (e) {
        // إذا فشل تحليل السلسلة النصية، نستخدم التاريخ الحالي
        print('Error parsing orderDate string: $e');
        finalOrderDate = DateTime.now();
      }
    } else {
      // الحالة 3: لا يوجد تاريخ صالح، نستخدم التاريخ الحالي
      finalOrderDate = DateTime.now();
    }

    // 2. جلب التفاصيل
    final buyerMap = data['buyer'] as Map<String, dynamic>? ?? {};
    final itemsList = (data['items'] as List<dynamic>?) ?? [];

    // 3. جلب المبالغ المالية وتوحيدها
    // Gross Total (الإجمالي قبل الخصم)
    final grossTotal = (data['total'] as num?)?.toDouble() ?? 0.0;
    // Cashback Applied
    final cashbackApplied = (data['cashbackApplied'] as num?)?.toDouble() ?? 0.0;
    // Net Total (المبلغ الصافي) - نستخدم netTotal أو نقوم بحسابه
    final netTotal = (data['netTotal'] as num?)?.toDouble() ?? (grossTotal - cashbackApplied);


    return OrderModel(
      id: doc.id,
      sellerId: data['sellerId'] ?? '', // ⭐️ حقل sellerId ⭐️
      orderDate: finalOrderDate,
      status: data['status'] ?? 'غير محدد',

      buyerDetails: BuyerDetailsModel.fromMap(buyerMap),
      items: itemsList.map((item) => OrderItemModel.fromMap(item as Map<String, dynamic>)).toList(),

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
      default: return 'حالة غير معروفة';
    }
  }
}
