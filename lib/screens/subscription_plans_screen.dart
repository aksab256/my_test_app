import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

class SubscriptionPlansScreen extends StatelessWidget {
  const SubscriptionPlansScreen({super.key});

  // دالة التعامل مع الدفع (فتح الرابط الخارجي)
  Future<void> _processPayment(BuildContext context, String planName, double price) async {
    // هنا مستقبلاً هنكلم السيرفر (EC2) يبعتلنا رابط الدفع
    // حالياً هنفترض وجود رابط تجريبي
    final String paymentLink = "https://your-payment-gateway.com/pay?amount=$price";
    
    if (await canLaunchUrl(Uri.parse(paymentLink))) {
      await launchUrl(Uri.parse(paymentLink), mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('عذراً، تعذر فتح بوابة الدفع حالياً')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('باقات الاشتراك', style: TextStyle(fontFamily: 'Cairo')),
        backgroundColor: const Color(0xFF2c3e50),
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        // جلب الباقات من Firestore
        stream: FirebaseFirestore.instance.collection('subscription_plans').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('لا توجد باقات متاحة حالياً'));
          }

          final plans = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: plans.length,
            itemBuilder: (context, index) {
              final plan = plans[index].data() as Map<String, dynamic>;
              
              return Card(
                elevation: 5,
                margin: const EdgeInsets.only(bottom: 20),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                child: Column(
                  children: [
                    // رأس الكارت (الاسم والسعر)
                    Container(
                      padding: const EdgeInsets.all(20),
                      width: double.infinity,
                      decoration: const BoxDecoration(
                        color: Color(0xFF2c3e50),
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(15),
                          topRight: Radius.circular(15),
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            plan['planName'] ?? 'باقة غير مسمى',
                            style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            '${plan['price']} ج.م',
                            style: const TextStyle(color: Color(0xFFf1c40f), fontSize: 24, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'صحيحة لمدة ${plan['durationDays']} يوم',
                            style: const TextStyle(color: Colors.white70, fontSize: 12, fontFamily: 'Cairo'),
                          ),
                        ],
                      ),
                    ),
                    
                    // قائمة المميزات
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: (plan['features'] as List? ?? []).map((feature) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                const Icon(Icons.check_circle, color: Colors.green, size: 20),
                                const SizedBox(width: 10),
                                Text(feature.toString(), style: const TextStyle(fontSize: 14, fontFamily: 'Cairo')),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),

                    // زر الاشتراك
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      child: ElevatedButton(
                        onPressed: () => _processPayment(context, plan['planName'], (plan['price'] as num).toDouble()),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF27ae60),
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 50),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text('اشترك الآن', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
