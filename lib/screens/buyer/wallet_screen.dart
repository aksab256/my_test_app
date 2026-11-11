// المسار: lib/screens/buyer/wallet_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sizer/sizer.dart'; 
import 'package:google_fonts/google_fonts.dart';
import '../../providers/cashback_provider.dart';
import '../../providers/buyer_data_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/buyer_mobile_nav_widget.dart';
import 'gifts_tab.dart'; 

// 🎯 استيراد الصفحة مباشرة لضمان عمل التوجيه المباشر وزر الرجوع
import 'package:my_test_app/screens/buyer/my_orders_screen.dart';

class WalletScreen extends StatefulWidget {
  static const String routeName = '/wallet';
  final int initialTabIndex;
  const WalletScreen({super.key, this.initialTabIndex = 0});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {

  @override
  void initState() {
    super.initState();
    // جلب البيانات فور فتح الصفحة
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final cashbackProvider = Provider.of<CashbackProvider>(context, listen: false);
      cashbackProvider.fetchCashbackBalance();
      cashbackProvider.fetchAvailableOffers();
      cashbackProvider.fetchEarnHistory();
    });
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      initialIndex: widget.initialTabIndex.clamp(0, 1),
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
              toolbarHeight: 70,
              title: Text(
                'المحفظة والعروض',
                style: GoogleFonts.cairo(
                  fontSize: 20.sp,
                  fontWeight: FontWeight.bold, 
                  color: Colors.white
                ),
              ),
              centerTitle: true,
              bottom: TabBar(
                indicatorColor: Colors.orangeAccent,
                indicatorWeight: 4,
                labelStyle: GoogleFonts.cairo(fontSize: 16.sp, fontWeight: FontWeight.bold),
                tabs: const [
                  Tab(text: "أهداف الكاش باك"),
                  Tab(text: "هدايا المنطقة"),
                ],
              ),
            ),
            body: SafeArea(
              child: TabBarView(
                children: [
                  _buildCashbackTab(),
                  const GiftsTab(),
                ],
              ),
            ),
            bottomNavigationBar: BuyerMobileNavWidget(
              selectedIndex: 3,
              // ✅ إضافة القيم التي قد تسبب Null check operator error
              cartCount: 0, 
              ordersChanged: false,
              onItemSelected: (index) {
                if (index == 3) return;
                if (index == 0) Navigator.pushReplacementNamed(context, '/traders');
                if (index == 1) Navigator.pushReplacementNamed(context, '/buyerHome');
                
                // ✅ تعديل أيقونة الطلبات لتفتح مباشرة لضمان عمل زر الرجوع
                if (index == 2) {
                  Navigator.push(
                    context, 
                    MaterialPageRoute(builder: (context) => const MyOrdersScreen())
                  );
                }
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCashbackTab() {
    return Consumer2<BuyerDataProvider, CashbackProvider>(
      builder: (context, buyerData, cashbackProvider, child) {
        return Column(
          children: [
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(horizontal: 20.sp, vertical: 20.sp),
              decoration: const BoxDecoration(
                color: AppTheme.primaryGreen,
                borderRadius: BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30)),
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
                onRefresh: () async {
                  await cashbackProvider.fetchCashbackBalance();
                  await cashbackProvider.fetchAvailableOffers();
                  await cashbackProvider.fetchEarnHistory();
                },
                child: _buildCashbackGoalsList(cashbackProvider),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildBalanceCard(CashbackProvider provider) {
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
          Text('رصيدك المتاح: ', style: GoogleFonts.cairo(fontSize: 18.sp, color: Colors.white)),
          Text(
            '${provider.availableBalance.toStringAsFixed(2)} ج',
            style: GoogleFonts.cairo(
              fontSize: 22.sp, 
              fontWeight: FontWeight.w900, 
              color: const Color(0xFFFFD700) 
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCashbackGoalsList(CashbackProvider provider) {
    if (provider.isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen));
    }

    final goals = provider.offersList;

    if (goals.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: 10.h),
          Center(
            child: Column(
              children: [
                Icon(Icons.receipt_long_outlined, size: 60.sp, color: Colors.grey[300]),
                Text('لا توجد عروض حالياً', style: GoogleFonts.cairo(fontSize: 18.sp, color: Colors.grey)),
              ],
            ),
          ),
        ],
      );
    }

    final history = provider.earnHistory;
    return ListView.builder(
      padding: EdgeInsets.fromLTRB(15.sp, 15.sp, 15.sp, 30.sp),
      itemCount: goals.length + (history.isEmpty ? 0 : history.length + 1),
      itemBuilder: (context, index) {
        if (index < goals.length) return _buildGoalCard(goals[index]);
        final hIndex = index - goals.length;
        if (hIndex == 0) {
          return Padding(
            padding: EdgeInsets.only(top: 10.sp, bottom: 6.sp),
            child: Text('سجل المستحقات',
                style: GoogleFonts.cairo(fontSize: 17.sp, fontWeight: FontWeight.bold, color: AppTheme.primaryGreen)),
          );
        }
        return _buildHistoryTile(history[hIndex - 1]);
      },
    );
  }

  Widget _buildHistoryTile(Map<String, dynamic> entry) {
    final double amount = (entry['amount'] ?? 0.0).toDouble();
    final String type = entry['type'] ?? '';
    final bool isCumulative = type == 'CASHBACK_EARNED_CUMULATIVE';
    return Card(
      margin: EdgeInsets.only(bottom: 10.sp),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppTheme.primaryGreen.withValues(alpha: 0.12),
          child: Text('+${amount.toStringAsFixed(0)}',
              style: GoogleFonts.cairo(fontSize: 11.sp, fontWeight: FontWeight.bold, color: AppTheme.primaryGreen)),
        ),
        title: Text(isCumulative ? 'مكافأة تراكمية' : (amount < 0 ? 'صرف كاش باك' : 'كاش باك فوري'),
            style: GoogleFonts.cairo(fontSize: 15.sp, fontWeight: FontWeight.w600)),
        subtitle: Text(
          "${entry['fundingSource'] == 'seller' ? 'تمويل التاجر' : 'تمويل المنصة'}"
          "${entry['orderId'] != '' ? ' • طلب ${entry['orderId']}' : ''}",
          style: GoogleFonts.cairo(fontSize: 13.sp, color: Colors.blueGrey),
        ),
      ),
    );
  }

  Widget _buildGoalCard(Map<String, dynamic> goal) {
    bool isCumulative = goal['targetType'] == 'cumulative_period';
    double minAmount = (goal['minAmount'] ?? 0.0).toDouble();
    double currentProgress = (goal['currentProgress'] ?? 0.0).toDouble();
    double progressPercent = minAmount > 0 ? (currentProgress / minAmount).clamp(0.0, 1.0) : 0.0;
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
              children: [
                Expanded(
                  child: Text(
                    goal['description'] ?? 'عرض كاش باك',
                    style: GoogleFonts.cairo(fontSize: 18.sp, fontWeight: FontWeight.bold, color: AppTheme.primaryGreen),
                  ),
                ),
                Text(
                  '${goal['value']}${goal['type'] == 'percentage' ? '%' : 'ج'}',
                  style: GoogleFonts.cairo(fontSize: 20.sp, fontWeight: FontWeight.w900, color: Colors.orange[800]),
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('المحقَّق: ${currentProgress.toStringAsFixed(0)} ج', 
                    style: GoogleFonts.cairo(fontSize: 14.sp, fontWeight: FontWeight.bold)),
                  Text('%${(progressPercent * 100).toStringAsFixed(0)}', 
                    style: GoogleFonts.cairo(fontSize: 16.sp, color: progressColor, fontWeight: FontWeight.bold)),
                ],
              ),
            ],
            Row(
              children: [
                Icon(Icons.account_balance_wallet_outlined, size: 16.sp, color: AppTheme.primaryGreen),
                Text(" ${goal['fundLabel'] ?? 'الممول غير محدد'} • ${goal['scopeLabel'] ?? 'كل التجار'}",
                  style: GoogleFonts.cairo(fontSize: 14.sp, fontWeight: FontWeight.w600, color: Colors.black87)),
              ],
            ),
            const Divider(),
            Row(
              children: [
                Icon(Icons.calendar_month, size: 16.sp, color: Colors.redAccent),
                Text(" متبقي ${goal['daysRemaining']} يوم", 
                  style: GoogleFonts.cairo(fontSize: 14.sp, color: Colors.redAccent, fontWeight: FontWeight.bold)),
                const Spacer(),
                Text(goal['sellerName'] ?? 'كل التجار', 
                  style: GoogleFonts.cairo(fontSize: 14.sp, color: Colors.blueGrey, fontWeight: FontWeight.w600)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

