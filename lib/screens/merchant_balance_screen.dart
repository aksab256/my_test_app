import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:my_test_app/providers/buyer_data_provider.dart';

class MerchantPointBalanceScreen extends StatelessWidget {
  const MerchantPointBalanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final buyerProvider = Provider.of<BuyerDataProvider>(context);
    final currentUserId = buyerProvider.loggedInUser?.id ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('سجل مستحقات العهدة', style: TextStyle(fontFamily: 'Cairo')),
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        // ✨ الإصلاح الأول: تعديل صيغة الـ Query
        stream: FirebaseFirestore.instance
            .collection('deliverySupermarkets')
            .where('ownerId', isEqualTo: currentUserId) 
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('لا توجد بيانات حالياً'));
          }

          final data = snapshot.data!.docs.first.data() as Map<String, dynamic>;
          // هنا بنفترض إن السجلات محفوظة في قائمة داخل المستند أو في Collection فرعي
          // سأعرض لك مثالاً بسيطاً لعرض الإجمالي:
          
          return Column(
            children: [
              _buildHeaderCard(data['walletBalance']?.toString() ?? '0'),
              const Divider(),
              const Expanded(
                child: Center(child: Text('سيتم عرض تفاصيل العمليات اللوجستية هنا')),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeaderCard(String balance) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.teal[600],
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          const Text('إجمالي نقاط الأمان (العهدة)', 
            style: TextStyle(color: Colors.white70, fontFamily: 'Cairo', fontSize: 16)),
          const SizedBox(height: 10),
          Text(
            '$balance ن',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              // ✨ الإصلاح الثاني: تعديل وزن الخط
              fontWeight: FontWeight.w900, 
            ),
          ),
        ],
      ),
    );
  }
}
