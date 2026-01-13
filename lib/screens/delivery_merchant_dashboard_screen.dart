// lib/screens/delivery_merchant_dashboard_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:my_test_app/providers/buyer_data_provider.dart';
import 'package:my_test_app/widgets/delivery_merchant_sidebar_widget.dart';
import 'package:google_fonts/google_fonts.dart'; // تأكد من وجود المكتبة في pubspec.yaml

// ... (نفس موديل DashboardData ونفس الـ Logic في الدالة _fetchDashboardData بدون تغيير)

  @override
  Widget build(BuildContext context) {
    final userName = Provider.of<BuyerDataProvider>(context).loggedInUser?.fullname ?? 'التاجر';
    final primaryColor = const Color(0xFF1a237e); // أزرق ملكي عميق
    final accentColor = const Color(0xFF00c853);  // أخضر حيوي للمبيعات

    return Scaffold(
      backgroundColor: Colors.grey[50], // خلفية فاتحة مريحة للعين
      appBar: AppBar(
        elevation: 0,
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        centerTitle: true,
        title: Text('لوحة التحكم', style: GoogleFonts.notoSansArabic(fontWeight: FontWeight.bold)),
      ),
      drawer: const DeliveryMerchantSidebarWidget(),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // رأس الصفحة جذاب بتصميم منحني أو خلفية ملونة
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
              decoration: BoxDecoration(
                color: primaryColor,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'مرحباً بك،',
                    style: GoogleFonts.notoSansArabic(color: Colors.white70, fontSize: 16),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    userName,
                    style: GoogleFonts.notoSansArabic(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 25), // Sezer للمسافة

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: FutureBuilder<DashboardData>(
                future: _dashboardDataFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: Padding(
                      padding: EdgeInsets.all(50.0),
                      child: CircularProgressIndicator(),
                    ));
                  } else if (snapshot.hasError) {
                    return _buildErrorWidget(snapshot.error.toString());
                  } else if (snapshot.hasData) {
                    final data = snapshot.data!;
                    return GridView.count(
                      crossAxisCount: 2,
                      crossAxisSpacing: 15,
                      mainAxisSpacing: 15,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      childAspectRatio: 0.9, // لجعل الكروت مربعة متناسقة
                      children: [
                        _DashboardCard(
                          title: 'المنتجات',
                          value: data.totalProducts.toString(),
                          icon: Icons.inventory_2_outlined,
                          color1: const Color(0xFF6441A5),
                          color2: const Color(0xFF2a0845),
                        ),
                        _DashboardCard(
                          title: 'إجمالي الطلبات',
                          value: data.totalOrders.toString(),
                          icon: Icons.shopping_bag_outlined,
                          color1: const Color(0xFF2193b0),
                          color2: const Color(0xFF6dd5ed),
                        ),
                        _DashboardCard(
                          title: 'طلبات معلقة',
                          value: data.pendingOrders.toString(),
                          icon: Icons.pending_outlined,
                          color1: const Color(0xFFee0979),
                          color2: const Color(0xFFff6a00),
                        ),
                        _DashboardCard(
                          title: 'المبيعات (ج.م)',
                          value: data.totalSales.toStringAsFixed(0),
                          icon: Icons.monetization_on_outlined,
                          color1: const Color(0xFF11998e),
                          color2: const Color(0xFF38ef7d),
                        ),
                      ],
                    );
                  }
                  return const SizedBox();
                },
              ),
            ),
            
            const SizedBox(height: 30),
            
            // ويدجت إضافي لإضفاء مظهر احترافي
            _buildQuickActionBanner(),
            
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // --- بناء الكرت الاحترافي بتدرج ألوان ---
  Widget _buildErrorWidget(String error) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(15)),
      child: Text('خطأ: $error', style: const TextStyle(color: Colors.red)),
    );
  }

  Widget _buildQuickActionBanner() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5))],
      ),
      child: Row(
        children: [
          const Icon(Icons.tips_and_updates, color: Colors.amber, size: 30),
          const SizedBox(width: 15),
          Expanded(
            child: Text(
              'نصيحة: تأكد من تحديث حالة الطلبات المعلقة لزيادة تقييم متجرك.',
              style: GoogleFonts.notoSansArabic(fontSize: 14, color: Colors.blueGrey[800]),
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color1;
  final Color color2;

  const _DashboardCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color1,
    required this.color2,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(25),
        gradient: LinearGradient(
          colors: [color1, color2],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: color1.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack( // استخدام Stack لإضافة لمسة جمالية (أيقونة شفافة في الخلفية)
        children: [
          Positioned(
            right: -10,
            bottom: -10,
            child: Icon(icon, size: 80, color: Colors.white.withOpacity(0.15)),
          ),
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: Colors.white, size: 30),
                const SizedBox(height: 15),
                Text(
                  title,
                  style: GoogleFonts.notoSansArabic(
                    color: Colors.white70,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 5),
                FittedBox( // لضمان عدم خروج النص الكبير عن حدود الكرت
                  child: Text(
                    value,
                    style: GoogleFonts.notoSansArabic(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
