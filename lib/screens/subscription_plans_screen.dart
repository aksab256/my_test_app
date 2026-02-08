import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
// 🚀 إضافة مكتبة فيسبوك
import 'package:facebook_app_events/facebook_app_events.dart';

class SubscriptionPlansScreen extends StatefulWidget {
  const SubscriptionPlansScreen({super.key});

  @override
  State<SubscriptionPlansScreen> createState() => _SubscriptionPlansScreenState();
}

class _SubscriptionPlansScreenState extends State<SubscriptionPlansScreen> {
  bool _isProcessing = false;
  // تعريف كائن فيسبوك
  static final facebookAppEvents = FacebookAppEvents();

  // 🎯 الدالة الأساسية لإرسال الطلب واستلام الرابط من السيرفر
  Future<void> _initiateSubscriptionPayment(Map<String, dynamic> plan) async {
    final double price = (plan['price'] as num).toDouble();
    final String planName = plan['planName'] ?? 'باقة غير معروفة';

    // 🚀 تتبع فيسبوك: التاجر مهتم وعاوز يشترك (بدأ عملية الدفع)
    facebookAppEvents.logEvent(
      name: 'fb_mobile_initiated_checkout',
      parameters: {
        'plan_name': planName,
        'amount': price,
        'currency': 'EGP',
      },
    );

    // 1️⃣ حالة الباقة المجانية (السعر = 0)
    if (price == 0) {
      // 🚀 تتبع فيسبوك: تفعيل باقة تجريبية
      facebookAppEvents.logEvent(
        name: 'trial_activated',
        parameters: {'plan_name': planName},
      );

      _showFreePlanDialog(planName);
      return;
    }

    // 2️⃣ حالة الباقة المدفوعة (السعر أكبر من 0)
    setState(() => _isProcessing = true);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final docRef = await FirebaseFirestore.instance.collection('pendingInvoices').add({
        "type": "SUBSCRIPTION_RENEW",
        "status": "pay_now",
        "amount": price,
        "storeId": user.uid,
        "planName": planName,
        "durationDays": plan['durationDays'] ?? 30,
        "email": user.email ?? "no-email@store.com",
        "createdAt": FieldValue.serverTimestamp(),
      });

      docRef.snapshots().listen((snapshot) async {
        if (snapshot.exists && snapshot.data()!.containsKey('paymentUrl')) {
          String url = snapshot.data()!['paymentUrl'];
          
          if (_isProcessing) {
            setState(() => _isProcessing = false);
            await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
          }
        }
      });

      Future.delayed(const Duration(seconds: 15), () {
        if (mounted && _isProcessing) {
          setState(() => _isProcessing = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('السيرفر مستغرق وقتاً طويلاً، حاول مجدداً')),
          );
        }
      });

    } catch (e) {
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ في الاتصال: $e')),
      );
    }
  }

  // دالة إظهار الديالوج للباقة المجانية
  void _showFreePlanDialog(String planName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Text('تفعيل الاشتراك', 
          textAlign: TextAlign.center, 
          style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
        content: Text('باقة "$planName" مفعلة لحسابك حالياً للفترة التجريبية بنجاح.',
          textAlign: TextAlign.center,
          style: const TextStyle(fontFamily: 'Cairo')),
        actions: [
          Center(
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('بدء الاستخدام', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: Color(0xFF27ae60))),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('باقات الاشتراك المتاحة', 
          style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF2c3e50),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('subscription_plans').orderBy('price').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(child: Text('لا توجد باقات متاحة حالياً', style: TextStyle(fontFamily: 'Cairo')));
              }

              final plans = snapshot.data!.docs;

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 25),
                itemCount: plans.length,
                itemBuilder: (context, index) {
                  final plan = plans[index].data() as Map<String, dynamic>;
                  final List<dynamic> features = plan['features'] ?? [];
                  final double price = (plan['price'] as num).toDouble();

                  return Container(
                    margin: const EdgeInsets.only(bottom: 25),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5))
                      ],
                    ),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(25),
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: price > 0 ? const Color(0xFFB21F2D) : const Color(0xFF34495e),
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                          ),
                          child: Column(
                            children: [
                              Text(plan['planName'] ?? 'باقة',
                                style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text('$price', style: const TextStyle(color: Color(0xFFf1c40f), fontSize: 32, fontWeight: FontWeight.bold)),
                                  const Text(' ج.م', style: TextStyle(color: Colors.white, fontSize: 16, fontFamily: 'Cairo')),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            children: features.map((f) => _buildFeatureItem(f['label'], f['value'])).toList(),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 25),
                          child: ElevatedButton(
                            onPressed: _isProcessing ? null : () => _initiateSubscriptionPayment(plan),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: price > 0 ? const Color(0xFFB21F2D) : const Color(0xFF27ae60),
                              foregroundColor: Colors.white,
                              minimumSize: const Size(double.infinity, 55),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                            ),
                            child: _isProcessing 
                              ? const CircularProgressIndicator(color: Colors.white)
                              : Text(price > 0 ? 'اشترك الآن' : 'تفعيل مجاني', 
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
          if (_isProcessing)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(child: Text("جاري تحضير بوابة الدفع...", style: TextStyle(color: Colors.white, fontFamily: 'Cairo'))),
            ),
        ],
      ),
    );
  }

  Widget _buildFeatureItem(String label, bool isAvailable) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(isAvailable ? Icons.check_circle : Icons.cancel, color: isAvailable ? Colors.green : Colors.red.shade300, size: 22),
          const SizedBox(width: 15),
          Text(label, style: TextStyle(fontSize: 15, fontFamily: 'Cairo', color: isAvailable ? Colors.black87 : Colors.grey)),
        ],
      ),
    );
  }
}
