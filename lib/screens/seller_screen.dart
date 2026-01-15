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
  // تم الاستغناء عن المصفوفة اليدوية واستبدالها بالـ Stream في الـ UI

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
          // ✅ منطق الإشعارات المدمج (تشغيل الأيقونة الأصلية)
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('notifications')
                .where('userId', isEqualTo: UserSession.userId)
                .orderBy('createdAt', descending: true)
                .limit(10)
                .snapshots(),
            builder: (context, snapshot) {
              bool hasNotifications = snapshot.hasData && snapshot.data!.docs.isNotEmpty;

              return PopupMenuButton<int>(
                offset: const Offset(0, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                // 🎯 الحفاظ على نفس تصميم الـ Stack والأيقونة الأصلية
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Icon(Icons.notifications_none_rounded, size: 28),
                    ),
                    if (hasNotifications)
                      Positioned(
                        top: 15,
                        right: 15,
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: Colors.redAccent, 
                            shape: BoxShape.circle, 
                            border: Border.all(color: Colors.white, width: 1.5)
                          ),
                        ),
                      )
                  ],
                ),
                itemBuilder: (context) {
                  if (!hasNotifications) {
                    return [
                      const PopupMenuItem(
                        enabled: false,
                        child: Center(child: Text("لا توجد إشعارات", style: TextStyle(fontFamily: 'Cairo', fontSize: 12))),
                      )
                    ];
                  }
                  return snapshot.data!.docs.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    return PopupMenuItem<int>(
                      enabled: false,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(data['title'] ?? 'تنبيه جديد', 
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, fontFamily: 'Cairo', color: Colors.black)),
                          const SizedBox(height: 4),
                          Text(data['message'] ?? '', 
                            style: const TextStyle(fontSize: 11, color: Colors.black54, fontFamily: 'Cairo')),
                          const Divider(),
                        ],
                      ),
                    );
                  }).toList();
                },
              );
            }
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
