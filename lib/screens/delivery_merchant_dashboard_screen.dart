// lib/screens/delivery_merchant_dashboard_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:my_test_app/providers/buyer_data_provider.dart';
import 'package:my_test_app/widgets/delivery_merchant_sidebar_widget.dart';

// 1. موديل البيانات
class DashboardData {
  final int totalProducts;
  final int totalOrders;
  final int pendingOrders;
  final double totalSales;

  DashboardData({
    required this.totalProducts,
    required this.totalOrders,
    required this.pendingOrders,
    required this.totalSales,
  });
}

// 2. الشاشة الرئيسية (Stateful)
class DeliveryMerchantDashboardScreen extends StatefulWidget {
  // 🎯 التصحيح 1: إضافة routeName لحل الخطأ في شاشة العروض
  static const routeName = '/deliveryMerchantDashboard'; 

  const DeliveryMerchantDashboardScreen({super.key});

  @override
  State<DeliveryMerchantDashboardScreen> createState() => _DeliveryMerchantDashboardScreenState();
}

class _DeliveryMerchantDashboardScreenState extends State<DeliveryMerchantDashboardScreen> {
  Future<DashboardData>? _dashboardDataFuture;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 3. دالة جلب البيانات (مطابقة لمنطق JavaScript)
  Future<DashboardData> _fetchDashboardData(String userId) async {
    // ----------------- 1. إجمالي المنتجات -----------------
    final productsRef = _firestore.collection("marketOffer");
    final activeOffersQuery = productsRef
        .where("ownerId", isEqualTo: userId)
        .where("status", isEqualTo: "active");

    final productsSnapshot = await activeOffersQuery.count().get();
    final totalProducts = productsSnapshot.count; // نوعها int?

    // ----------------- 2. إجمالي الطلبات والمعلقة والمبيعات -----------------
    final ordersRef = _firestore.collection("consumerorders");
    
    // إجمالي الطلبات (الكل)
    final allOrdersQuery = ordersRef.where("supermarketId", isEqualTo: userId);
    final allOrdersSnapshot = await allOrdersQuery.count().get();
    final totalOrders = allOrdersSnapshot.count; // نوعها int?
    
    // طلبات معلقة
    final pendingOrdersQuery = ordersRef
        .where("supermarketId", isEqualTo: userId)
        .where("status", whereIn: ["new-order", "pending"]);

    final pendingOrdersSnapshot = await pendingOrdersQuery.count().get();
    final pendingOrders = pendingOrdersSnapshot.count; // نوعها int?
    
    // إجمالي المبيعات
    final deliveredOrdersQuery = ordersRef
        .where("supermarketId", isEqualTo: userId)
        .where("status", isEqualTo: "delivered");

    final deliveredOrdersDocs = await deliveredOrdersQuery.get();
    double totalSales = 0;
    for (var doc in deliveredOrdersDocs.docs) {
      final data = doc.data();
      if (data.containsKey('finalAmount') && data['finalAmount'] != null) {
        totalSales += double.tryParse(data['finalAmount'].toString()) ?? 0.0;
      }
    }

    return DashboardData(
      // 🎯 التصحيح 1: إضافة ?? 0 لتحويل int? إلى int
      totalProducts: totalProducts ?? 0,
      totalOrders: totalOrders ?? 0,
      pendingOrders: pendingOrders ?? 0,
      totalSales: totalSales,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_dashboardDataFuture == null) {
      final buyerData = Provider.of<BuyerDataProvider>(context, listen: false);
      
      // 🎯 التصحيح 2: تغيير 'user' إلى 'loggedInUser'
      final userId = buyerData.loggedInUser?.id;
      
      if (userId != null && userId.isNotEmpty) {
        _dashboardDataFuture = _fetchDashboardData(userId);
      } else {
        _dashboardDataFuture = Future.error("User ID is missing or not logged in.");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // 🎯 التصحيح 3: تغيير 'user' إلى 'loggedInUser'
    final userName = Provider.of<BuyerDataProvider>(context).loggedInUser?.fullname ?? 'التاجر';

    return Scaffold(
      appBar: AppBar(
        title: const Text('لوحة تحكم التوصيل'),
      ),
      drawer: const DeliveryMerchantSidebarWidget(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // رأس الصفحة ورسالة الترحيب
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'أهلاً بك، $userName!',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                  textDirection: TextDirection.rtl,
                ),
                Row(
                  children: [
                    Icon(Icons.dashboard_rounded, size: 28, color: Theme.of(context).primaryColor),
                    const SizedBox(width: 10),
                    const Text(
                      'لوحة تحكم التوصيل',
                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 30),
            
            // عرض البيانات عبر FutureBuilder
            FutureBuilder<DashboardData>(
              future: _dashboardDataFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  return Center(child: Text('خطأ في تحميل البيانات: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
                } else if (snapshot.hasData) {
                  final data = snapshot.data!;
                  return GridView.count(
                    crossAxisCount: MediaQuery.of(context).size.width > 700 ? 4 : 2,
                    crossAxisSpacing: 20,
                    mainAxisSpacing: 20,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _DashboardCard(
                        icon: Icons.inventory_2_rounded,
                        title: 'إجمالي المنتجات',
                        value: data.totalProducts.toString(),
                      ),
                      _DashboardCard(
                        icon: Icons.receipt_rounded,
                        title: 'إجمالي الطلبات',
                        value: data.totalOrders.toString(),
                      ),
                      _DashboardCard(
                        icon: Icons.pending_actions_rounded,
                        title: 'طلبات معلقة',
                        value: data.pendingOrders.toString(),
                      ),
                      _DashboardCard(
                        icon: Icons.attach_money_rounded,
                        title: 'إجمالي المبيعات',
                        value: '${data.totalSales.toStringAsFixed(2)} ج.م',
                      ),
                    ],
                  );
                }
                return const Center(child: Text('لا توجد بيانات لعرضها.'));
              },
            ),

            const SizedBox(height: 30),
            const Text(
              'مرحباً بك في لوحة تحكم التوصيل! استخدم القائمة الجانبية للتنقل بين الأقسام.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18),
            ),
          ],
        ),
      ),
    );
  }
}

// 4. ويدجت البطاقة الفرعية
class _DashboardCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _DashboardCard({required this.icon, required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(25.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 45, color: const Color(0xFF4CAF50)),
            const SizedBox(height: 15),
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              value,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF2c3e50)),
            ),
          ],
        ),
      ),
    );
  }
}
