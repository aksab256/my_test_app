import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:my_test_app/screens/consumer/consumer_widgets.dart';

class PointsLoyaltyScreen extends StatefulWidget {
  static const routeName = '/points-loyalty';
  const PointsLoyaltyScreen({super.key});

  @override
  State<PointsLoyaltyScreen> createState() => _PointsLoyaltyScreenState();
}

class _PointsLoyaltyScreenState extends State<PointsLoyaltyScreen> {
  bool _isRedeeming = false;
  final String _redeemApiUrl = "https://mtvpdys0o9.execute-api.us-east-1.amazonaws.com/dev/redeempoint";

  // الألوان الموحدة للتصميم الاحترافي
  final Color primaryBlue = const Color(0xFF2196F3);
  final Color accentYellow = const Color(0xFFFFC107);
  final Color successGreen = const Color(0xFF4CAF50);
  final Color darkGrey = const Color(0xFF455A64);

  // 🥳 دالة الاستبدال المحسنة مع رسالة نجاح احتفالية
  Future<void> _redeemPoints() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isRedeeming = true);

    try {
      final response = await http.post(
        Uri.parse(_redeemApiUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"userId": user.uid}),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        // رسالة نجاح "مبهجة" ومنسقة
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Text("🎉", style: TextStyle(fontSize: 24)),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("تم الاستبدال بنجاح!", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text("أضفنا ${data['cashAdded']} جنيه لمحفظتك 💸", style: const TextStyle(fontSize: 14)),
                    ],
                  ),
                ),
              ],
            ),
            backgroundColor: successGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            margin: const EdgeInsets.all(15),
            duration: const Duration(seconds: 4),
          ),
        );
      } else {
        throw data['error'] ?? data['message'] ?? 'فشل الاستبدال';
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("⛔️ عذراً: $e"),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(15),
        ),
      );
    } finally {
      if (mounted) setState(() => _isRedeeming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF0F4F8), // لون خلفية أهدأ
        appBar: AppBar(
          title: const Text('نقاطي - برنامج الولاء', style: TextStyle(fontWeight: FontWeight.bold)),
          centerTitle: true,
          backgroundColor: primaryBlue,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        body: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('consumers').doc(user?.uid).snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

            final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
            
            // معالجة الرصيد من الحقلين لضمان الدقة
            final int pointsField = data['points'] ?? 0;
            final int loyaltyPointsField = data['loyaltyPoints'] ?? 0;
            final int currentPoints = pointsField > 0 ? pointsField : loyaltyPointsField;
            final double cashbackBalance = (data['cashbackBalance'] ?? 0).toDouble();

            return SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // بطاقة رصيد النقاط (أخضر)
                  _buildSummaryCard(
                    title: "رصيد نقاط الولاء الحالي",
                    value: "$currentPoints",
                    unit: "نقطة",
                    icon: FontAwesomeIcons.star,
                    gradient: const [Color(0xFF66BB6A), Color(0xFF43A047)],
                  ),
                  const SizedBox(height: 15),
                  // بطاقة رصيد المحفظة (أزرق)
                  _buildSummaryCard(
                    title: "رصيد المحفظة (كاش باك)",
                    value: cashbackBalance.toStringAsFixed(2),
                    unit: "جنيه مصري",
                    icon: FontAwesomeIcons.wallet,
                    gradient: [primaryBlue, const Color(0xFF1976D2)],
                  ),
                  const SizedBox(height: 30),

                  _buildSectionHeader(Icons.swap_horizontal_circle_outlined, "استبدال النقاط"),
                  _buildRedemptionArea(currentPoints),

                  const SizedBox(height: 30),
                  _buildSectionHeader(Icons.auto_awesome, "كيف تكسب المزيد؟"),
                  _buildEarningRules(),
                ],
              ),
            );
          },
        ),
        bottomNavigationBar: const ConsumerFooterNav(cartCount: 0, activeIndex: -1),
      ),
    );
  }

  // ويدجت البطاقات المحسنة
  Widget _buildSummaryCard({required String title, required String value, required String unit, required IconData icon, required List<Color> gradient}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(colors: gradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
        boxShadow: [BoxShadow(color: gradient[1].withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 6))],
      ),
      child: Stack(
        children: [
          Positioned(
            left: -20, top: -20,
            child: Icon(icon, size: 100, color: Colors.white.withOpacity(0.12)),
          ),
          Column(
            children: [
              Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              Text(value, style: const TextStyle(color: Colors.white, fontSize: 44, fontWeight: FontWeight.bold, letterSpacing: 1)),
              Text(unit, style: const TextStyle(color: Colors.white70, fontSize: 15)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(IconData icon, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Row(
        children: [
          Icon(icon, color: primaryBlue, size: 28),
          const SizedBox(width: 12),
          Text(title, style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: darkGrey)),
          const Expanded(child: Divider(indent: 15, thickness: 1.2, color: Colors.black12)),
        ],
      ),
    );
  }

  // منطقة الاستبدال المحسنة بتصميم البطاقة البيضاء
  Widget _buildRedemptionArea(int currentPoints) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('appSettings').doc('points').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox();
        final settings = snapshot.data!.data() as Map<String, dynamic>? ?? {};
        final rate = settings['conversionRate'] ?? {};

        final int reqPoints = rate['pointsRequired'] ?? 1000;
        final double cashVal = (rate['cashEquivalent'] ?? 10).toDouble();
        final int minPoints = rate['minPointsForRedemption'] ?? 500;

        bool canRedeem = currentPoints >= minPoints;

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text("كل $reqPoints نقطة", style: TextStyle(fontWeight: FontWeight.bold, color: primaryBlue, fontSize: 16)),
                  const Text(" = "),
                  Text("$cashVal جنيه مصري", style: TextStyle(fontWeight: FontWeight.bold, color: successGreen, fontSize: 16)),
                ],
              ),
              const SizedBox(height: 8),
              Text("الحد الأدنى للاستبدال: $minPoints نقطة", style: const TextStyle(color: Colors.grey, fontSize: 13)),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: (_isRedeeming || !canRedeem) ? null : () => _redeemPoints(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryBlue,
                    disabledBackgroundColor: Colors.grey.shade300,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    elevation: 0,
                  ),
                  child: _isRedeeming
                    ? const SizedBox(height: 25, width: 25, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                    : Text(
                        canRedeem ? "استبدل نقاطي الآن" : "نقاطك غير كافية للاستبدال",
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
Widget _buildEarningRules() {
  return StreamBuilder<DocumentSnapshot>(
    stream: FirebaseFirestore.instance.collection('appSettings').doc('points').snapshots(),
    builder: (context, snapshot) {
      if (!snapshot.hasData || !snapshot.data!.exists) return const SizedBox();

      final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
      final List<dynamic> rules = data['earningRules'] ?? [];
      // فلترة القواعد النشطة فقط
      final activeRules = rules.where((rule) => rule['isActive'] == true).toList();

      return Column(
        children: activeRules.map((rule) {
          IconData iconData = FontAwesomeIcons.circleInfo;
          
          // استخراج القيم من Firestore
          final String type = rule['type'] ?? '';
          final dynamic value = rule['value'] ?? 0;
          String description = rule['description'] ?? '';

          // بناء نص مخصص لو الوصف فاضي في قاعدة البيانات
          if (description.isEmpty) {
            if (type == 'on_new_customer_registration') {
              description = "اكسب $value نقطة هديّة عند تسجيل حسابك لأول مرة";
              iconData = FontAwesomeIcons.userPlus;
            } else if (type == 'per_currency_unit') {
              description = "اكسب $value نقطة مقابل كل جنيه مصري من مشترياتك";
              iconData = FontAwesomeIcons.coins;
            } else {
              description = "اكسب $value نقطة إضافية عند استخدام التطبيق";
            }
          }

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white, // تغيير اللون لأبيض صريح ليظهر بوضوح
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                )
              ],
              border: Border.all(color: primaryBlue.withOpacity(0.1)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: primaryBlue.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(iconData, color: primaryBlue, size: 18),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Text(
                    description,
                    style: TextStyle(
                      fontSize: 14, 
                      color: darkGrey, 
                      fontWeight: FontWeight.w600,
                      height: 1.3
                    ),
                  ),
                ),
                // إضافة ملصق صغير للقيمة
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: successGreen.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    "+$value",
                    style: TextStyle(color: successGreen, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      );
    },
  );
}

  
