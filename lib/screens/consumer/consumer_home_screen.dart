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
    // 💡 تم تفريغ initState من طلب الإشعارات الفوري لترك المجال للاحتفالية أولاً
  }

  // ✅ تعديل: طلب الإشعارات يظهر الآن فقط بعد انتهاء رسالة الترحيب
  Future<void> _setupNotificationsAfterCelebration() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    FirebaseMessaging messaging = FirebaseMessaging.instance;
    NotificationSettings settings = await messaging.requestPermission(
      alert: true, badge: true, sound: true
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
          // 🎯 بعد إغلاق الرسالة الترحيبية، نطلب إذن الإشعارات
          _setupNotificationsAfterCelebration();
        },
      ),
    );
    overlayState.insert(overlayEntry);
  }

  Future<void> _checkFirstTimeWelcome(int points) async {
    final prefs = await SharedPreferences.getInstance();
    bool shown = prefs.getBool('welcome_anim_shown_v2') ?? false; 
    
    if (!shown) {
      Future.microtask(() {
        if (mounted) {
          _showCelebrationOverlay(points);
        }
      });
      await prefs.setBool('welcome_anim_shown_v2', true);
    } else {
      // إذا كانت قد ظهرت سابقاً، نطلب الإشعارات فوراً عند الدخول
      _setupNotificationsAfterCelebration();
    }
  }

  // ... (دالة _handleAbaatlyHad كما هي)
  Future<void> _handleAbaatlyHad() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      LatLng currentLatLng = LatLng(position.latitude, position.longitude);

      if (!mounted) return;
      Navigator.pushNamed(context, '/abaatly-had', arguments: {
        'location': currentLatLng,
        'isStoreOwner': false,
      });
    } catch (e) {
      if (!mounted) return;
      Navigator.pushNamed(context, '/abaatly-had', arguments: {
        'location': const LatLng(30.0444, 31.2357),
        'isStoreOwner': false,
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFFBFBFB),
      drawer: const ConsumerSideMenu(), // ✅ الشريط الجانبي موجود هنا
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        toolbarHeight: 90,
        // ✅ زر القائمة الجانبية (leading) سيظهر تلقائياً هنا بفضل الـ Drawer
        iconTheme: IconThemeData(color: softGreen, size: 28),
        centerTitle: true,
        title: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('consumers').doc(user?.uid).snapshots(),
          builder: (context, snapshot) {
            String firstName = "GUEST";
            if (snapshot.hasData && snapshot.data!.exists) {
              final data = snapshot.data!.data() as Map<String, dynamic>;
              final fullStr = data['fullname']?.toString() ?? "";
              if (fullStr.isNotEmpty) {
                firstName = fullStr.split(' ').first.toUpperCase();
              }
            }
            return Column(
              children: [
                Text("مرحباً بك،", style: TextStyle(color: Colors.black54, fontSize: 12.sp)),
                Text(firstName,
                    style: TextStyle(color: darkGreenText, fontWeight: FontWeight.w900, fontSize: 19.sp)),
              ],
            );
          }
        ),
        actions: [
          // ✅ تم نقل الإشعارات هنا بجانب النقاط لعدم حجب زر الـ Menu
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('nofictions')
                .where('userId', isEqualTo: user?.uid)
                .orderBy('createdAt', descending: true)
                .limit(10)
                .snapshots(),
            builder: (context, snapshot) {
              int notificationCount = snapshot.hasData ? snapshot.data!.docs.length : 0;
              return Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: Icon(Icons.notifications_active_outlined, color: softGreen, size: 26),
                    onPressed: () {}, // سيفتح صفحة الإشعارات لاحقاً
                  ),
                  if (notificationCount > 0)
                    Positioned(
                      top: 25,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(10)),
                        constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
                        child: Text('$notificationCount', 
                          style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance.collection('consumers').doc(user?.uid).snapshots(),
            builder: (context, snapshot) {
              int points = 0;
              if (snapshot.hasData && snapshot.data!.exists) {
                var userData = snapshot.data!.data() as Map<String, dynamic>;
                points = userData['loyaltyPoints'] ?? 0;
                bool isProcessed = userData['welcomePointsProcessed'] ?? false;
                if (isProcessed && points > 0) {
                  _checkFirstTimeWelcome(points);
                }
              }
              return _buildPointsBadge(points);
            },
          ),
          const SizedBox(width: 5),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            children: [
              const SizedBox(height: 20),
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
      bottomNavigationBar: const ConsumerFooterNav(cartCount: 0, activeIndex: 0),
    );
  }

  // (بقية الـ Widgets كما هي في كودك)
  Widget _buildSmartRadarButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
      child: InkWell(
        onTap: () => Navigator.pushNamed(context, ConsumerStoreSearchScreen.routeName),
        borderRadius: BorderRadius.circular(40),
        child: Container(
          height: 90,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [softGreen, const Color(0xFF43A047)]),
            borderRadius: BorderRadius.circular(45),
            boxShadow: [BoxShadow(color: softGreen.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 6))],
          ),
          child: Row(
            children: [
              const SizedBox(width: 20),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
                child: const Icon(Icons.radar, color: Colors.white, size: 35),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("اكتشف المحلات القريبة", style: TextStyle(color: Colors.white, fontSize: 15.sp, fontWeight: FontWeight.w900)),
                    Text("تفعيل رادار البحث الذكي", style: TextStyle(color: Colors.white70, fontSize: 10.sp, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              const Icon(Icons.my_location, color: Colors.white, size: 28),
              const SizedBox(width: 25),
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
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFFFF9800), Color(0xFFE65100)]),
          borderRadius: BorderRadius.circular(25),
          boxShadow: [BoxShadow(color: Colors.orange.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Row(
          children: [
            _buildBannerIcon(),
            const SizedBox(width: 15),
            Expanded(child: _buildBannerText()),
            ElevatedButton(
              onPressed: _handleAbaatlyHad,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.orange[900],
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
                elevation: 5,
              ),
              child: Text("اطلب الآن", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12.sp)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBannerIcon() => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
        child: Icon(Icons.delivery_dining, color: Colors.white, size: 30.sp),
      );

  Widget _buildBannerText() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("ابعتلي حد", style: TextStyle(color: Colors.white, fontSize: 17.sp, fontWeight: FontWeight.w900)),
          Text("مندوب حر لنقل أغراضك فوراً", style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 10.sp, fontWeight: FontWeight.bold)),
        ],
      );

  Widget _buildPointsBadge(int points) => InkWell(
        onTap: () => Navigator.pushNamed(context, PointsLoyaltyScreen.routeName),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 15),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.amber.withOpacity(0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.orange.withOpacity(0.5)),
          ),
          child: Row(children: [
            const Icon(Icons.stars, color: Colors.orange, size: 22),
            const SizedBox(width: 6),
            Text(points.toString(), style: TextStyle(color: darkGreenText, fontWeight: FontWeight.w900, fontSize: 13.sp)),
          ]),
        ),
      );

  Widget _buildCategoriesSection() => FutureBuilder<List<ConsumerCategory>>(
        future: dataService.fetchMainCategories(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          return ConsumerCategoriesBanner(categories: snapshot.data ?? []);
        },
      );

  Widget _buildBannersSection() => FutureBuilder<List<ConsumerBanner>>(
        future: dataService.fetchPromoBanners(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          return ConsumerPromoBanners(banners: snapshot.data ?? [], height: 220);
        },
      );
}

// ✅ تعديل: كلاس الاحتفال أصبح أكبر وأكثر فخامة
class _CelebrationWidget extends StatefulWidget {
  final int points;
  final VoidCallback onDismiss;
  const _CelebrationWidget({required this.points, required this.onDismiss});

  @override
  State<_CelebrationWidget> createState() => _CelebrationWidgetState();
}

class _CelebrationWidgetState extends State<_CelebrationWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000));
    _scaleAnimation = CurvedAnimation(parent: _controller, curve: Curves.elasticOut);
    _controller.forward();

    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) {
        _controller.reverse().then((value) => widget.onDismiss());
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black45, // تعتيم الخلفية أكثر لتركيز الانتباه
      child: Center(
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.all(35), // زيادة الحشو الداخلي
            width: 85.w, // عرض أكبر
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(40),
              boxShadow: [BoxShadow(color: Colors.orange.withOpacity(0.5), blurRadius: 30, spreadRadius: 5)],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("🎉", style: TextStyle(fontSize: 60.sp)),
                const SizedBox(height: 15),
                Text("هدية ترحيبية!", style: TextStyle(fontSize: 22.sp, fontWeight: FontWeight.w900, color: Colors.orange)),
                const SizedBox(height: 20),
                RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: TextStyle(fontSize: 16.sp, color: Colors.black87, fontFamily: 'Cairo'),
                    children: [
                      const TextSpan(text: "أهلاً بك في أكسب، جالك\n"),
                      TextSpan(text: "${widget.points} نقطة", style: TextStyle(fontSize: 24.sp, fontWeight: FontWeight.w900, color: const Color(0xFF2E7D32))),
                      const TextSpan(text: "\n\nجمع أكتر.. اكسب أكتر!"),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
