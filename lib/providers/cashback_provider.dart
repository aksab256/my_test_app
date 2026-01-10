// lib/screens/buyer/wallet_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sizer/sizer.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/cashback_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/buyer_mobile_nav_widget.dart';
import 'wallet/gifts_tab.dart'; // استدعاء ملف الهدايا المنفصل

class WalletScreen extends StatelessWidget {
  static const String routeName = '/wallet';

  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: Colors.grey[50],
          appBar: AppBar(
            backgroundColor: AppTheme.primaryGreen,
            elevation: 0,
            title: Text(
              'محفظتي وهداياي',
              style: GoogleFonts.cairo(fontSize: 20.sp, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            centerTitle: true,
            bottom: TabBar(
              indicatorColor: Colors.orangeAccent,
              indicatorWeight: 4,
              labelStyle: GoogleFonts.cairo(fontSize: 16.sp, fontWeight: FontWeight.bold),
              unselectedLabelStyle: GoogleFonts.cairo(fontSize: 14.sp),
              tabs: const [
                Tab(text: "أهداف الكاش باك"),
                Tab(text: "هدايا العروض"),
              ],
            ),
          ),
          body: const TabBarView(
            children: [
              CashbackTabContent(), // التبويب الأول (داخلي)
              GiftsTab(),           // التبويب الثاني (ملف منفصل)
            ],
          ),
          bottomNavigationBar: BuyerMobileNavWidget(
            selectedIndex: 2, // أيقونة المحفظة
            onItemSelected: (index) {
              if (index == 2) return;
              if (index == 1) Navigator.pushReplacementNamed(context, '/buyerHome');
              if (index == 4) Navigator.pushReplacementNamed(context, '/myDetails');
            },
          ),
        ),
      ),
    );
  }
}

// --- محتوى تبويب الكاش باك (الجزء الأول) ---
class CashbackTabContent extends StatelessWidget {
  const CashbackTabContent({super.key});

  @override
  Widget build(BuildContext context) {
    final cashbackProv = Provider.of<CashbackProvider>(context, listen: false);

    return SingleChildScrollView(
      child: Column(
        children: [
          // كارت الرصيد الحالي
          _buildBalanceCard(cashbackProv),
          
          // قائمة الأهداف
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 15.sp, vertical: 10.sp),
            child: Row(
              children: [
                Icon(Icons.track_changes, color: AppTheme.primaryGreen, size: 22.sp),
                SizedBox(width: 8.sp),
                Text("أهدافك الحالية", style: GoogleFonts.cairo(fontSize: 18.sp, fontWeight: FontWeight.bold)),
              ],
            ),
          ),

          FutureBuilder<List<Map<String, dynamic>>>(
            future: cashbackProv.fetchCashbackGoals(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final goals = snapshot.data ?? [];
              if (goals.isEmpty) {
                return _buildEmptyState("لا توجد أهداف كاش باك نشطة حالياً.");
              }
              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: goals.length,
                itemBuilder: (context, index) => _buildGoalItem(goals[index]),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceCard(CashbackProvider prov) {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.all(15.sp),
      padding: EdgeInsets.all(20.sp),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [AppTheme.primaryGreen, Colors.green.shade800]),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.green.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5))],
      ),
      child: Column(
        children: [
          Text("رصيدك الحالي", style: GoogleFonts.cairo(color: Colors.white70, fontSize: 16.sp)),
          FutureBuilder<double>(
            future: prov.fetchCashbackBalance(),
            builder: (context, snap) => Text(
              "${snap.data ?? 0.0} جنيه",
              style: GoogleFonts.cairo(color: Colors.white, fontSize: 28.sp, fontWeight: FontWeight.black),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGoalItem(Map<String, dynamic> goal) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 15.sp, vertical: 8.sp),
      padding: EdgeInsets.all(15.sp),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(goal['title'], style: GoogleFonts.cairo(fontSize: 17.sp, fontWeight: FontWeight.bold)),
              ),
              Text(
                goal['type'] == 'percentage' ? "${goal['value']}%" : "${goal['value']} ج",
                style: GoogleFonts.cairo(fontSize: 18.sp, color: AppTheme.primaryGreen, fontWeight: FontWeight.black),
              ),
            ],
          ),
          SizedBox(height: 10.sp),
          // شريط التقدم
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: goal['progressPercentage'] / 100,
              minHeight: 12.sp,
              backgroundColor: Colors.grey.shade200,
              color: goal['isAchieved'] ? Colors.orange : AppTheme.primaryGreen,
            ),
          ),
          SizedBox(height: 8.sp),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("تم تحقيق: ${goal['currentProgress']} من ${goal['minAmount']}", 
                style: GoogleFonts.cairo(fontSize: 14.sp, color: Colors.grey.shade700)),
              if (goal['isAchieved'])
                const Icon(Icons.check_circle, color: Colors.orange)
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String msg) {
    return Padding(
      padding: EdgeInsets.all(40.sp),
      child: Column(
        children: [
          Icon(Icons.info_outline, size: 50.sp, color: Colors.grey),
          SizedBox(height: 10.sp),
          Text(msg, textAlign: TextAlign.center, style: GoogleFonts.cairo(fontSize: 16.sp, color: Colors.grey)),
        ],
      ),
    );
  }
}
