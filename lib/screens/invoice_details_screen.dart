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

  // 1. طلب الدفع الإلكتروني (تغيير الحالة لـ pay_now)
  Future<void> _requestOnlinePayment(BuildContext context) async {
    try {
      await FirebaseFirestore.instance
          .collection('pendingInvoices')
          .doc(invoiceId)
          .update({
        'status': 'pay_now',
        'paymentMethod': 'Online (Paymob)',
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('🎯 جاري تجهيز رابط الدفع.. لحظات ويظهر الزرار')),
      );
    } catch (e) {
      print("Error updating invoice: $e");
    }
  }

  // 2. طلب التحصيل النقدي (تغيير الحالة لـ cash_collection)
  Future<void> _requestCashCollection(BuildContext context) async {
    try {
      await FirebaseFirestore.instance
          .collection('pendingInvoices')
          .doc(invoiceId)
          .update({
        'status': 'cash_collection',
        'paymentMethod': 'Cash (Manual)',
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ تم طلب تحصيل نقدي، سيصلك مندوبنا قريباً'),
          backgroundColor: Colors.blue,
        ),
      );
    } catch (e) {
      print("Error: $e");
    }
  }

  Future<void> _openPaymentLink(BuildContext context) async {
    final String? link = invoiceData['paymentUrl']; // تم التحديث لـ paymentUrl
    if (link == null || link.isEmpty) return;

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
    String status = invoiceData['status'] ?? 'pending_payment';
    bool isPaid = status == 'paid';
    bool hasUrl = invoiceData['paymentUrl'] != null;
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
          children: [
            _buildInfoCard(status),
            const SizedBox(height: 20),
            _buildInfoTile("رقم الفاتورة", invoiceId.substring(0, 8).toUpperCase()),
            _buildInfoTile("تاريخ الإصدار", _formatDate(invoiceData['createdAt'])),
            const Divider(),
            _buildInfoTile("المبلغ المطلوب", "${invoiceData['amount'] ?? 0} ج.م", isBold: true),
            const SizedBox(height: 30),

            if (!isPaid) ...[
              if (isCashRequested) 
                _buildRequestedBanner("تم طلب تحصيل نقدي - المندوب في الطريق")
              else if (hasUrl)
                _buildPayButton(context)
              else
                _buildActionButtons(context),
            ],
          ],
        ),
      ),
    );
  }

  // أزرار الاختيار بين كاش أو فيزا
  Widget _buildActionButtons(BuildContext context) {
    return Column(
      children: [
        const Text("اختر وسيلة الدفع المناسبة لك:", style: TextStyle(color: Colors.grey)),
        const SizedBox(height: 15),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.money),
                label: const Text("سداد نقدي"),
                onPressed: () => _requestCashCollection(context),
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 15)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.credit_card),
                label: const Text("دفع إلكتروني"),
                onPressed: () => _requestOnlinePayment(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15)
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPayButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton.icon(
        icon: const Icon(Icons.vpn_key),
        label: const Text("فتح رابط الدفع الآمن"),
        style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
        onPressed: () => _openPaymentLink(context),
      ),
    );
  }

  Widget _buildRequestedBanner(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(10)),
      child: Text(text, textAlign: TextAlign.center, style: TextStyle(color: Colors.blue.shade800, fontWeight: FontWeight.bold)),
    );
  }

  // --- المكونات المساعدة ---
  Widget _buildInfoCard(String status) {
    Color color = status == 'paid' ? Colors.green : (status == 'cash_collection' ? Colors.blue : Colors.orange);
    String text = status == 'paid' ? "مسددة" : (status == 'cash_collection' ? "بانتظار التحصيل" : "بانتظار السداد");
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10), border: Border.all(color: color)),
      child: Row(children: [Icon(Icons.info, color: color), const SizedBox(width: 10), Text(text, style: TextStyle(fontWeight: FontWeight.bold, color: color))]),
    );
  }

  Widget _buildInfoTile(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label), Text(value, style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.bold))]),
    );
  }

  String _formatDate(dynamic dateVal) {
    if (dateVal == null) return "-";
    if (dateVal is Timestamp) return DateFormat('yyyy/MM/dd HH:mm').format(dateVal.toDate());
    return dateVal.toString();
  }
}
