import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:my_test_app/providers/buyer_data_provider.dart';
import 'package:my_test_app/widgets/delivery_merchant_sidebar_widget.dart';
// ✨ تم تفعيل الاستيراد وتصحيح اسم الملف بناءً على مسمياتك
import 'package:my_test_app/screens/merchant_balance_screen.dart'; 

// 1. موديل البيانات المحدث ليشمل العهدة
class DashboardData {
  final int totalProducts;
  final int totalOrders;
  final int pendingOrders;
  final double totalSales;
  final double securityPoints; // ✨ نقاط الأمان (العهدة)

  DashboardData({
    required this.totalProducts,
    required this.totalOrders,
    required this.pendingOrders,
    required this.totalSales,
    required this.securityPoints,
  });
}

class DeliveryMerchantDashboardScreen extends StatefulWidget {
  static const routeName = '/deliveryMerchantDashboard'; 

  const DeliveryMerchantDashboardScreen({super.key});

  @override
  State<DeliveryMerchantDashboardScreen> createState() => _DeliveryMerchantDashboardScreenState();
}

class _DeliveryMerchantDashboardScreenState extends State<DeliveryMerchantDashboardScreen> {
  Future<DashboardData>? _dashboardDataFuture;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 2. جلب البيانات الشاملة من فايرستور
  Future<DashboardData> _fetchDashboardData(String userId) async {
    // جلب عدد المنتجات النشطة
    final productsSnapshot = await _firestore.collection("marketOffer")
        .where("ownerId", isEqualTo: userId)
        .where("status", isEqualTo: "active")
        .count().get();

    // جلب إحصائيات الطلبات
    final ordersRef = _firestore.collection("consumerorders");
    final allOrdersSnapshot = await ordersRef.where("supermarketId", isEqualTo: userId).count().get();
    final pendingOrdersSnapshot = await ordersRef
        .where("supermarketId", isEqualTo: userId)
        .where("status", whereIn: ["new-order", "pending", "processing"]).count().get();

    // حساب إجمالي المبيعات للطلبات المسلمة
    final deliveredOrdersDocs = await ordersRef
        .where("supermarketId", isEqualTo: userId)
        .where("status", isEqualTo: "delivered").get();
    
    double totalSales = 0;
    for (var doc in deliveredOrdersDocs.docs) {
      final data = doc.data();
      if (data.containsKey('finalAmount')) {
        totalSales += double.tryParse(data['finalAmount'].toString()) ?? 0.0;
      }
    }

    // ✨ جلب "نقاط الأمان" من سجلات السوبر ماركت (العهدة المباشرة)
    final merchantSnapshot = await _firestore.collection("deliverySupermarkets")
        .where("ownerId", isEqualTo: userId)
        .limit(1).get();
    
    double securityPoints = 0;
    if (merchantSnapshot.docs.isNotEmpty) {
      securityPoints = double.tryParse(merchantSnapshot.docs.first.data()['walletBalance'].toString()) ?? 0.0;
    }

    return DashboardData(
      totalProducts: productsSnapshot.count ?? 0,
      totalOrders: allOrdersSnapshot.count ?? 0,
      pendingOrders: pendingOrdersSnapshot.count ?? 0,
      totalSales: totalSales,
      securityPoints: securityPoints,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_dashboardDataFuture == null) {
      final buyerData = Provider.of<BuyerDataProvider>(context, listen: false);
      final userId = buyerData.loggedInUser?.id;
      
      if (userId != null && userId.isNotEmpty) {
        _dashboardDataFuture = _fetchDashboardData(userId);
      } else {
        _dashboardDataFuture = Future.error("لم يتم تسجيل الدخول");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final buyerProvider = Provider.of<BuyerDataProvider>(context);
    final userName = buyerProvider.loggedInUser?.fullname ?? 'التاجر';
    final planName = buyerProvider.planName; 

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('لوحة تحكم المتجر', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
      ),
      drawer: const DeliveryMerchantSidebarWidget(),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() {
            _dashboardDataFuture = _fetchDashboardData(buyerProvider.loggedInUser!.id!);
          });
        },
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.white, Colors.blue.withOpacity(0.05)],
            ),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildWelcomeHeader(userName, planName),
                const SizedBox(height: 32),
                FutureBuilder<DashboardData>(
                  future: _dashboardDataFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: Padding(
                        padding: EdgeInsets.all(50.0),
                        child: CircularProgressIndicator(),
                      ));
                    } else if (snapshot.hasError) {
                      return _buildErrorState(snapshot.error.toString());
                    } else if (snapshot.hasData) {
                      return _buildStatsGrid(snapshot.data!, context);
                    }
                    return const Center(child: Text('لا توجد بيانات متاحة حالياً.'));
                  },
                ),
                const SizedBox(height: 40),
                _buildInfoFooter(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeHeader(String name, String plan) {
    bool isFree = plan.contains('مجانية') || plan.contains('تجريبية');
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: isFree ? Colors.green[50] : Colors.amber[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isFree ? Colors.green : Colors.amber.shade700),
          ),
          child: Row(
            children: [
              Icon(isFree ? Icons.bolt : Icons.workspace_premium, 
                   size: 14, color: isFree ? Colors.green : Colors.amber.shade800),
              const SizedBox(width: 4),
              Text(plan, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('أهلاً بك، $name 👋', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
            Text('إليك أداء متجرك اليوم', style: TextStyle(fontSize: 12, color: Colors.grey[600], fontFamily: 'Cairo')),
          ],
        ),
      ],
    );
  }

  Widget _buildStatsGrid(DashboardData data, BuildContext context) {
    return GridView.count(
      crossAxisCount: MediaQuery.of(context).size.width > 600 ? 5 : 2,
      crossAxisSpacing: 14,
      mainAxisSpacing: 14,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _DashboardCard(
          icon: Icons.verified_user_outlined,
          title: 'نقاط الأمان',
          value: '${data.securityPoints.toStringAsFixed(0)} ن',
          color: Colors.teal,
          onTap: () {
            // ✨ الآن الكلاس معرف بفضل الـ Import الصحيح وبدون كلمة const
            Navigator.push(
              context, 
              MaterialPageRoute(builder: (context) => MerchantPointBalanceScreen())
            );
          },
        ),
        _DashboardCard(
          icon: Icons.monetization_on_outlined,
          title: 'المبيعات',
          value: '${data.totalSales.toStringAsFixed(0)} ج.م',
          color: Colors.green,
        ),
        _DashboardCard(
          icon: Icons.shopping_bag_outlined,
          title: 'الطلبات',
          value: data.totalOrders.toString(),
          color: Colors.orange,
        ),
        _DashboardCard(
          icon: Icons.hourglass_empty_rounded,
          title: 'انتظار',
          value: data.pendingOrders.toString(),
          color: Colors.redAccent,
        ),
        _DashboardCard(
          icon: Icons.inventory_2_outlined,
          title: 'المنتجات',
          value: data.totalProducts.toString(),
          color: Colors.blue,
        ),
      ],
    );
  }

  Widget _buildErrorState(String error) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(12)),
      child: Text('خطأ في الاتصال بالسيرفر', style: const TextStyle(color: Colors.red, fontFamily: 'Cairo'), textAlign: TextAlign.center),
    );
  }

  Widget _buildInfoFooter() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          const Icon(Icons.security_update_good, color: Colors.teal),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'يمكنك الضغط على كارت "نقاط الأمان" لمراجعة تفاصيل عهدة الطلبات والتسويات اللوجستية.',
              style: TextStyle(color: Colors.grey[700], fontSize: 11, fontFamily: 'Cairo'),
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color color;
  final VoidCallback? onTap;

  const _DashboardCard({
    required this.icon, 
    required this.title, 
    required this.value,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.08),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 26, color: color),
              const SizedBox(height: 10),
              Text(
                title,
                style: TextStyle(fontSize: 11, color: Colors.grey[600], fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  value,
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
