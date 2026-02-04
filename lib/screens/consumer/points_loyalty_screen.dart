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

  final Color primaryBlue = const Color(0xFF2196F3);
  final Color successGreen = const Color(0xFF4CAF50);
  final Color darkGrey = const Color(0xFF455A64);

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
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("🎉 تم الاستبدال! أضفنا ${data['cashAdded']} جنيه لمحفظتك"),
            backgroundColor: successGreen,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        throw data['error'] ?? 'فشل الاستبدال';
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("⛔️ $e"), backgroundColor: Colors.redAccent));
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
        backgroundColor: const Color(0xFFF0F4F8),
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
            final int pointsField = data['points'] ?? 0;
            final int loyaltyPointsField = data['loyaltyPoints'] ?? 0;
            final int currentPoints = pointsField > 0 ? pointsField : loyaltyPointsField;
            final double cashbackBalance = (data['cashbackBalance'] ?? 0).toDouble();

            return SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  _buildSummaryCard(
                    title: "رصيد نقاط الولاء الحالي",
                    value: "$currentPoints",
                    unit: "نقطة",
                    icon: FontAwesomeIcons.star,
                    gradient: const [Color(0xFF66BB6A), Color(0xFF43A047)],
                  ),
                  const SizedBox(height: 15),
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

  Widget _buildSummaryCard({required String title, required String value, required String unit, required IconData icon, required List<Color> gradient}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(colors: gradient),
        boxShadow: [BoxShadow(color: gradient[1].withOpacity(0.3), blurRadius: 12)],
      ),
      child: Column(
        children: [
          Text(title, style: const TextStyle(color: Colors.white, fontSize: 16)),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 44, fontWeight: FontWeight.bold)),
          Text(unit, style: const TextStyle(color: Colors.white70, fontSize: 15)),
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
        ],
      ),
    );
  }

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
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
          child: Column(
            children: [
              Text("كل $reqPoints نقطة = $cashVal جنيه", style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: (_isRedeeming || !canRedeem) ? null : () => _redeemPoints(),
                  style: ElevatedButton.styleFrom(backgroundColor: primaryBlue),
                  child: _isRedeeming ? const CircularProgressIndicator(color: Colors.white) : Text(canRedeem ? "استبدل الآن" : "النقاط غير كافية"),
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
        final activeRules = rules.where((rule) => rule['isActive'] == true).toList();

        return Column(
          children: activeRules.map((rule) {
            final String type = rule['type'] ?? '';
            final dynamic value = rule['value'] ?? 0;
            String description = rule['description'] ?? '';
            if (description.isEmpty) {
              description = type == 'on_new_customer_registration' ? "هدية التسجيل الجديد" : "نقاط على المشتريات";
            }

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)),
              child: Row(
                children: [
                  Icon(Icons.stars, color: primaryBlue, size: 20),
                  const SizedBox(width: 15),
                  Expanded(child: Text(description)),
                  Text("+$value", style: TextStyle(color: successGreen, fontWeight: FontWeight.bold)),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }
}
