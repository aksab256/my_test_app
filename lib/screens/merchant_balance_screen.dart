import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:my_test_app/providers/buyer_data_provider.dart';
import 'package:intl/intl.dart';

class MerchantPointBalanceScreen extends StatefulWidget {
  const MerchantPointBalanceScreen({super.key});

  @override
  State<MerchantPointBalanceScreen> createState() => _MerchantPointBalanceScreenState();
}

class _MerchantPointBalanceScreenState extends State<MerchantPointBalanceScreen> {
  int _limit = 10; // تحميل 10 سجلات في البداية
  bool _isloadingMore = false;

  void _loadMore() {
    setState(() {
      _limit += 10;
    });
  }

  @override
  Widget build(BuildContext context) {
    final buyerProvider = Provider.of<BuyerDataProvider>(context);
    final currentUserId = buyerProvider.loggedInUser?.id ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('سجل مستحقات العهدة', style: TextStyle(fontFamily: 'Cairo')),
        centerTitle: true,
      ),
      // استخدمنا SafeArea لضمان عدم تداخل المحتوى مع حواف الشاشة
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot>(
          // نجلب مستند السوبر ماركت أولاً لعرض الرصيد الإجمالي
          stream: FirebaseFirestore.instance
              .collection('deliverySupermarkets')
              .where('ownerId', isEqualTo: currentUserId)
              .snapshots(),
          builder: (context, mainSnapshot) {
            if (mainSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!mainSnapshot.hasData || mainSnapshot.data!.docs.isEmpty) {
              return const Center(child: Text('لا توجد بيانات للمتجر'));
            }

            final merchantDoc = mainSnapshot.data!.docs.first;
            
            // 🎯 التعديل التأميني هنا فقط لمنع الكراش:
            // فحصنا إذا كان الحقل موجوداً في الـ Map قبل محاولة الوصول إليه
            final merchantData = merchantDoc.data() as Map<String, dynamic>;
            final walletBalance = merchantData.containsKey('walletBalance') 
                ? merchantData['walletBalance'].toString() 
                : '0';

            return Column(
              children: [
                _buildHeaderCard(walletBalance),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Text('آخر العمليات اللوجستية', 
                      style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    // 🔥 هنا السر: بندخل جوه الـ Collection الفرعي walletLogs
                    stream: merchantDoc.reference
                        .collection('walletLogs')
                        .orderBy('timestamp', descending: true)
                        .limit(_limit)
                        .snapshots(),
                    builder: (context, logSnapshot) {
                      if (!logSnapshot.hasData) return const Center(child: CircularProgressIndicator());
                      
                      final logs = logSnapshot.data!.docs;
                      if (logs.isEmpty) {
                        return const Center(child: Text('لا توجد سجلات عمليات حتى الآن'));
                      }

                      return ListView.builder(
                        itemCount: logs.length + 1, // +1 عشان زرار "المزيد"
                        itemBuilder: (context, index) {
                          if (index == logs.length) {
                            return _buildLoadMoreButton(logs.length);
                          }

                          final log = logs[index].data() as Map<String, dynamic>;
                          return _buildLogTile(log);
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeaderCard(String balance) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [Colors.teal[700]!, Colors.teal[400]!]),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 4))],
      ),
      child: Column(
        children: [
          const Text('إجمالي نقاط الأمان (العهد المستحقة)', 
            style: TextStyle(color: Colors.white70, fontFamily: 'Cairo', fontSize: 16)),
          const SizedBox(height: 10),
          Text(
            '$balance ج.م',
            style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }

  Widget _buildLogTile(Map<String, dynamic> log) {
    final amount = log['amount'] ?? 0;
    final isPositive = amount >= 0;
    final timestamp = (log['timestamp'] as Timestamp?)?.toDate();
    final dateStr = timestamp != null ? DateFormat('yyyy-MM-dd HH:mm').format(timestamp) : '---';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isPositive ? Colors.green[50] : Colors.red[50],
          child: Icon(
            isPositive ? Icons.add_chart : Icons.remove_moderator,
            color: isPositive ? Colors.green : Colors.red,
          ),
        ),
        title: Text(log['details'] ?? 'عملية لوجستية', style: const TextStyle(fontFamily: 'Cairo', fontSize: 13)),
        subtitle: Text(dateStr, style: const TextStyle(fontSize: 11)),
        trailing: Text(
          '${isPositive ? "+" : ""}$amount',
          style: TextStyle(
            color: isPositive ? Colors.green[700] : Colors.red[700],
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildLoadMoreButton(int currentCount) {
    // لو عدد السجلات أقل من المسموح به حالياً، مش محتاجين زرار "المزيد"
    if (currentCount < _limit) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: TextButton.icon(
        onPressed: _loadMore,
        icon: const Icon(Icons.expand_more, color: Colors.teal),
        label: const Text('عرض المزيد من السجلات', style: TextStyle(fontFamily: 'Cairo', color: Colors.teal)),
      ),
    );
  }
}
