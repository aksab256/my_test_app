// lib/models/consumer_order_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/constants.dart';

// نموذج المنتج داخل الطلب
class OrderItem {
  final String? name;
  final num? quantity;
  final String? imageUrl;

  OrderItem({this.name, this.quantity, this.imageUrl});

  factory OrderItem.fromMap(Map<String, dynamic> data) {
    return OrderItem(
      // 🟢 دعم المسميات المختلفة الموجودة في Firebase
      name: (data['name'] ?? data['productName']) as String?, 
      quantity: data['quantity'] as num?,
      imageUrl: (data['imageUrl'] ?? data['productImage']) as String?,
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
  final DateTime? orderDate; // 🟢 تم التغيير من Timestamp إلى DateTime
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

  factory ConsumerOrderModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;

    // 🟢 معالجة المنتجات
    final itemsList = (data?['items'] as List<dynamic>?)
            ?.map((item) => OrderItem.fromMap(item as Map<String, dynamic>))
            .toList() ?? <OrderItem>[];

    // 🟢 معالجة الأرقام
    final finalAmount = (data?['finalAmount'] as num?)?.toDouble() ?? 0.0;
    final deliveryFee = (data?['deliveryFee'] as num?)?.toDouble() ?? 0.0;
    final pointsUsed = (data?['pointsUsed'] as num?)?.toInt() ?? 0;

    // 🟢 معالجة التاريخ المرنة (الحل الجذري للمشكلة)
    DateTime? parsedDate;
    var rawDate = data?['orderDate'];
    if (rawDate is Timestamp) {
      parsedDate = rawDate.toDate();
    } else if (rawDate is String) {
      parsedDate = DateTime.tryParse(rawDate);
    }

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
      orderDate: parsedDate, // 🟢 تمرير التاريخ المعالج
      paymentMethod: data?['paymentMethod'] ?? 'غير متوفر',
      deliveryFee: deliveryFee,
      pointsUsed: pointsUsed,
      items: itemsList,
    );
  }
}
