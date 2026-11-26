// lib/screens/buyer/credit_application_screen.dart
//
// صفحة «الأجل»: عداد الفواتير النقدية المستلمة من 5 + التقديم عند الاكتمال.
// العداد يُشتق دائمًا من وثائق الطلبات (بلا عداد محلي)، وحالة الطلب تُقرأ
// من وثيقة `creditApplications/<uid>` — فتبقى صحيحة بعد إعادة الفتح أو
// الدخول من جهاز آخر.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:my_test_app/providers/buyer_data_provider.dart';
import 'package:my_test_app/services/credit_application_service.dart';
import 'package:my_test_app/widgets/buyer_mobile_nav_widget.dart';
import 'credit_consent_dialog.dart';
import 'my_orders_screen.dart';

class CreditApplicationScreen extends StatefulWidget {
  static const routeName = '/credit';

  const CreditApplicationScreen({super.key});

  @override
  State<CreditApplicationScreen> createState() =>
      _CreditApplicationScreenState();
}

class _CreditApplicationScreenState extends State<CreditApplicationScreen> {
  late final CreditApplicationService _service;

  @override
  void initState() {
    super.initState();
    _service = CreditApplicationService();
  }

  void _onItemTapped(int index) {
    if (index == 2) return;
    switch (index) {
      case 0:
        Navigator.pushReplacementNamed(context, '/traders');
        break;
      case 1:
        Navigator.pushReplacementNamed(context, '/buyerHome');
        break;
      case 3:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const MyOrdersScreen()),
        );
        break;
      case 4:
        Navigator.pushReplacementNamed(context, '/wallet');
        break;
    }
  }

  Future<void> _openConsent() async {
    final buyer = Provider.of<BuyerDataProvider>(context, listen: false);
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => CreditConsentDialog(
        merchantName: buyer.userName.isEmpty
            ? (buyer.loggedInUser?.fullname ?? '')
            : buyer.userName,
        merchantPhone: (buyer.userPhone?.isEmpty ?? true)
            ? (buyer.loggedInUser?.phone ?? '')
            : buyer.userPhone!,
        merchantAddress: buyer.effectiveAddress ?? '',
        onSubmit: () => _service.submitApplication(
          uid: uid,
          merchantName: buyer.userName.isEmpty
              ? (buyer.loggedInUser?.fullname ?? '')
              : buyer.userName,
          merchantPhone: (buyer.userPhone?.isEmpty ?? true)
              ? (buyer.loggedInUser?.phone ?? '')
              : buyer.userPhone!,
          merchantAddress: buyer.effectiveAddress ?? '',
        ),
      ),
    );
    if (ok == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'تم إرسال طلبك إلى القسم المختص لمراجعته ودراسته، وسيتم إبلاغك بالنتيجة لاحقًا.'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 4),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F6),
      appBar: AppBar(
        title: const Text('الأجل'),
        centerTitle: true,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
                colors: [Color(0xFF74D19C), Color(0xFF4CAF50)]),
          ),
        ),
      ),
      bottomNavigationBar: Container(
        color: Colors.white,
        child: SafeArea(
          top: false,
          child: BuyerMobileNavWidget(
            selectedIndex: 2,
            onItemSelected: _onItemTapped,
            cartCount: 0,
            ordersChanged: false,
          ),
        ),
      ),
      body: uid == null
          ? const Center(child: Text('سجّل الدخول أولًا لعرض الأجل'))
          : StreamBuilder<Map<String, dynamic>?>(
              stream: _service.watchApplication(uid),
              builder: (context, appSnap) {
                final app = appSnap.data;
                final underReview =
                    app != null && app['status'] ==
                        CreditApplicationService.applicationUnderReview;
                return StreamBuilder<int>(
                  stream: _service.watchEligibleCount(uid),
                  builder: (context, countSnap) {
                    if (countSnap.connectionState ==
                        ConnectionState.waiting) {
                      return const Center(
                          child:
                              CircularProgressIndicator(color: Colors.green));
                    }
                    final count = countSnap.data ?? 0;
                    final eligible =
                        CreditApplicationService.isEligible(count);
                    final remaining =
                        CreditApplicationService.requiredInvoices - count;
                    return SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _counterCard(count),
                          const SizedBox(height: 16),
                          if (underReview)
                            _statusCard(app)
                          else if (eligible)
                            ElevatedButton(
                              onPressed: _openConsent,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF4CAF50),
                                padding: const EdgeInsets.symmetric(
                                    vertical: 16),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14)),
                              ),
                              child: const Text('التقديم على الأجل',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold)),
                            )
                          else
                            _remainingNote(remaining),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
    );
  }

  Widget _counterCard(int count) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
        child: Column(
          children: [
            const Text('الفواتير النقدية المستلمة والمؤكدة',
                style: TextStyle(fontSize: 14, color: Colors.grey)),
            const SizedBox(height: 12),
            Text(
              '$count / ${CreditApplicationService.requiredInvoices}',
              style: const TextStyle(
                  fontSize: 44,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF4CAF50)),
            ),
            const SizedBox(height: 8),
            const Text(
              'تُحتسب الفاتورة عند تأكيد استلام الطلب فقط',
              style: TextStyle(fontSize: 12, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _remainingNote(int remaining) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Text(
        'متبقٍ $remaining ${remaining == 1 ? 'فاتورة' : 'فواتير'} مستلمة ومؤكدة لفتح التقديم على الأجل.',
        style: const TextStyle(fontSize: 14),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _statusCard(Map<String, dynamic>? app) {
    Timestamp? sentAt = app?['createdAt'] is Timestamp
        ? app!['createdAt'] as Timestamp
        : null;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        children: [
          const Icon(Icons.hourglass_top_outlined,
              color: Colors.blue, size: 36),
          const SizedBox(height: 8),
          const Text('طلبك قيد المراجعة',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue)),
          const SizedBox(height: 6),
          const Text(
            'أُرسلت بياناتك إلى القسم المختص، وسيتم إبلاغك بالنتيجة لاحقًا.',
            style: TextStyle(fontSize: 13),
            textAlign: TextAlign.center,
          ),
          if (sentAt != null) ...[
            const SizedBox(height: 6),
            Text(
              'تاريخ الإرسال: ${sentAt.toDate().toString().split(' ').first}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ],
      ),
    );
  }
}
