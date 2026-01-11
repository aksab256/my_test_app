// lib/screens/buyer/wallet_screen.dart

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
              toolbarHeight: 70, // زيادة مساحة العنوان
              title: Text(
                'المحفظة والعروض',
                style: GoogleFonts.cairo(
                  fontSize: 20.sp, // خط كبير وواضح
                  fontWeight: FontWeight.bold, 
                  color: Colors.white
                ),
              ),
              centerTitle: true,
              bottom: TabBar(
                indicatorColor: Colors.orangeAccent,
                indicatorWeight: 4,
                labelStyle: GoogleFonts.cairo(fontSize: 16.sp, fontWeight: FontWeight.bold),
                unselectedLabelStyle: GoogleFonts.cairo(fontSize: 14.sp),
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
        // كارت الرصيد العلوي المحدث
        Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(horizontal: 20.sp, vertical: 20.sp),
          decoration: BoxDecoration(
            color: AppTheme.primaryGreen,
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(30),
              bottomRight: Radius.circular(30),
            ),
          ),
          child: Column(
            children: [
              Text(
                'أهلاً، ${buyerData.loggedInUser?.fullname ?? 'زائر'}',
                style: GoogleFonts.cairo(fontSize: 16.sp, color: Colors.white70),
              ),
              SizedBox(height: 12.sp),
              _buildBalanceCard(cashbackProvider),
            ],
          ),
        ),
        
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => Provider.of<CashbackProvider>(context, listen: false).fetchAvailableOffers(),
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
          padding: EdgeInsets.all(15.sp),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white24),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'رصيدك المتاح: ',
                style: GoogleFonts.cairo(fontSize: 18.sp, color: Colors.white),
              ),
              Text(
                '${balance.toStringAsFixed(2)} ج',
                style: GoogleFonts.cairo(
                  fontSize: 22.sp, 
                  fontWeight: FontWeight.w900, 
                  color: const Color(0xFFFFD700) // لون ذهبي للرصيد
                ),
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
          future: provider.fetchAvailableOffers(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final goals = snapshot.data ?? [];
            if (goals.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.receipt_long_outlined, size: 60.sp, color: Colors.grey[300]),
                    Text('لا توجد عروض حالياً', style: GoogleFonts.cairo(fontSize: 18.sp, color: Colors.grey)),
                  ],
                ),
              );
            }
            return ListView.builder(
              padding: EdgeInsets.fromLTRB(15.sp, 15.sp, 15.sp, 30.sp),
              itemCount: goals.length,
              itemBuilder: (context, index) => _buildGoalCard(goals[index]),
            );
          },
        );
      },
    );
  }

  Widget _buildGoalCard(Map<String, dynamic> goal) {
    // التوافق مع مسميات لوحة التحكم الجديدة
    bool isCumulative = goal['targetType'] == 'cumulative_period';
    double minAmount = (goal['minAmount'] ?? 0.0).toDouble();
    double currentProgress = (goal['currentProgress'] ?? 0.0).toDouble();
    
    double progressPercent = minAmount > 0 ? (currentProgress / minAmount) : 0.0;
    if (progressPercent > 1.0) progressPercent = 1.0;
    
    Color progressColor = progressPercent >= 1.0 ? Colors.green : Colors.orange;

    return Card(
      elevation: 4,
      margin: EdgeInsets.only(bottom: 18.sp),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: EdgeInsets.all(16.sp),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    goal['description'] ?? 'عرض كاش باك',
                    style: GoogleFonts.cairo(
                      fontSize: 18.sp, // تكبير الخط كما طلبت
                      fontWeight: FontWeight.bold, 
                      color: AppTheme.primaryGreen,
                      height: 1.2
                    ),
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10.sp, vertical: 4.sp),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${goal['value']}${goal['type'] == 'percentage' ? '%' : 'ج'}',
                    style: GoogleFonts.cairo(fontSize: 20.sp, fontWeight: FontWeight.w900, color: Colors.orange[800]),
                  ),
                ),
              ],
            ),
            
            SizedBox(height: 10.sp),
            
            Text(
              isCumulative 
                ? "هدف تراكمي: اشترِ بمجموع ${goal['minAmount']} ج"
                : "كاش باك فوري على كل طلب بـ ${goal['minAmount']} ج",
              style: GoogleFonts.cairo(fontSize: 15.sp, color: Colors.black87, fontWeight: FontWeight.w600),
            ),

            if (isCumulative) ...[
              SizedBox(height: 15.sp),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: progressPercent,
                  minHeight: 12,
                  backgroundColor: Colors.grey[200],
                  valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                ),
              ),
              SizedBox(height: 8.sp),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('المحقَّق: ${currentProgress.toStringAsFixed(0)} ج', 
                    style: GoogleFonts.cairo(fontSize: 14.sp, color: Colors.grey[700], fontWeight: FontWeight.bold)),
                  Text('%${(progressPercent * 100).toStringAsFixed(0)}', 
                    style: GoogleFonts.cairo(fontSize: 16.sp, color: progressColor, fontWeight: FontWeight.bold)),
                ],
              ),
            ],

            Padding(
              padding: EdgeInsets.symmetric(vertical: 12.sp),
              child: Divider(height: 1, color: Colors.grey[200]),
            ),

            Row(
              children: [
                Icon(Icons.calendar_month, size: 16.sp, color: Colors.redAccent),
                SizedBox(width: 5.sp),
                Text(
                  "متبقي ${goal['daysRemaining']} يوم",
                  style: GoogleFonts.cairo(fontSize: 14.sp, color: Colors.redAccent, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Icon(Icons.storefront, size: 16.sp, color: Colors.blueGrey),
                SizedBox(width: 4.sp),
                Text(
                  goal['sellerName'] ?? 'كل التجار',
                  style: GoogleFonts.cairo(fontSize: 14.sp, color: Colors.blueGrey, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
