// lib/screens/seller_screen.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:my_test_app/controllers/seller_dashboard_controller.dart';
import 'package:my_test_app/widgets/seller/seller_sidebar.dart';
import 'package:my_test_app/models/seller_dashboard_data.dart';
import 'package:my_test_app/screens/seller/seller_overview_screen.dart';
import 'package:sizer/sizer.dart';
// 🎯 استيرادات الإشعارات
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:permission_handler/permission_handler.dart';

class SellerScreen extends StatefulWidget {
  static const String routeName = '/sellerhome';
  const SellerScreen({super.key});

  @override
  State<SellerScreen> createState() => _SellerScreenState();
}

class _SellerScreenState extends State<SellerScreen> {
  String _activeRoute = 'نظرة عامة';
  Widget _activeScreen = const SellerOverviewScreen();

  void _selectMenuItem(String route, Widget screen) {
    setState(() {
      _activeRoute = route;
      _activeScreen = screen;
    });
  }

  void _handleLogout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('loggedUser');
    await prefs.remove('userToken');
    await prefs.remove('userRole');
    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/');
    }
  }

  // 🎯 دالة طلب الإذن وإعداد استقبال الإشعارات
  void _setupNotifications() async {
    // 1. طلب الإذن باستخدام permission_handler لضمان الاستقرار في أندرويد 13+
    var status = await Permission.notification.status;
    if (status.isDenied) {
      await Permission.notification.request();
    }

    // 2. إعداد Firebase Messaging
    FirebaseMessaging messaging = FirebaseMessaging.instance;

    // طلب الإذن من Firebase (إضافي للتأكيد)
    await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // 3. الحصول على الـ Token (مفيد للـ Debugging ولتحديث الداتابيز)
    String? token = await messaging.getToken();
    print('🔥 Seller FCM Token: $token');

    // 4. الاستماع للإشعارات والتطبيق مفتوح
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.notification != null && mounted) {
        _showNotificationDialog(
          message.notification!.title ?? "إشعار جديد",
          message.notification!.body ?? "",
        );
      }
    });
  }

  // دالة لإظهار تنبيه داخلي احترافي
  void _showNotificationDialog(String title, String body) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Row(
          children: [
            Icon(Icons.notifications_active, color: Theme.of(context).primaryColor),
            const SizedBox(width: 10),
            Text(title),
          ],
        ),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('حسناً', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();

    // 🎯 طلب الإذن بعد ثانية واحدة من استقرار الشاشة
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) _setupNotifications();
    });

    Future.microtask(() {
      if (!mounted) return;
      final controller = Provider.of<SellerDashboardController>(context, listen: false);
      controller.loadDashboardData(controller.sellerId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = Provider.of<SellerDashboardController>(context);

    return Scaffold(
      appBar: AppBar(
        elevation: 2,
        centerTitle: true,
        toolbarHeight: 8.h,
        title: Text(
          _activeRoute,
          style: TextStyle(
            fontSize: 16.sp,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.5,
          ),
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        actions: [
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_none_rounded, size: 28),
                onPressed: () {
                  // 🎯 التحسين: إعادة توجيه المستخدم لصفحة "نظرة عامة" لتحديث البيانات أو رؤية التنبيهات
                  _selectMenuItem('نظرة عامة', const SellerOverviewScreen());
                },
              ),
              if (controller.data.newOrdersCount > 0)
                Positioned(
                  top: 15,
                  right: 15,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: Colors.redAccent,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                  ),
                )
            ],
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: _activeScreen,
      drawer: SellerSidebar(
        userData: SellerUserData(fullname: controller.data.sellerName),
        onMenuSelected: _selectMenuItem,
        activeRoute: _activeRoute,
        onLogout: _handleLogout,
        newOrdersCount: controller.data.newOrdersCount,
        sellerId: controller.sellerId,
        hasWriteAccess: true,
      ),
    );
  }
}

