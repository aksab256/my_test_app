// lib/models/consumer_order_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/constants.dart';

// نموذج المنتج داخل الطلب
// 💡 تم الإبقاء على OrderItem كما هي (عادة لا تسبب تضاربًا في الاسم)
class OrderItem {
  final String? name;
  final num? quantity;
  final String? imageUrl;
  // أضف أي حقول أخرى للمنتج إذا كانت موجودة في Firestore

  OrderItem({this.name, this.quantity, this.imageUrl});

  factory OrderItem.fromMap(Map<String, dynamic> data) {
    return OrderItem(
      name: data['name'] as String?,
      quantity: data['quantity'] as num?,
      imageUrl: data['imageUrl'] as String?,
    );
  }
}

// نموذج الطلب الرئيسي (💡 تم تغيير اسم الكلاس)
class ConsumerOrderModel {
  final String id; // Document ID (used for Firestore operations)
  final String orderId; // Internal order ID (optional, used for display)
  final String customerName;
  final String customerAddress;
  final String customerPhone;
  final String supermarketId;
  final String supermarketName;
  final String supermarketPhone;
  final double finalAmount;
  final String status;
  final Timestamp? orderDate;
  final String paymentMethod;
  final double deliveryFee;
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

  // دالة تحويل من Firestore DocumentSnapshot
  factory ConsumerOrderModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;

    // استخدام التحقق الآمن مع توفير قيم افتراضية مطابقة لمنطق الـ JS
    // هذا يضمن عدم الانهيار حتى لو كانت الحقول مفقودة (null)
    final itemsList = (data?['items'] as List<dynamic>?)
        ?.map((item) => OrderItem.fromMap(item as Map<String, dynamic>))
        .toList() ?? <OrderItem>[];
    
    // التعامل الآمن مع الأرقام (num to double)
    final finalAmount = (data?['finalAmount'] as num?)?.toDouble() ?? 0.0;
    final deliveryFee = (data?['deliveryFee'] as num?)?.toDouble() ?? 0.0;
    final pointsUsed = (data?['pointsUsed'] as num?)?.toInt() ?? 0;
    
    // التعامل مع التاريخ
    final orderDate = data?['orderDate'] as Timestamp?;

    return ConsumerOrderModel(
      id: doc.id,
      orderId: data?['orderId'] ?? doc.id,
      customerName: data?['customerName'] ?? 'غير معروف',
      customerAddress: data?['customerAddress'] ?? 'غير متوفر',
      customerPhone: data?['customerPhone'] ?? 'غير متوفر',
      supermarketId: data?['supermarketId'] ?? '',
      supermarketName: data?['supermarketName'] ?? 'غير معروف',
      supermarketPhone: data?['supermarketPhone'] ?? 'غير متوفر',
      finalAmount: finalAmount,
      status: data?['status'] ?? OrderStatuses.NEW_ORDER,
      orderDate: orderDate,
      paymentMethod: data?['paymentMethod'] ?? 'غير متوفر',
      deliveryFee: deliveryFee,
      pointsUsed: pointsUsed,
      items: itemsList,
    );
  }
}

