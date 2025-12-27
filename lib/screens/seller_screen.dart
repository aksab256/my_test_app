// lib/screens/seller_screen.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:my_test_app/controllers/seller_dashboard_controller.dart';
import 'package:my_test_app/widgets/seller/seller_sidebar.dart';
import 'package:my_test_app/screens/seller/seller_overview_screen.dart';
import 'package:my_test_app/services/user_session.dart';
import 'package:sizer/sizer.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

// استيراد ودجت الشات
import 'package:my_test_app/widgets/chat_support_widget.dart';

class SellerScreen extends StatefulWidget {
  static const String routeName = '/sellerhome';
  const SellerScreen({super.key});

  @override
  State<SellerScreen> createState() => _SellerScreenState();
}

class _SellerScreenState extends State<SellerScreen> {
  String _activeRoute = 'نظرة عامة';
  Widget _activeScreen = const SellerOverviewScreen();
  final List<Map<String, String>> _recentNotifications = [];

  @override
  void initState() {
    super.initState();
    
    // 1. طلب إذن الإشعارات وتحديث التوكن
    _setupNotifications();

    // 2. تحميل بيانات لوحة التحكم بناءً على الهوية (تاجر أم موظف)
    Future.microtask(() {
      if (!mounted) return;
      final controller = Provider.of<SellerDashboardController>(context, listen: false);
      
      // ✅ نستخدم دائماً ownerId لضمان جلب بيانات المحل الصحيحة للموظف
      final String effectiveId = UserSession.ownerId ?? controller.sellerId;
      controller.loadDashboardData(effectiveId);
    });
  }

  // --- نظام الإشعارات المطور ---
  void _setupNotifications() async {
    try {
      FirebaseMessaging messaging = FirebaseMessaging.instance;

      // طلب الإذن (يظهر النافذة للمستخدم)
      NotificationSettings settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        String? token = await messaging.getToken();
        String? uid = UserSession.userId; // معرف المستخدم الحالي

        if (token != null && uid != null) {
          // تحديث التوكن في المجموعة المناسبة (sellers أو subUsers)
          // ملاحظة: الموظف نحدث بياناته في subUsers باستخدام هاتفه أو الـ UID
          String collection = (UserSession.isSubUser) ? 'subUsers' : 'sellers';
          
          // تحديث Firestore (نستخدم merge لعدم حذف البيانات القديمة)
          await FirebaseFirestore.instance.collection(collection).doc(uid).set({
            'notificationToken': token,
            'fcmToken': token,
            'lastUpdate': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }
      }
    } catch (e) {
      debugPrint("🚨 خطأ في إعداد الإشعارات: $e");
    }
  }

  void _selectMenuItem(String route, Widget screen) {
    setState(() {
      _activeRoute = route;
      _activeScreen = screen;
    });
  }

  void _handleLogout() async {
    UserSession.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/login');
    }
  }

  void _showNotificationsList() {
    // كود عرض قائمة الإشعارات (يمكنك تركه كما هو لديك)
  }

  @override
  Widget build(BuildContext context) {
    final controller = Provider.of<SellerDashboardController>(context);

    return Scaffold(
      appBar: AppBar(
        elevation: 2,
        centerTitle: true,
        toolbarHeight: 8.h,
        title: Text(_activeRoute, style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        actions: [
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_none_rounded, size: 28),
                onPressed: _showNotificationsList,
              ),
              if (_recentNotifications.isNotEmpty)
                Positioned(
                  top: 15,
                  right: 15,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 1.5)),
                  ),
                )
            ],
          ),
          const SizedBox(width: 10),
        ],
      ),
      
      floatingActionButton: FloatingActionButton(
        heroTag: "seller_main_chat",
        backgroundColor: const Color(0xff28a745),
        elevation: 4,
        onPressed: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (context) => const ChatSupportWidget(),
          );
        },
        child: const Icon(Icons.support_agent, color: Colors.white, size: 32),
      ),
      
      body: _activeScreen,
      
      drawer: SellerSidebar(
        userData: SellerUserData(
          fullname: controller.data.sellerName,
          // 🎯 تمرير حالة الموظف للتحكم في ظهور القوائم
          isSubUser: UserSession.isSubUser, 
        ),
        onMenuSelected: _selectMenuItem,
        activeRoute: _activeRoute,
        onLogout: _handleLogout,
        newOrdersCount: controller.data.newOrdersCount,
        sellerId: UserSession.ownerId ?? controller.sellerId,
      ),
    );
  }
}

