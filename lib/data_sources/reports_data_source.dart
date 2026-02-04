// lib/data_sources/reports_data_source.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'dart:developer' as developer;

// --- 1. نماذج بيانات التقارير (Data Models) ---

class SalesOverview {
  final double totalSales;
  final int totalOrders;
  final int productsSold;

  SalesOverview({
    required this.totalSales,
    required this.totalOrders,
    required this.productsSold,
  });
}

class StatusReport {
  final List<String> labels;
  final List<int> counts;

  StatusReport({required this.labels, required this.counts});
}

class MonthlySales {
  final List<String> labels; 
  final List<double> sales;

  MonthlySales({required this.labels, required this.sales});
}

class TopProduct {
  final String name;
  final int quantity;
  final double totalSales;

  TopProduct({
    required this.name,
    required this.quantity,
    required this.totalSales,
  });
}

class FullReportData {
  final SalesOverview overview;
  final StatusReport statusReport;
  final MonthlySales monthlySales;
  final List<TopProduct> topProducts;

  FullReportData({
    required this.overview,
    required this.statusReport,
    required this.monthlySales,
    required this.topProducts,
  });
}

// --- 2. فئة جلب البيانات (Data Source) ---

class ReportsDataSource {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // خريطة حالات الطلب (للعرض باللغة العربية)
  static const Map<String, String> ORDER_STATUSES_MAP = {
    'new-order': 'طلبات جديدة',
    'pending': 'قيد الانتظار', // مضافة لدعم طلبات المستهلك
    'processing': 'قيد التنفيذ',
    'shipped': 'تم الشحن',
    'delivered': 'تم التوصيل',
    'cancelled': 'ملغاة',
  };

  Future<FullReportData> loadFullReport(
      String sellerId, DateTime startDate, DateTime endDate) async {
    
    final startTimestamp = Timestamp.fromDate(startDate);
    final endTimestamp = Timestamp.fromDate(endDate);

    try {
      // أ. استعلام طلبات الجملة
      final b2bQuery = _db
          .collection("orders")
          .where("sellerId", isEqualTo: sellerId)
          .where("orderDate", isGreaterThanOrEqualTo: startTimestamp)
          .where("orderDate", isLessThanOrEqualTo: endTimestamp)
          .get();

      // ب. استعلام طلبات المستهلكين
      final b2cQuery = _db
          .collection("consumerorders")
          .where("supermarketId", isEqualTo: sellerId)
          .where("orderDate", isGreaterThanOrEqualTo: startTimestamp)
          .where("orderDate", isLessThanOrEqualTo: endTimestamp)
          .get();

      // جلب البيانات من المجموعتين معاً
      final results = await Future.wait([b2bQuery, b2cQuery]);
      final b2bDocs = results[0].docs;
      final b2cDocs = results[1].docs;

      if (b2bDocs.isEmpty && b2cDocs.isEmpty) {
        return _emptyReport();
      }

      double totalSales = 0;
      int totalOrders = 0;
      int productsSoldCount = 0;
      final statusCounts = <String, int>{};
      final monthlySalesMap = <String, double>{};
      final productSalesMap = <String, Map<String, dynamic>>{};

      // تهيئة العدادات
      ORDER_STATUSES_MAP.keys.forEach((status) => statusCounts[status] = 0);

      final allDocs = [...b2bDocs, ...b2cDocs];

      for (var doc in allDocs) {
        final data = doc.data() as Map<String, dynamic>;
        
        // 1. توحيد الحالة
        String status = (data['status']?.toString().toLowerCase().trim() ?? 'unknown');
        if (ORDER_STATUSES_MAP.containsKey(status)) {
          statusCounts[status] = (statusCounts[status] ?? 0) + 1;
        }

        // 2. الحسابات المالية (فقط للطلبات غير الملغاة)
        if (status != 'cancelled') {
          totalOrders++;
          
          // توحيد مسمى حقل المبلغ (total للجملة و finalAmount للقطاعي)
          final orderTotal = (data['total'] ?? data['finalAmount'] ?? 0.0) as num;
          totalSales += orderTotal.toDouble();

          // 3. معالجة التاريخ والشهور
          DateTime? date;
          if (data['orderDate'] is Timestamp) {
            date = (data['orderDate'] as Timestamp).toDate();
          } else if (data['orderDate'] is String) {
            date = DateTime.tryParse(data['orderDate']);
          }

          if (date != null) {
            final monthYear = DateFormat('yyyy-MM').format(date);
            monthlySalesMap[monthYear] = (monthlySalesMap[monthYear] ?? 0) + orderTotal.toDouble();
          }

          // 4. معالجة المنتجات الأكثر مبيعاً
          final orderItems = data['items'] as List<dynamic>? ?? [];
          for (var item in orderItems) {
            final productName = item['name'] ?? item['translatedName'] ?? 'منتج مجهول';
            final quantity = (item['quantity'] ?? 0) as num;
            final itemPrice = (item['price'] ?? 0.0) as num;

            if (!productSalesMap.containsKey(productName)) {
              productSalesMap[productName] = {'quantity': 0, 'totalSales': 0.0};
            }
            productSalesMap[productName]!['quantity'] += quantity.toInt();
            productSalesMap[productName]!['totalSales'] += (itemPrice * quantity).toDouble();
            productsSoldCount += quantity.toInt();
          }
        }
      }

      return FullReportData(
        overview: SalesOverview(
          totalSales: totalSales,
          totalOrders: totalOrders,
          productsSold: productsSoldCount,
        ),
        statusReport: _buildStatusReport(statusCounts),
        monthlySales: _buildMonthlySales(monthlySalesMap),
        topProducts: _buildTopProducts(productSalesMap),
      );

    } catch (e) {
      developer.log('Error in ReportsDataSource: $e');
      rethrow;
    }
  }

  // --- دوال المساعدة للتحويل النهائي ---

  StatusReport _buildStatusReport(Map<String, int> statusCounts) {
    // نأخذ الحالات التي تكررت مرة واحدة على الأقل
    final activeEntries = ORDER_STATUSES_MAP.entries
        .where((entry) => (statusCounts[entry.key] ?? 0) > 0)
        .toList();

    return StatusReport(
      labels: activeEntries.map((e) => e.value).toList(),
      counts: activeEntries.map((e) => statusCounts[e.key]!).toList(),
    );
  }

  MonthlySales _buildMonthlySales(Map<String, double> monthlySalesMap) {
    final sortedMonths = monthlySalesMap.keys.toList()..sort();
    final labels = sortedMonths.map((my) {
      final date = DateFormat('yyyy-MM').parse(my);
      return DateFormat('MM/yyyy').format(date);
    }).toList();

    return MonthlySales(
      labels: labels,
      sales: sortedMonths.map((my) => monthlySalesMap[my]!).toList(),
    );
  }

  List<TopProduct> _buildTopProducts(Map<String, Map<String, dynamic>> productSalesMap) {
    final sortedProducts = productSalesMap.entries.map((entry) {
      return TopProduct(
        name: entry.key,
        quantity: entry.value['quantity'] as int,
        totalSales: entry.value['totalSales'] as double,
      );
    }).toList()
    ..sort((a, b) => b.totalSales.compareTo(a.totalSales));

    return sortedProducts.take(5).toList();
  }

  FullReportData _emptyReport() {
    return FullReportData(
      overview: SalesOverview(totalSales: 0.0, totalOrders: 0, productsSold: 0),
      statusReport: StatusReport(labels: [], counts: []),
      monthlySales: MonthlySales(labels: [], sales: []),
      topProducts: [],
    );
  }
}
