// lib/screens/buyer/wallet_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart' as intl;
import 'package:sizer/sizer.dart'; // للتحكم الاحترافي في المقاسات
import 'package:google_fonts/google_fonts.dart';
import '../../providers/cashback_provider.dart';
import '../../providers/buyer_data_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/buyer_mobile_nav_widget.dart';

class WalletScreen extends StatelessWidget {
  static const String routeName = '/wallet';
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.pushReplacementNamed(context, '/buyerHome');
      },
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: const Color(0xFFF8F9FA), // لون مريح للعين
          body: SafeArea( // 🛡️ حماية المحتوى من الحواف
            child: Column(
              children: [
                _buildTopHeader(context),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () => Provider.of<CashbackProvider>(context, listen: false).fetchCashbackGoals(),
                    child: _buildCashbackGoalsList(),
                  ),
                ),
              ],
            ),
          ),
          bottomNavigationBar: BuyerMobileNavWidget(
            selectedIndex: 3, // المحفظة هي رقم 3
            onItemSelected: (index) {
              if (index == 3) return;
              if (index == 0) Navigator.pushReplacementNamed(context, '/traders');
              if (index == 1) Navigator.pushReplacementNamed(context, '/buyerHome');
              if (index == 2) Navigator.pushReplacementNamed(context, '/myOrders');
            },
          ),
        ),
      ),
    );
  }

  Widget _buildTopHeader(BuildContext context) {
    final buyerData = Provider.of<BuyerDataProvider>(context);
    final cashbackProvider = Provider.of<CashbackProvider>(context);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20.sp),
      decoration: BoxDecoration(
        color: AppTheme.primaryGreen,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 5))],
      ),
      child: Column(
        children: [
          Text(
            'أهدافي للكاش باك',
            style: GoogleFonts.cairo(fontSize: 22.sp, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          SizedBox(height: 10.sp),
          Text(
            'أهلاً بك، ${buyerData.loggedInUser?.fullname ?? 'زائر'}!',
            style: GoogleFonts.cairo(fontSize: 16.sp, color: Colors.white70),
          ),
          SizedBox(height: 20.sp),
          _buildBalanceCard(cashbackProvider),
        ],
      ),
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
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.white30),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('رصيد المحفظة:', style: GoogleFonts.cairo(fontSize: 18.sp, color: Colors.white)),
              Text(
                '${balance.toStringAsFixed(2)} ج',
                style: GoogleFonts.cairo(fontSize: 22.sp, fontWeight: FontWeight.w900, color: const Color(0xFFFFD700)),
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
              return Center(child: Text('لا توجد أهداف حالياً', style: GoogleFonts.cairo(fontSize: 18.sp)));
            }
            return ListView.builder(
              padding: EdgeInsets.all(15.sp),
              itemCount: goals.length,
              itemBuilder: (context, index) => _buildGoalCard(context, goals[index]),
            );
          },
        );
      },
    );
  }

  Widget _buildGoalCard(BuildContext context, Map<String, dynamic> goal) {
    bool isSingleOrder = goal['goalBasis'] == 'single_order';
    double progress = goal['progressPercentage'];
    Color progressColor = progress >= 100 ? Colors.green : Colors.orange;

    return Card(
      elevation: 4,
      margin: EdgeInsets.only(bottom: 15.sp),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: EdgeInsets.all(15.sp),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.stars, color: progressColor, size: 24.sp),
                SizedBox(width: 10.sp),
                Expanded(
                  child: Text(
                    goal['title'],
                    style: GoogleFonts.cairo(fontSize: 18.sp, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const Divider(),
            Text(
              isSingleOrder ? '🎯 المطلوب: طلب واحد بقيمة ${goal['minAmount']} ج' : '📈 المطلوب: مجموع مشتريات ${goal['minAmount']} ج',
              style: GoogleFonts.cairo(fontSize: 16.sp, color: Colors.black87),
            ),
            SizedBox(height: 10.sp),
            LinearProgressIndicator(
              value: progress / 100,
              minHeight: 12,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(progressColor),
            ),
            SizedBox(height: 8.sp),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'الحالي: ${goal['currentProgress'].toStringAsFixed(1)} ج',
                  style: GoogleFonts.cairo(fontSize: 15.sp, fontWeight: FontWeight.bold),
                ),
                Text('%${progress.toStringAsFixed(0)}', style: GoogleFonts.cairo(fontSize: 15.sp, color: progressColor)),
              ],
            ),
            if (isSingleOrder && progress < 100)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text('* يجب تحقيق القيمة في عملية شراء واحدة', style: GoogleFonts.cairo(fontSize: 13.sp, color: Colors.red)),
              ),
          ],
        ),
      ),
    );
  }
}
