// lib/models/consumer_order_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/constants.dart';

// نموذج المنتج داخل الطلب
class OrderItem {
  final String? name;
  final num? quantity;
  final String? imageUrl;
  final double? price;
  final String? productId; // تم إضافته لتمكين الفلترة الذكية

  OrderItem({
    this.name, 
    this.quantity, 
    this.imageUrl, 
    this.price,
    this.productId,
  });

  factory OrderItem.fromMap(Map<String, dynamic> data) {
    return OrderItem(
      name: (data['name'] ?? data['productName']) as String?, 
      quantity: data['quantity'] as num?,
      imageUrl: (data['imageUrl'] ?? data['productImage']) as String?,
      price: (data['price'] as num?)?.toDouble(),
      productId: data['productId'] as String?, // جلب المعرف للتأكد من نوع المنتج
    );
  }
}

// نموذج الطلب الرئيسي
class ConsumerOrderModel {
  final String id;
  final String orderId;
  final String customerName;
  final String customerAddress;
  final String customerPhone;
  final String supermarketId;
  final String supermarketName;
  final String supermarketPhone;
  final double finalAmount;
  final String status;
  final DateTime? orderDate; 
  final String paymentMethod;
  final double deliveryFee; // الحقل الذي كان يظهر صفراً
  final int pointsUsed;
  final List<OrderItem> items;

  ConsumerOrderModel({
    required this.id,
    required this.orderId,
    required this.customerName,
    required this.customerAddress,
    required this.customerPhone,
    required this.supermarketId,
    required this.supermarketName,
    required this.supermarketPhone,
    required this.finalAmount,
    required this.status,
    this.orderDate,
    required this.paymentMethod,
    required this.deliveryFee,
    required this.pointsUsed,
    required this.items,
  });

  factory ConsumerOrderModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;

    // 1. تحويل مصفوفة المنتجات أولاً لاستخدامها في البحث عن التوصيل
    final itemsList = (data?['items'] as List<dynamic>?)
            ?.map((item) => OrderItem.fromMap(item as Map<String, dynamic>))
            .toList() ?? <OrderItem>[];

    // 2. 🎯 منطق جلب مصاريف التوصيل الموحد مع الـ Checkout
    double extractedFee = 0.0;

    // أولاً: محاولة القراءة من الحقل المباشر (في حال وجوده في طلبات قديمة أو تحديث مستقبلي)
    extractedFee = (data?['deliveryFee'] as num?)?.toDouble() ?? 0.0;

    // ثانياً: إذا كانت النتيجة صفر، نبحث داخل المنتجات عن المعرف 'DELIVERY_FEE' 
    // أو أي منتج يحتوي اسمه على كلمة "توصيل" (نفس منطق تطبيق المستهلك)
    if (extractedFee == 0) {
      for (var item in itemsList) {
        if (item.productId == 'DELIVERY_FEE' || 
            (item.name != null && (item.name!.contains("توصيل") || item.name!.contains("Delivery")))) {
          extractedFee = item.price ?? 0.0;
          break; // وجدنا القيمة، نخرج من الحلقة
        }
      }
    }

    final finalAmount = (data?['finalAmount'] as num?)?.toDouble() ?? 0.0;
    final pointsUsed = (data?['pointsUsed'] as num?)?.toInt() ?? 0;

    // معالجة التاريخ (Timestamp أو String)
    DateTime? parsedDate;
    var rawDate = data?['orderDate'];
    if (rawDate is Timestamp) {
      parsedDate = rawDate.toDate();
    } else if (rawDate is String) {
      parsedDate = DateTime.tryParse(rawDate);
    }

    return ConsumerOrderModel(
      id: doc.id,
      orderId: data?['orderId']?.toString() ?? doc.id,
      customerName: data?['customerName'] ?? 'غير معروف',
      customerAddress: data?['customerAddress'] ?? 'غير متوفر',
      customerPhone: data?['customerPhone'] ?? '', 
      supermarketId: data?['supermarketId'] ?? '',
      supermarketName: data?['supermarketName'] ?? 'غير معروف',
      supermarketPhone: data?['supermarketPhone'] ?? '', 
      finalAmount: finalAmount,
      status: data?['status'] ?? 'new-order', 
      orderDate: parsedDate,
      paymentMethod: data?['paymentMethod'] ?? 'كاش',
      deliveryFee: extractedFee, // القيمة المستخرجة بذكاء الآن
      pointsUsed: pointsUsed,
      items: itemsList,
    );
  }
}
