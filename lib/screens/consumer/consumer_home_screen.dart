// lib/screens/consumer/consumer_home_screen.dart

import 'package:flutter/material.dart';
import 'package:my_test_app/screens/consumer/consumer_widgets.dart';
import 'package:my_test_app/screens/consumer/consumer_data_models.dart';
import 'package:my_test_app/services/consumer_data_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:my_test_app/screens/consumer/consumer_store_search_screen.dart';
import 'package:my_test_app/screens/consumer/points_loyalty_screen.dart';
import 'package:my_test_app/widgets/promo_slider_widget.dart'; 
import 'package:my_test_app/widgets/chat_support_widget.dart'; 
import 'package:latlong2/latlong.dart';
import 'package:sizer/sizer.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ConsumerHomeScreen extends StatefulWidget {
  static const routeName = '/consumerhome'; 
  const ConsumerHomeScreen({super.key});

  @override
  State<ConsumerHomeScreen> createState() => _ConsumerHomeScreenState();
}

class _ConsumerHomeScreenState extends State<ConsumerHomeScreen> with SingleTickerProviderStateMixin {
  final ConsumerDataService dataService = ConsumerDataService();
  final Color softGreen = const Color(0xFF66BB6A);
  final Color darkGreenText = const Color(0xFF2E7D32);
  bool _celebrationTriggered = false; 

  @override
  void initState() {
    super.initState();
    _checkInitialPoints();
    _checkForPendingRating();
  }

  void _checkForPendingRating() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final query = await FirebaseFirestore.instance
        .collection('specialRequests')
        .where('userId', isEqualTo: user.uid)
        .where('status', isEqualTo: 'delivered')
        .where('isRated', isEqualTo: false)
        .limit(1)
        .get();

    if (query.docs.isNotEmpty) {
      final orderId = query.docs.first.id;
      if (mounted) {
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) Navigator.pushNamed(context, '/customerTracking', arguments: orderId);
        });
      }
    }
  }

  void _checkInitialPoints() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance.collection('consumers').doc(user.uid).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        int points = data['loyaltyPoints'] ?? 0;
        _checkFirstTimeWelcome(points);
      }
    }
  }

  Future<void> _requestNotificationPermissions() async {
    final prefs = await SharedPreferences.getInstance();
    bool alreadyAsked = prefs.getBool('notifications_asked') ?? false;
    
    if (alreadyAsked || !mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text("تفعيل التنبيهات"),
          content: const Text("يرجى السماح بالتنبيهات لتصلك تحديثات طلباتك وعروضنا الحصرية أولاً بأول."),
          actions: [
            TextButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await prefs.setBool('notifications_asked', true);
                FirebaseMessaging messaging = FirebaseMessaging.instance;
                await messaging.requestPermission(alert: true, badge: true, sound: true);
                String? token = await messaging.getToken();
                if (token != null && FirebaseAuth.instance.currentUser != null) {
                  await FirebaseFirestore.instance.collection('users').doc(FirebaseAuth.instance.currentUser!.uid).set({
                    'fcmToken': token,
                    'lastTokenUpdate': FieldValue.serverTimestamp(),
                  }, SetOptions(merge: true));
                }
              },
              child: const Text("موافق", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _showCelebrationOverlay(int points) {
    if (_celebrationTriggered) return;
    _celebrationTriggered = true;
    OverlayState? overlayState = Overlay.of(context);
    late OverlayEntry overlayEntry;
    overlayEntry = OverlayEntry(
      builder: (context) => _CelebrationWidget(
        points: points, 
        onDismiss: () {
          overlayEntry.remove();
          _requestNotificationPermissions();
        },
      ),
    );
    overlayState.insert(overlayEntry);
  }

  Future<void> _checkFirstTimeWelcome(int points) async {
    final prefs = await SharedPreferences.getInstance();
    bool shown = prefs.getBool('welcome_anim_shown_v2') ?? false; 
    if (!shown) {
      Future.microtask(() { if (mounted) _showCelebrationOverlay(points); });
      await prefs.setBool('welcome_anim_shown_v2', true);
    } else {
      _requestNotificationPermissions();
    }
  }

  Future<void> _handleSmartRadarNavigation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      LatLng currentLatLng = LatLng(position.latitude, position.longitude);
      if (!mounted) return;
      Navigator.pushNamed(context, ConsumerStoreSearchScreen.routeName, arguments: {'userLocation': currentLatLng});
    } catch (e) {
      Navigator.pushNamed(context, ConsumerStoreSearchScreen.routeName, arguments: {'userLocation': const LatLng(30.0444, 31.2357)});
    }
  }

  Future<void> _handleAbaatlyHad() async {
    try {
      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      LatLng currentLatLng = LatLng(position.latitude, position.longitude);
      if (!mounted) return;
      Navigator.pushNamed(context, '/abaatly-had', arguments: {'location': currentLatLng, 'isStoreOwner': false});
    } catch (e) {
      Navigator.pushNamed(context, '/abaatly-had', arguments: {'location': const LatLng(30.0444, 31.2357), 'isStoreOwner': false});
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFFBFBFB),
        drawer: const ConsumerSideMenu(), 
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          toolbarHeight: 90,
          iconTheme: IconThemeData(color: softGreen, size: 28),
          centerTitle: true,
          title: StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance.collection('consumers').doc(user?.uid).snapshots(),
            builder: (context, snapshot) {
              String firstName = "زائر";
              if (snapshot.hasData && snapshot.data!.exists) {
                final data = snapshot.data!.data() as Map<String, dynamic>;
                firstName = (data['fullname'] ?? "").toString().split(' ').first;
              }
              return Column(
                children: [
                  Text("مرحباً بك،", style: TextStyle(color: Colors.black54, fontSize: 10.sp)),
                  Text(firstName.isEmpty ? "زائر" : firstName,
                      style: TextStyle(color: darkGreenText, fontWeight: FontWeight.w900, fontSize: 17.sp)),
                ],
              );
            }
          ),
          actions: [_buildNotificationIcon(user?.uid), _buildPointsStream(user?.uid), const SizedBox(width: 5)],
        ),
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: () async => setState(() {}),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  const SizedBox(height: 15),
                  _buildSmartRadarButton(),
                  _buildFreeDeliveryBanner(),
                  const ConsumerSectionTitle(title: 'الأقسام المميزة'),
                  _buildCategoriesSection(),
                  const SizedBox(height: 10),
                  const ConsumerSectionTitle(title: 'أحدث العروض الحصرية'),
                  _buildBannersSection(),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ),
        // 🛡️ تأمين زر الشات ليكون دائماً فوق شريط التنقل بمسافة واضحة
        floatingActionButton: Padding(
          padding: const EdgeInsets.only(bottom: 10), 
          child: FloatingActionButton(
            heroTag: "consumer_home_chat_btn",
            onPressed: () {
              showModalBottomSheet(
                context: context, 
                isScrollControlled: true, 
                backgroundColor: Colors.transparent, 
                builder: (context) => const ChatSupportWidget()
              );
            },
            backgroundColor: softGreen,
            child: const Icon(Icons.support_agent, color: Colors.white, size: 30),
          ),
        ),
        // 🛡️ تأمين شريط التنقل السفلي باستخدام SafeArea
        bottomNavigationBar: SafeArea(
          top: false,
          child: const ConsumerFooterNav(cartCount: 0, activeIndex: 0),
        ),
      ),
    );
  }

  Widget _buildSmartRadarButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
      child: InkWell(
        onTap: _handleSmartRadarNavigation,
        child: Container(
          height: 100,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [softGreen, const Color(0xFF43A047)]),
            borderRadius: BorderRadius.circular(45),
            boxShadow: [BoxShadow(color: softGreen.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 6))]
          ),
          child: Row(
            children: [
              const SizedBox(width: 20),
              const Icon(Icons.radar, color: Colors.white, size: 40),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text("اكتشف المحلات القريبة", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
                    Text("تفعيل رادار البحث الذكي", style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_left, color: Colors.white),
              const SizedBox(width: 20)
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFreeDeliveryBanner() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFFFF9800), Color(0xFFE65100)]),
          borderRadius: BorderRadius.circular(25),
        ),
        child: Row(
          children: [
            Icon(Icons.delivery_dining, color: Colors.white, size: 35.sp),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text("ابعتلي حد", style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
                  Text("مندوب توصيل خاص بك", style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: _handleAbaatlyHad,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.orange[900],
                padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              ),
              child: const Text("اطلب الآن", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationIcon(String? uid) {
    if (uid == null) return const SizedBox.shrink();
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('notifications').where('userId', isEqualTo: uid).orderBy('createdAt', descending: true).limit(10).snapshots(),
      builder: (context, snapshot) {
        int count = snapshot.hasData ? snapshot.data!.docs.length : 0;
        return PopupMenuButton<int>(
          icon: Stack(children: [Icon(Icons.notifications_none, color: softGreen, size: 28), if (count > 0) Positioned(right: 0, top: 0, child: CircleAvatar(radius: 7, backgroundColor: Colors.red, child: Text('$count', style: const TextStyle(fontSize: 8, color: Colors.white))))]),
          itemBuilder: (ctx) {
             if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
               return [const PopupMenuItem<int>(value: 0, child: Text("لا توجد إشعارات"))];
             }
             return snapshot.data!.docs.map((d) {
               return PopupMenuItem<int>(
                 value: 1,
                 child: Text(d['title'] ?? 'إشعار', style: const TextStyle(fontSize: 12)),
               );
             }).toList();
          },
        );
      },
    );
  }

  Widget _buildPointsStream(String? uid) => StreamBuilder<DocumentSnapshot>(
    stream: FirebaseFirestore.instance.collection('consumers').doc(uid).snapshots(),
    builder: (context, snapshot) => _buildPointsBadge(snapshot.hasData ? (snapshot.data!.data() as Map<String, dynamic>)['loyaltyPoints'] ?? 0 : 0)
  );

  Widget _buildPointsBadge(int points) => InkWell(onTap: () => Navigator.pushNamed(context, PointsLoyaltyScreen.routeName), child: Container(margin: const EdgeInsets.all(10), padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(color: Colors.amber.withOpacity(0.2), borderRadius: BorderRadius.circular(15)), child: Row(children: [const Icon(Icons.stars, color: Colors.orange, size: 20), const SizedBox(width: 5), Text(points.toString(), style: const TextStyle(fontWeight: FontWeight.bold))])));

  Widget _buildCategoriesSection() => FutureBuilder<List<ConsumerCategory>>(future: dataService.fetchMainCategories(), builder: (context, snapshot) => snapshot.connectionState == ConnectionState.waiting ? const LinearProgressIndicator() : ConsumerCategoriesBanner(categories: snapshot.data ?? []));

  Widget _buildBannersSection() => FutureBuilder<List<ConsumerBanner>>(future: dataService.fetchPromoBanners(), builder: (context, snapshot) => snapshot.hasData ? PromoSliderWidget(banners: snapshot.data!, height: 160.0) : const SizedBox.shrink());
}

class _CelebrationWidget extends StatefulWidget {
  final int points;
  final VoidCallback onDismiss;
  const _CelebrationWidget({required this.points, required this.onDismiss});
  @override
  State<_CelebrationWidget> createState() => _CelebrationWidgetState();
}

class _CelebrationWidgetState extends State<_CelebrationWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;
  @override
  void initState() { super.initState(); _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 800)); _scale = CurvedAnimation(parent: _controller, curve: Curves.elasticOut); _controller.forward(); }
  @override
  void dispose() { _controller.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) { 
    return Material(color: Colors.black45, child: Center(child: ScaleTransition(scale: _scale, child: Container(margin: const EdgeInsets.all(30), padding: const EdgeInsets.all(30), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(30)), child: Column(mainAxisSize: MainAxisSize.min, children: [Text("🎉", style: TextStyle(fontSize: 40.sp)), const SizedBox(height: 20), Text("هدية ترحيبية!", style: TextStyle(fontSize: 22.sp, fontWeight: FontWeight.bold, color: Colors.orange)), const SizedBox(height: 10), Text("لقد حصلت على ${widget.points} نقطة", style: TextStyle(fontSize: 16.sp)), const SizedBox(height: 30), ElevatedButton(onPressed: widget.onDismiss, child: const Text("استمتع الآن"))]))))); 
  }
}
