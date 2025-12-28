// lib/screens/consumer/consumer_home_screen.dart
import 'package:flutter/material.dart';
import 'package:my_test_app/screens/consumer/consumer_widgets.dart';
import 'package:my_test_app/screens/consumer/consumer_data_models.dart';
import 'package:my_test_app/services/consumer_data_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:my_test_app/widgets/chat_support_widget.dart';
import 'package:my_test_app/screens/consumer/consumer_store_search_screen.dart';
import 'package:latlong2/latlong.dart';
import 'package:sizer/sizer.dart';
import 'package:geolocator/geolocator.dart'; // تأكد من وجود المكتبة لجلب الموقع الفعلي

class ConsumerHomeScreen extends StatefulWidget {
  static const routeName = '/consumerHome';
  const ConsumerHomeScreen({super.key});

  @override
  State<ConsumerHomeScreen> createState() => _ConsumerHomeScreenState();
}

class _ConsumerHomeScreenState extends State<ConsumerHomeScreen> {
  final ConsumerDataService dataService = ConsumerDataService();
  final Color softGreen = const Color(0xFF66BB6A);
  final Color darkGreenText = const Color(0xFF2E7D32);

  @override
  void initState() {
    super.initState();
    _setupNotifications();
  }

  Future<void> _setupNotifications() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    FirebaseMessaging messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(alert: true, badge: true, sound: true);
    String? token = await messaging.getToken();
    if (token != null) {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'fcmToken': token,
        'lastTokenUpdate': FieldValue.serverTimestamp(),
      });
    }
  }

  // 🎯 دالة ذكية لجلب الموقع الفعلي والتوجيه لصفحة "ابعتلي حد"
  Future<void> _handleAbaatlyHad() async {
    try {
      // 1. طلب إذن الموقع
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      // 2. جلب الإحداثيات الحالية
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high
      );
      
      LatLng currentLatLng = LatLng(position.latitude, position.longitude);

      // 3. التوجه للمسار مع تمرير الموقع والبيانات
      if (!mounted) return;
      Navigator.pushNamed(
        context, 
        '/abaatly-had', 
        arguments: {
          'location': currentLatLng,
          'isStoreOwner': false, // تتغير لـ true لو استدعيناها من صفحة التاجر
        }
      );
    } catch (e) {
      // في حال فشل جلب الموقع، نمرر موقع افتراضي حتى لا يتوقف التطبيق
      if (!mounted) return;
      Navigator.pushNamed(
        context, 
        '/abaatly-had', 
        arguments: {
          'location': const LatLng(30.0444, 31.2357), 
          'isStoreOwner': false,
        }
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFFBFBFB),
      drawer: const ConsumerSideMenu(),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        toolbarHeight: 75,
        iconTheme: IconThemeData(color: softGreen),
        centerTitle: true,
        title: Column(
          children: [
            Text("مرحباً بك، ${user?.displayName ?? 'مستخدم'}",
                style: TextStyle(color: Colors.black54, fontSize: 10.sp)),
            Text("AMR", style: TextStyle(color: darkGreenText, fontWeight: FontWeight.bold, fontSize: 18.sp)),
          ],
        ),
        actions: [_buildPointsBadge()],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  const SizedBox(height: 100),
                  _buildFreeDeliveryBanner(), // البنر المحدث
                  const ConsumerSectionTitle(title: 'الأقسام المميزة'),
                  _buildCategoriesSection(),
                  const SizedBox(height: 10),
                  const ConsumerSectionTitle(title: 'أحدث العروض الحصرية'),
                  _buildBannersSection(),
                  const SizedBox(height: 120),
                ],
              ),
            ),
            Positioned(top: 15, left: 15, right: 15, child: _buildSmartRadarButton()),
          ],
        ),
      ),
      bottomNavigationBar: const ConsumerFooterNav(cartCount: 0, activeIndex: 0),
    );
  }

  Widget _buildFreeDeliveryBanner() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFFFF9800), Color(0xFFF57C00)]),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.orange.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Row(
          children: [
            _buildBannerIcon(),
            const SizedBox(width: 15),
            Expanded(child: _buildBannerText()),
            ElevatedButton(
              onPressed: _handleAbaatlyHad, // استدعاء الدالة الذكية
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.orange,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text("اطلب الآن", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.sp)),
            ),
          ],
        ),
      ),
    );
  }

  // --- Widgets فرعية للتنظيم ---
  Widget _buildBannerIcon() => Container(
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
    child: Icon(Icons.delivery_dining, color: Colors.white, size: 28.sp),
  );

  Widget _buildBannerText() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text("ابعتلي حد", style: TextStyle(color: Colors.white, fontSize: 16.sp, fontWeight: FontWeight.w900)),
      Text("اطلب مندوب حر لنقل أغراضك فوراً", style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 10.sp)),
    ],
  );

  Widget _buildPointsBadge() => Container(
    margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 15),
    padding: const EdgeInsets.symmetric(horizontal: 10),
    decoration: BoxDecoration(color: Colors.amber.withOpacity(0.1), borderRadius: BorderRadius.circular(15)),
    child: Row(children: [
      const Icon(Icons.stars, color: Colors.orange, size: 18),
      const SizedBox(width: 4),
      Text("0", style: TextStyle(color: darkGreenText, fontWeight: FontWeight.bold, fontSize: 11.sp)),
    ]),
  );

  Widget _buildCategoriesSection() => FutureBuilder<List<ConsumerCategory>>(
    future: dataService.fetchMainCategories(),
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) return const CircularProgressIndicator();
      return ConsumerCategoriesBanner(categories: snapshot.data ?? []);
    },
  );

  Widget _buildBannersSection() => FutureBuilder<List<ConsumerBanner>>(
    future: dataService.fetchPromoBanners(),
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) return const CircularProgressIndicator();
      return ConsumerPromoBanners(banners: snapshot.data ?? [], height: 220);
    },
  );

  Widget _buildSmartRadarButton() => Container(/* كود الرادار كما هو */);
}

