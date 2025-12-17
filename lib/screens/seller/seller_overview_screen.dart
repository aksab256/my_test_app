import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:my_test_app/controllers/seller_dashboard_controller.dart';
import 'package:sizer/sizer.dart';

class SellerOverviewScreen extends StatelessWidget {
  const SellerOverviewScreen({super.key});

  // كارت إحصائيات ضخم وعريض
  Widget _buildBigStatCard(BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: 2.h),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: color.withOpacity(0.2), width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 35),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13.sp,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 20.sp,
                    fontWeight: FontWeight.w900,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.arrow_forward_ios_rounded, color: Colors.grey.shade300, size: 20),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = Provider.of<SellerDashboardController>(context);
    final data = controller.data;

    if (controller.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (controller.errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Text(
            controller.errorMessage!,
            style: TextStyle(color: Colors.red, fontSize: 14.sp, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => controller.loadDashboardData(controller.sellerId),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 2.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ترحيب ضخم
            Text(
              controller.welcomeMessage,
              style: TextStyle(
                fontSize: 20.sp,
                fontWeight: FontWeight.w900,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              "إليك ملخص نشاطك التجاري اليوم",
              style: TextStyle(fontSize: 12.sp, color: Colors.grey),
            ),
            const SizedBox(height: 30),

            // الكارتات الضخمة
            _buildBigStatCard(
              context,
              title: 'إجمالي المبيعات المكتملة',
              value: '${data.completedSalesAmount.toStringAsFixed(2)} ج.م',
              icon: Icons.account_balance_wallet_rounded,
              color: const Color(0xFF2D9E68),
            ),
            _buildBigStatCard(
              context,
              title: 'طلبات جديدة ملموسة',
              value: data.newOrdersCount.toString(),
              icon: Icons.notification_important_rounded,
              color: Colors.redAccent,
            ),
            _buildBigStatCard(
              context,
              title: 'إجمالي الطلبات المستلمة',
              value: data.totalOrders.toString(),
              icon: Icons.shopping_basket_rounded,
              color: Colors.blueAccent,
            ),
            _buildBigStatCard(
              context,
              title: 'طلبات قيد التجهيز',
              value: data.pendingOrdersCount.toString(),
              icon: Icons.pending_actions_rounded,
              color: Colors.orangeAccent,
            ),

            // 🟢 تم إزالة جزء "مناطق التوصيل" من هنا لحل مشكلة النوع (TypeError) 🟢
            // ولأنها موجودة بالفعل في صفحة مستقلة للإعدادات.
            
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
