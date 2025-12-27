import 'package:flutter/material.dart';
import 'package:my_test_app/screens/consumer/consumer_widgets.dart';
import 'package:my_test_app/screens/consumer/consumer_data_models.dart';
import 'package:my_test_app/services/consumer_data_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:my_test_app/widgets/chat_support_widget.dart';

class ConsumerHomeScreen extends StatefulWidget {
  static const routeName = '/consumerHome';
  const ConsumerHomeScreen({super.key});

  @override
  State<ConsumerHomeScreen> createState() => _ConsumerHomeScreenState();
}

class _ConsumerHomeScreenState extends State<ConsumerHomeScreen> {
  final ConsumerDataService dataService = ConsumerDataService();

  @override
  void initState() {
    super.initState();
    _setupNotifications();
  }

  Future<void> _setupNotifications() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    FirebaseMessaging messaging = FirebaseMessaging.instance;
    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      String? token = await messaging.getToken();
      if (token != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
          'fcmToken': token,
          'lastTokenUpdate': FieldValue.serverTimestamp(),
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      drawer: const ConsumerSideMenu(),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(70),
        child: Builder(
          builder: (context) => ConsumerCustomAppBar(
            userName: user?.displayName ?? 'مستخدم',
            userPoints: 0,
            onMenuPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
      ),
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 100),
                  const ConsumerSectionTitle(title: 'الأقسام المميزة'),
                  FutureBuilder<List<ConsumerCategory>>(
                    future: dataService.fetchMainCategories(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const SizedBox(
                          height: 130,
                          child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF43A047))),
                        );
                      }
                      final categories = snapshot.data ?? [];
                      return ConsumerCategoriesBanner(categories: categories);
                    },
                  ),
                  const SizedBox(height: 10),
                  const ConsumerSectionTitle(title: 'أحدث العروض الحصرية'),
                  FutureBuilder<List<ConsumerBanner>>(
                    future: dataService.fetchPromoBanners(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const SizedBox(
                          height: 200,
                          child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF43A047))),
                        );
                      }
                      final banners = snapshot.data ?? [];
                      return ConsumerPromoBanners(banners: banners, height: 220);
                    },
                  ),
                  const SizedBox(height: 100),
                ],
              ),
            ),
            Positioned(
              top: 15,
              left: 15,
              right: 15,
              child: _buildSmartRadarButton(),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const ConsumerFooterNav(cartCount: 0, activeIndex: 0),
      floatingActionButton: FloatingActionButton(
        heroTag: "consumer_chat_btn",
        onPressed: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (context) => const ChatSupportWidget(),
          );
        },
        backgroundColor: const Color(0xFF43A047),
        child: const Icon(Icons.support_agent, color: Colors.white, size: 30),
      ),
    );
  }

  Widget _buildSmartRadarButton() {
    return Container(
      height: 75,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF43A047), Color(0xFF2E7D32)],
          begin: Alignment.centerRight,
          end: Alignment.centerLeft,
        ),
        borderRadius: BorderRadius.circular(40),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF43A047).withOpacity(0.4),
            blurRadius: 20,
            spreadRadius: 2,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(40),
          onTap: () { // 🎯 تم التصحيح هنا من onPressed إلى onTap
            debugPrint("📡 تشغيل رادار البحث عن الأقرب...");
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.radar, color: Colors.white, size: 30),
                ),
                const SizedBox(width: 15),
                const Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "اكتشف المحلات القريبة",
                        style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        "اضغط لتفعيل رادار البحث الذكي",
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.location_on_outlined, color: Colors.white, size: 28),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

