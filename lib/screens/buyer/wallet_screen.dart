import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sizer/sizer.dart'; 
import 'package:google_fonts/google_fonts.dart';
import '../../providers/cashback_provider.dart';
import '../../providers/buyer_data_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/buyer_mobile_nav_widget.dart';
import 'gifts_tab.dart'; 

class WalletScreen extends StatelessWidget {
  static const String routeName = '/wallet';
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          Navigator.pushReplacementNamed(context, '/buyerHome');
        },
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            backgroundColor: const Color(0xFFF8F9FA),
            appBar: AppBar(
              backgroundColor: AppTheme.primaryGreen,
              elevation: 0,
              title: Text(
                'المحفظة والعروض',
                style: GoogleFonts.cairo(fontSize: 18.sp, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              centerTitle: true,
              bottom: TabBar(
                indicatorColor: Colors.orangeAccent,
                indicatorWeight: 4,
                labelStyle: GoogleFonts.cairo(fontSize: 14.sp, fontWeight: FontWeight.bold),
                tabs: const [
                  Tab(text: "أهداف الكاش باك"),
                  Tab(text: "هدايا المنطقة"),
                ],
              ),
            ),
            body: SafeArea(
              child: TabBarView(
                children: [
                  _buildCashbackTab(context),
                  const GiftsTab(),
                ],
              ),
            ),
            bottomNavigationBar: BuyerMobileNavWidget(
              selectedIndex: 3,
              onItemSelected: (index) {
                if (index == 3) return;
                if (index == 0) Navigator.pushReplacementNamed(context, '/traders');
                if (index == 1) Navigator.pushReplacementNamed(context, '/buyerHome');
                if (index == 2) Navigator.pushReplacementNamed(context, '/myOrders');
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCashbackTab(BuildContext context) {
    final buyerData = Provider.of<BuyerDataProvider>(context);
    final cashbackProvider = Provider.of<CashbackProvider>(context);

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(15.sp),
          decoration: BoxDecoration(
            color: AppTheme.primaryGreen,
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(25),
              bottomRight: Radius.circular(25),
            ),
          ),
          child: Column(
            children: [
              Text(
                'أهلاً، ${buyerData.loggedInUser?.fullname ?? 'زائر'}',
                style: GoogleFonts.cairo(fontSize: 14.sp, color: Colors.white70),
              ),
              SizedBox(height: 10.sp),
              _buildBalanceCard(cashbackProvider),
            ],
          ),
        ),
        
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => Provider.of<CashbackProvider>(context, listen: false).fetchCashbackGoals(),
            child: _buildCashbackGoalsList(),
          ),
        ),
      ],
    );
  }

  Widget _buildBalanceCard(CashbackProvider provider) {
    return FutureBuilder<double>(
      future: provider.fetchCashbackBalance(),
      builder: (context, snapshot) {
        double balance = snapshot.data ?? 0.0;
        return Container(
          padding: EdgeInsets.symmetric(horizontal: 15.sp, vertical: 12.sp),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.white30),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('رصيد الكاش باك:', style: GoogleFonts.cairo(fontSize: 14.sp, color: Colors.white)),
              Text(
                '${balance.toStringAsFixed(2)} ج',
                style: GoogleFonts.cairo(fontSize: 18.sp, fontWeight: FontWeight.w900, color: const Color(0xFFFFD700)),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCashbackGoalsList() {
    return Consumer<CashbackProvider>(
      builder: (context, provider, _) {
        return FutureBuilder<List<Map<String, dynamic>>>(
          future: provider.fetchCashbackGoals(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final goals = snapshot.data ?? [];
            if (goals.isEmpty) {
              return Center(child: Text('لا توجد عروض نشطة حالياً', style: GoogleFonts.cairo(fontSize: 15.sp)));
            }
            return ListView.builder(
              padding: EdgeInsets.all(12.sp),
              itemCount: goals.length,
              itemBuilder: (context, index) => _buildGoalCard(goals[index]),
            );
          },
        );
      },
    );
  }

  // 🔥 التعديل الجوهري هنا للتفرقة بين أنواع الأهداف
  Widget _buildGoalCard(Map<String, dynamic> goal) {
    // 1. تحديد نوع الهدف
    bool isCumulative = goal['goalBasis'] == 'cumulative_spending';
    double progress = (goal['progressPercentage'] ?? 0.0).toDouble();
    Color progressColor = progress >= 100 ? Colors.green : Colors.orange;

    // 2. حساب الوقت المتبقي
    final now = DateTime.now();
    final endDate = goal['endDate'] as DateTime;
    final daysLeft = endDate.difference(now).inDays;

    return Card(
      elevation: 2,
      margin: EdgeInsets.only(bottom: 12.sp),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: isCumulative ? BorderSide.none : BorderSide(color: Colors.blue.shade100, width: 1),
      ),
      child: Padding(
        padding: EdgeInsets.all(12.sp),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // العنوان والتاجر
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(goal['title'], 
                    style: GoogleFonts.cairo(fontSize: 15.sp, fontWeight: FontWeight.bold, color: AppTheme.primaryGreen)),
                ),
                if (!isCumulative)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8.sp, vertical: 2.sp),
                    decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(5)),
                    child: Text("طلب فردي", style: GoogleFonts.cairo(fontSize: 9.sp, color: Colors.blue.shade800)),
                  ),
              ],
            ),
            
            SizedBox(height: 5.sp),
            
            // الوصف
            Text(
              isCumulative 
                ? "مطلوب شراء بإجمالي ${goal['minAmount']} ج خلال فترة العرض"
                : "كل طلب بقيمة ${goal['minAmount']} ج يمنحك كاش باك ${goal['value']} ج",
              style: GoogleFonts.cairo(fontSize: 12.sp, color: Colors.black87),
            ),

            if (isCumulative) ...[
              SizedBox(height: 10.sp),
              // شريط التقدم (للتراكمي فقط)
              LinearProgressIndicator(
                value: (progress / 100).clamp(0.0, 1.0),
                minHeight: 8,
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation<Color>(progressColor),
              ),
              SizedBox(height: 5.sp),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('حققت: ${goal['currentProgress']} ج من ${goal['minAmount']} ج', 
                    style: GoogleFonts.cairo(fontSize: 11.sp, color: Colors.grey[600])),
                  Text('%${progress.toStringAsFixed(0)}', 
                    style: GoogleFonts.cairo(fontSize: 12.sp, color: progressColor, fontWeight: FontWeight.bold)),
                ],
              ),
            ],

            Divider(height: 20.sp, color: Colors.grey[100]),

            // الوقت المتبقي
            Row(
              children: [
                Icon(Icons.timer_outlined, size: 13.sp, color: Colors.redAccent),
                SizedBox(width: 5.sp),
                Text(
                  daysLeft > 0 ? "متبقي $daysLeft يوم على انتهاء العرض" : "العرض ينتهي اليوم!",
                  style: GoogleFonts.cairo(fontSize: 11.sp, color: Colors.redAccent, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
