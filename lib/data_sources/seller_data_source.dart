// lib/data_sources/seller_data_source.dart (النسخة النهائية والمدمجة)

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:my_test_app/models/seller_model.dart';
import 'dart:developer' as developer;


// تعريف نموذج البيانات للوحة التحكم (موجود سابقاً)
class SellerDashboardData {
  final int totalOrdersCount;
  final double completedSalesAmount;
  final int pendingOrdersCount;
  final int newOrdersCount;
                                                       
  SellerDashboardData({
    required this.totalOrdersCount,
    required this.completedSalesAmount,
    required this.pendingOrdersCount,
    required this.newOrdersCount,
  });
}
                                                    
class SellerDataSource {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  // ⭐️⭐️ تم تغيير اسم المجموعة إلى 'sellers' لحل مشكلة 'Seller not found' ⭐️⭐️
  final String _collectionName = 'sellers'; 

  /// تجلب تفاصيل البائع (المتجر) بناءً على معرفه (sellerId).
  Future<SellerModel> getSellerDetails(String sellerId) async {
    try {
      developer.log('Fetching seller details for ID: $sellerId from $_collectionName', name: 'SellerDataSource');

      final docSnapshot = await _db.collection(_collectionName).doc(sellerId).get();

      if (!docSnapshot.exists || docSnapshot.data() == null) {
        developer.log('Seller document not found for ID: $sellerId', name: 'SellerDataSource');
        throw Exception('Seller not found or data is empty.');
      }
      
      final data = docSnapshot.data()!;
      return SellerModel.fromFirestore(data, docSnapshot.id);

    } catch (e) {
      developer.log('Error in getSellerDetails for ID: $sellerId. Error: $e', name: 'SellerDataSource', error: e);
      return SellerModel(
        id: sellerId,
        name: 'خطأ في الاتصال!',
        phone: '---',
        address: 'فشل جلب البيانات: ${e.toString().split(':').last}',
      );
    }
  }

  /// تجلب بيانات لوحة التحكم للبائع المحدد.
  Future<SellerDashboardData> loadDashboardData(String sellerId) async {
    // ⭐️ المنطق هنا ما زال يستخدم مجموعة "orders" للحسابات، وهذا صحيح ⭐️
    final ordersQuery = _db
        .collection("orders")
        .where("sellerId", isEqualTo: sellerId);
                                                             
    final ordersSnapshot = await ordersQuery.get();
                                                           
    int totalOrders = 0;
    double completedSales = 0.0;
    int pendingOrders = 0;
    int newOrders = 0;
                                
    for (var doc in ordersSnapshot.docs) {
      final orderData = doc.data();
      totalOrders++;

      final status = orderData['status']?.toString().toLowerCase().trim() ?? '';
                                                           
      if (status == 'تم التوصيل' || status == 'delivered') {
        completedSales += (orderData['total'] as num?)?.toDouble() ?? 0.0;
      }
                                                           
      final isCancelled = (status == 'ملغى' || status == 'cancelled' || status == 'rejected' || status == 'failed');
                                           
      if (!(status == 'تم التوصيل' || status == 'delivered' || isCancelled)) {
        pendingOrders++;
      }

      if (status == 'new-order') {
        newOrders++;
      }
    }
                                                         
    return SellerDashboardData(
      totalOrdersCount: totalOrders,
      completedSalesAmount: completedSales,
      pendingOrdersCount: pendingOrders,
      newOrdersCount: newOrders,
    );
  }
}

