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

  // 1. الـ Factory الخاص بالموردين (كولكشن orders) - نتركه كما هو
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
  // تم ضبطه ليناسب صورة الفايربيز التي أرسلتها (أبو الشام ومحمود)
  factory OrderModel.fromConsumerFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    // أ- معالجة التاريخ: نضمن عدم حدوث كراش لو التنسيق اختلف
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

    // ب- مطابقة المبالغ: المستهلك يستخدم finalAmount بدلاً من netTotal
    final double netTotal = (data['finalAmount'] as num?)?.toDouble() ?? 
                            (data['totalAmount'] as num?)?.toDouble() ?? 0.0;
    final double subtotal = (data['subtotalPrice'] as num?)?.toDouble() ?? netTotal;
    final double points = (data['pointsUsed'] as num?)?.toDouble() ?? 0.0;

    // ج- بناء بيانات المشتري (محمود): الفايربيز يضع الحقول في الـ Root وليس داخل Map
    // هنا ننسخ بيانات BuyerDetailsModel يدوياً لضمان الدقة
    final buyerDetails = BuyerDetailsModel(
      name: data['customerName'] ?? 'عميل مستهلك',
      phone: data['customerPhone'] ?? '', 
      address: data['deliveryAddress'] ?? data['customerAddress'] ?? 'عنوان المستهلك',
    );

    // د- تحويل الأصناف: معالجة كل صنف على حدة (Try-Catch داخلي)
    List<OrderItemModel> parsedItems = [];
    if (data['items'] is List) {
      for (var itemData in (data['items'] as List)) {
        try {
          if (itemData is Map<String, dynamic>) {
            parsedItems.add(OrderItemModel.fromMap(itemData));
          }
        } catch (e) {
          // Fallback في حالة اختلاف مسميات حقول الأصناف (مثل price بدلاً من unitPrice)
          parsedItems.add(OrderItemModel(
            productId: itemData['productId'] ?? '',
            name: itemData['name'] ?? 'صنف غير معروف',
            quantity: (itemData['quantity'] ?? 1).toInt(),
            unitPrice: (itemData['price'] ?? 0).toDouble(),
            offerId: itemData['offerId'] ?? '',
            unitIndex: (itemData['unitIndex'] ?? 0).toInt(),
          ));
        }
      }
    }

    return OrderModel(
      id: doc.id,
      sellerId: data['supermarketId'] ?? '', // نستخدم المعرف الموجود في الصورة
      orderDate: finalDate,
      status: data['status'] ?? 'new-order',
      buyerDetails: buyerDetails,
      items: parsedItems,
      grossTotal: subtotal,
      cashbackApplied: points,
      totalAmount: netTotal,
    );
  }

  String get statusText {
    switch (status) {
      case 'new-order': return 'طلب جديد';
      case 'processing': return 'قيد التجهيز';
      case 'shipped': return 'تم الشحن';
      case 'delivered': return 'تم التسليم ✅';
      case 'cancelled': return 'ملغى ❌';
      default: return 'طلب جديد';
    }
  }
}
