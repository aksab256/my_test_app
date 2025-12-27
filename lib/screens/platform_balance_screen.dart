// lib/screens/platform_balance_screen.dart
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:my_test_app/screens/invoices_screen.dart';
import 'package:sizer/sizer.dart';

class PlatformBalanceScreen extends StatefulWidget {
  const PlatformBalanceScreen({super.key});

  @override
  State<PlatformBalanceScreen> createState() => _PlatformBalanceScreenState();
}

class _PlatformBalanceScreenState extends State<PlatformBalanceScreen> {
  double realizedAmount = 0.0;
  double unrealizedAmount = 0.0;
  double cashbackDebtAmount = 0.0;
  double cashbackCreditAmount = 0.0;
  bool hasPendingInvoice = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchSellerBalances();
  }

  Future<void> _fetchSellerBalances() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final sellerSnapshot = await FirebaseFirestore.instance
          .collection('sellers')
          .doc(user.uid)
          .get();

      if (sellerSnapshot.exists) {
        final data = sellerSnapshot.data()!;
        setState(() {
          realizedAmount = (data['realizedCommission'] as num? ?? 0).toDouble();
          unrealizedAmount = (data['unrealizedCommission'] as num? ?? 0).toDouble();
          cashbackDebtAmount = (data['cashbackAccruedDebt'] as num? ?? 0).toDouble();
          cashbackCreditAmount = (data['cashbackPlatformCredit'] as num? ?? 0).toDouble();
        });
      }

      final invoicesQuery = await FirebaseFirestore.instance
          .collection('invoices')
          .where('sellerId', isEqualTo: user.uid)
          .where('status', isEqualTo: 'pending')
          .get();

      setState(() => hasPendingInvoice = invoicesQuery.docs.isNotEmpty);
    } catch (e) {
      debugPrint("Error fetching: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _navigateToInvoices() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => InvoiceScreen(sellerId: user.uid)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF007bff),
        title: Text('الحساب المالي للمنصة', 
          style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const FaIcon(FontAwesomeIcons.receipt, color: Colors.white, size: 20),
            onPressed: _navigateToInvoices,
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(5.w),
              child: Column(
                children: [
                  _buildAlertBanner(),
                  SizedBox(height: 1.h),
                  _buildBalanceCard("عمولات مستحقة للمنصة", realizedAmount, "رسوم الطلبات المسلمة فعلياً", const Color(0xFF28a745), FontAwesomeIcons.calculator),
                  _buildBalanceCard("عمولات قيد المعالجة", unrealizedAmount, "طلبات لم يكتمل تسليمها بعد", const Color(0xFFffc107), FontAwesomeIcons.hourglassHalf),
                  const Divider(height: 30, thickness: 1),
                  _buildBalanceCard("مديونية كاش باك (عليكم)", cashbackDebtAmount, "فرق كاش باك لمورد آخر", const Color(0xFFdc3545), FontAwesomeIcons.arrowDown),
                  _buildBalanceCard("ائتمان كاش باك (لكم)", cashbackCreditAmount, "تعويض كاش باك من المنصة", const Color(0xFF007bff), FontAwesomeIcons.arrowUp),
                ],
              ),
            ),
    );
  }

  Widget _buildAlertBanner() {
    if (!hasPendingInvoice) return const SizedBox();
    return Container(
      padding: EdgeInsets.all(4.w),
      margin: EdgeInsets.only(bottom: 2.h),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.red),
          SizedBox(width: 3.w),
          Expanded(
            child: Text("توجد فاتورة شهرية مستحقة الدفع حالياً.",
              style: TextStyle(color: Colors.red.shade900, fontWeight: FontWeight.bold, fontSize: 13.sp, fontFamily: 'Cairo')),
          ),
          TextButton(onPressed: _navigateToInvoices, child: const Text("عرض")),
        ],
      ),
    );
  }

  Widget _buildBalanceCard(String title, double amount, String desc, Color color, IconData icon) {
    return Container(
      margin: EdgeInsets.only(bottom: 2.h),
      padding: EdgeInsets.all(5.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      child: Row(
        children: [
          FaIcon(icon, color: color, size: 24),
          SizedBox(width: 4.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.sp, fontFamily: 'Cairo')),
                Text(desc, style: TextStyle(color: Colors.grey, fontSize: 11.sp, fontFamily: 'Cairo')),
              ],
            ),
          ),
          Text("${amount.toStringAsFixed(2)}", 
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15.sp, color: color, fontFamily: 'Cairo')),
        ],
      ),
    );
  }
}

