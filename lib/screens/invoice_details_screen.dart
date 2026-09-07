import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class InvoiceDetailsScreen extends StatelessWidget {
  final String invoiceId;
  final Map<String, dynamic> invoiceData;

  const InvoiceDetailsScreen({
    super.key,
    required this.invoiceId,
    required this.invoiceData
  });

  // المرجع الصحيح حسب الصورة (كوليكشن pendingInvoices الرئيسي)
  DocumentReference _getInvoiceRef() {
    return FirebaseFirestore.instance
        .collection('pendingInvoices')
        .doc(invoiceId);
  }

  Future<void> _requestOnlinePayment(BuildContext context) async {
    try {
      await _getInvoiceRef().update({
        'status': 'pay_now',
        'paymentMethod': 'Online (Paymob)',
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('🎯 جاري تجهيز رابط الدفع..')),
      );
    } catch (e) {
      print("Error: $e");
    }
  }

  Future<void> _requestCashCollection(BuildContext context) async {
    try {
      await _getInvoiceRef().update({
        'status': 'cash_collection',
        'paymentMethod': 'Cash (Manual)',
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ تم طلب تحصيل نقدي'), backgroundColor: Colors.blue),
      );
    } catch (e) {
      print("Error: $e");
    }
  }

  Future<void> _openPaymentLink(String link, BuildContext context) async {
    final Uri url = Uri.parse(link);
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❌ تعذر فتح البوابة')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: _getInvoiceRef().snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Scaffold(body: Center(child: CircularProgressIndicator()));
        
        var currentData = snapshot.data!.data() as Map<String, dynamic>;
        String status = currentData['status'] ?? 'pending_payment';
        bool isPaid = status == 'paid';
        String? paymentUrl = currentData['paymentUrl'];
        bool isCashRequested = status == 'cash_collection';

        return Scaffold(
          appBar: AppBar(
            title: const Text('تفاصيل الفاتورة', style: TextStyle(fontFamily: 'Cairo')),
            backgroundColor: const Color(0xFF007bff),
            centerTitle: true,
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStatusBanner(status),
                const SizedBox(height: 25),
                
                _buildSectionTitle("بيانات التاجر"),
                _buildInfoTile("الاسم", "${currentData['merchantName']}"),
                _buildInfoTile("رقم الهاتف", "${currentData['phone']}"),
                
                const Divider(height: 40),
                
                _buildSectionTitle("التفاصيل المالية"),
                _buildInfoTile("رقم الفاتورة", invoiceId.substring(0, 8).toUpperCase()),
                _buildInfoTile("تاريخ الإصدار", _formatDate(currentData['createdAt'])),
                _buildInfoTile("إجمالي المبلغ", "${currentData['amount']} ج.م", isBold: true),
                
                const SizedBox(height: 40),

                if (!isPaid) ...[
                  if (isCashRequested) 
                    _buildFullWidthBanner("تم طلب تحصيل نقدي - بانتظار المندوب", Colors.blue)
                  else if (paymentUrl != null)
                    _buildPrimaryButton(
                      "فتح رابط الدفع الآمن", 
                      Colors.green, 
                      () => _openPaymentLink(paymentUrl, context)
                    )
                  else
                    _buildChoiceButtons(context, status),
                ],
              ],
            ),
          ),
        );
      }
    );
  }

  Widget _buildChoiceButtons(BuildContext context, String status) {
    if (status == 'pay_now') return const Center(child: CircularProgressIndicator());
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => _requestCashCollection(context),
            style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 15)),
            child: const Text("سداد نقدي"),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: ElevatedButton(
            onPressed: () => _requestOnlinePayment(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green, 
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 15)
            ),
            child: const Text("دفع إلكتروني"),
          ),
        ),
      ],
    );
  }

  Widget _buildPrimaryButton(String text, Color color, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(backgroundColor: color, foregroundColor: Colors.white),
        onPressed: onPressed,
        child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      ),
    );
  }

  Widget _buildStatusBanner(String status) {
    Color color = status == 'paid' ? Colors.green : (status == 'cash_collection' ? Colors.blue : Colors.orange);
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10), border: Border.all(color: color)),
      child: Row(children: [
        Icon(status == 'paid' ? Icons.check_circle : Icons.info, color: color),
        const SizedBox(width: 10),
        Text(status == 'paid' ? "الفاتورة مسددة" : (status == 'cash_collection' ? "طلب تحصيل قيد التنفيذ" : "بانتظار السداد"),
        style: TextStyle(fontWeight: FontWeight.bold, color: color))
      ]),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey));
  }

  Widget _buildInfoTile(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: const TextStyle(color: Colors.black54)),
        Text(value, style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.w600, fontSize: isBold ? 17 : 15)),
      ]),
    );
  }

  Widget _buildFullWidthBanner(String text, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
      child: Text(text, textAlign: TextAlign.center, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
    );
  }

  String _formatDate(dynamic dateVal) {
    if (dateVal == null) return "-";
    if (dateVal is Timestamp) return DateFormat('yyyy/MM/dd HH:mm').format(dateVal.toDate());
    return dateVal.toString();
  }
}

