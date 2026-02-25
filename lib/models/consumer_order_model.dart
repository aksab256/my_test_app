// lib/models/consumer_order_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart'; 
import '../constants/constants.dart';

// نموذج المنتج داخل الطلب
class OrderItem {
  final String? name;
  final num? quantity;
  final String? imageUrl;
  final double? price;
  final String? productId; 

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
      productId: data['productId'] as String?, 
    );
  }
}

// نموذج الطلب الرئيسي المحدث
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
  final double deliveryFee; 
  final int pointsUsed;
  final List<OrderItem> items;
  
  final double? lat;
  final double? lng;
  final String? specialRequestId; 

  // 🎯 الحقول الجديدة لدعم منطق المرتجع (لحل أخطاء البناء)
  final bool returnRequested; 
  final String? returnVerificationCode;

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
    this.lat,
    this.lng,
    this.specialRequestId,
    this.returnRequested = false, // القيمة الافتراضية
    this.returnVerificationCode,
  });

  LatLng get customerLatLng => LatLng(lat ?? 0.0, lng ?? 0.0);

  factory ConsumerOrderModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;

    final itemsList = (data?['items'] as List<dynamic>?)
            ?.map((item) => OrderItem.fromMap(item as Map<String, dynamic>))
            .toList() ?? <OrderItem>[];

    double extractedFee = (data?['deliveryFee'] as num?)?.toDouble() ?? 0.0;
    if (extractedFee == 0) {
      for (var item in itemsList) {
        if (item.productId == 'DELIVERY_FEE' || 
            (item.name != null && (item.name!.contains("توصيل") || item.name!.contains("Delivery")))) {
          extractedFee = item.price ?? 0.0;
          break; 
        }
      }
    }

    double? extractedLat;
    double? extractedLng;
    if (data?['deliveryLocation'] != null && data?['deliveryLocation'] is Map) {
      extractedLat = (data?['deliveryLocation']['lat'] as num?)?.toDouble();
      extractedLng = (data?['deliveryLocation']['lng'] as num?)?.toDouble();
    } 
    else if (data?['customerLatLng'] is GeoPoint) {
      extractedLat = (data?['customerLatLng'] as GeoPoint).latitude;
      extractedLng = (data?['customerLatLng'] as GeoPoint).longitude;
    }

    final String? specialId = data?['specialRequestId'] as String?;
    
    // 🚩 استخراج حقول المرتجع من Firestore
    final bool isReturnReq = data?['returnRequested'] ?? false;
    final String? returnCode = data?['returnVerificationCode']?.toString();

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
      finalAmount: (data?['finalAmount'] as num?)?.toDouble() ?? 0.0,
      status: data?['status'] ?? 'new-order', 
      orderDate: parsedDate,
      paymentMethod: data?['paymentMethod'] ?? 'كاش',
      deliveryFee: extractedFee, 
      pointsUsed: (data?['pointsUsed'] as num?)?.toInt() ?? 0,
      items: itemsList,
      lat: extractedLat,
      lng: extractedLng,
      specialRequestId: specialId,
      returnRequested: isReturnReq, // ✅ ربط القيمة
      returnVerificationCode: returnCode, // ✅ ربط القيمة
    );
  }
}
