import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:my_test_app/controllers/seller_dashboard_controller.dart';
import 'package:sizer/sizer.dart';

class SellerOverviewScreen extends StatelessWidget {
  const SellerOverviewScreen({super.key});

  // كارت إحصائيات ضخم وعريض (تم إزالة السهم وتعديل التصميم ليكون إحصائي فقط)
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
            color: color.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
        // خط جانبي ملون يعطي شكلاً جمالياً دون الحاجة لسهم
        border: Border(
          right: BorderSide(color: color.withOpacity(0.5), width: 5),
          left: BorderSide(color: color.withOpacity(0.1), width: 1),
          top: BorderSide(color: color.withOpacity(0.1), width: 1),
          bottom: BorderSide(color: color.withOpacity(0.1), width: 1),
        ),
      ),
      child: Row(
        children: [
          // أيقونة دائرية
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 30.sp),
          ),
          const SizedBox(width: 20),
          // النصوص
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Cairo',
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w900,
                    color: color,
                    fontFamily: 'Cairo',
                  ),
                ),
              ],
            ),
          ),
          // ✅ تم إزالة أيقونة arrow_forward_ios_rounded لضمان قبول جوجل بلاي
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
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, color: Colors.red, size: 40.sp),
              const SizedBox(height: 10),
              Text(
                controller.errorMessage!,
                style: TextStyle(color: Colors.red, fontSize: 13.sp, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
                textAlign: TextAlign.center,
              ),
              TextButton(
                onPressed: () => controller.loadDashboardData(controller.sellerId),
                child: const Text("إعادة المحاولة", style: TextStyle(fontFamily: 'Cairo')),
              )
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      color: const Color(0xff28a745),
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
                fontSize: 18.sp,
                fontWeight: FontWeight.w900,
                color: Theme.of(context).colorScheme.primary,
                fontFamily: 'Cairo',
              ),
            ),
            const SizedBox(height: 5),
            Text(
              "إليك ملخص نشاطك التجاري اليوم",
              style: TextStyle(fontSize: 11.sp, color: Colors.grey, fontFamily: 'Cairo'),
            ),
            const SizedBox(height: 25),

            // الكارتات الإحصائية (تم تعديلها)
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
            
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
