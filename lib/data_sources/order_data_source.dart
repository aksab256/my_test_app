import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/order_model.dart';
import 'dart:developer' as developer;

class OrderDataSource {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // الثوابت لتوحيد مسميات الحالات
  static const String STATUS_NEW = 'new-order';
  static const String STATUS_DELIVERED = 'delivered';
  static const String STATUS_CANCELLED = 'cancelled';
  static const String STATUS_SHIPPED = 'shipped';

  Future<List<OrderModel>> loadOrders(String userId, String userRole) async {
    try {
      List<OrderModel> combinedOrders = [];

      // -------------------------------------------------------
      // 1. منطق البائع (Seller) - يجمع بين الجملة والقطاعي
      // -------------------------------------------------------
      if (userRole == 'seller') {
        // أ- جلب طلبات الموردين (B2B) من مجموعة orders
        final ordersSnapshot = await _db.collection('orders')
            .where('sellerId', isEqualTo: userId)
            .get();
        
        for (var doc in ordersSnapshot.docs) {
          try {
            combinedOrders.add(OrderModel.fromFirestore(doc));
          } catch (e) {
            developer.log('❌ Error parsing B2B order ${doc.id}: $e');
          }
        }

        // ب- جلب طلبات المستهلكين (B2C) من مجموعة consumerorders
        // هنا بنقلد "روح" كود التجزئة وبنستخدم supermarketId
        final consumerSnapshot = await _db.collection('consumerorders')
            .where('supermarketId', isEqualTo: userId)
            .get();

        for (var doc in consumerSnapshot.docs) {
          try {
            combinedOrders.add(OrderModel.fromConsumerFirestore(doc));
          } catch (e) {
            developer.log('❌ Error parsing B2C order ${doc.id}: $e');
          }
        }

        // ج- الترتيب النهائي في الذاكرة (لتجنب مشاكل الـ Indexes المعقدة)
        combinedOrders.sort((a, b) => b.orderDate.compareTo(a.orderDate));
        return combinedOrders;
      } 
      
      // -------------------------------------------------------
      // 2. منطق المشتري أو المستهلك (المسار الأصلي المحمي)
      // -------------------------------------------------------
      else {
        // تحديد الحقل والمجموعة بناءً على الدور
        String queryField = (userRole == 'consumer') ? 'customerId' : 'buyer.id';
        String collectionName = (userRole == 'consumer') ? 'consumerorders' : 'orders';

        final querySnapshot = await _db.collection(collectionName)
            .where(queryField, isEqualTo: userId)
            .orderBy('orderDate', descending: true) // الفهرس مطلوب هنا
            .get();

        return querySnapshot.docs.map((doc) {
          try {
            return (userRole == 'consumer' || collectionName == 'consumerorders') 
                ? OrderModel.fromConsumerFirestore(doc) 
                : OrderModel.fromFirestore(doc);
          } catch (e) {
            developer.log('⚠️ Error parsing order ${doc.id}: $e');
            return null;
          }
        }).whereType<OrderModel>().toList();
      }

    } catch (e) {
      developer.log('🔥 Global Fetch Error: $e', name: 'OrderDataSource');
      
      // Fallback: محاولة جلب البيانات بدون ترتيب في حالة فشل الفهارس
      try {
        String fallbackField = (userRole == 'seller') ? 'sellerId' : 'buyer.id';
        final fallbackSnapshot = await _db.collection('orders')
            .where(fallbackField, isEqualTo: userId)
            .get();
        return fallbackSnapshot.docs.map((doc) => OrderModel.fromFirestore(doc)).toList();
      } catch (fallbackError) {
        return []; // لو كله فشل نرجع قائمة فاضية
      }
    }
  }

  /// تحديث حالة الطلب في المجموعة الصحيحة
  Future<void> updateOrderStatus(String orderId, String newStatus) async {
    try {
      // البحث عن الوثيقة في المجموعتين لأن البائع (Seller) يرى كليهما
      DocumentReference? targetDoc;
      
      // محاولة 1: مجموعة orders
      final b2bDoc = await _db.collection('orders').doc(orderId).get();
      if (b2bDoc.exists) {
        targetDoc = _db.collection('orders').doc(orderId);
      } else {
        // محاولة 2: مجموعة consumerorders
        final b2cDoc = await _db.collection('consumerorders').doc(orderId).get();
        if (b2cDoc.exists) {
          targetDoc = _db.collection('consumerorders').doc(orderId);
        }
      }

      if (targetDoc == null) throw Exception('الطلب غير موجود في أي مجموعة');

      final updates = <String, dynamic>{
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // إضافة تواريخ الحالة
      if (newStatus == STATUS_DELIVERED) updates['deliveryDate'] = FieldValue.serverTimestamp();
      if (newStatus == STATUS_CANCELLED) updates['cancellationDate'] = FieldValue.serverTimestamp();
      if (newStatus == STATUS_SHIPPED) updates['shippedDate'] = FieldValue.serverTimestamp();

      await targetDoc.update(updates);
      developer.log('✅ Status updated for $orderId to $newStatus');
      
    } catch (e) {
      developer.log('❌ Update Error: $e');
      throw Exception('فشل تحديث الحالة: $e');
    }
  }
}

