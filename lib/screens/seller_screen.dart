// lib/screens/seller_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // ✅ مطلوب لعملية إغلاق التطبيق
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:my_test_app/controllers/seller_dashboard_controller.dart';
import 'package:my_test_app/widgets/seller/seller_sidebar.dart';
import 'package:my_test_app/screens/seller/seller_overview_screen.dart';
import 'package:my_test_app/services/user_session.dart';
import 'package:sizer/sizer.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
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
  
  // ✅ متغير للتحكم في توقيت الضغط المزدوج
  DateTime? _lastPressedAt;

  @override
  void initState() {
    super.initState();
    _setupNotifications();
    Future.microtask(() {
      if (!mounted) return;
      final controller = Provider.of<SellerDashboardController>(context, listen: false);
      final String effectiveId = UserSession.ownerId ?? controller.sellerId;
      controller.loadDashboardData(effectiveId);
    });
  }

  // ✅ إعداد الإشعارات مع الإفصاح المسبق المتوافق مع جوجل بلاي
  void _setupNotifications() async {
    try {
      FirebaseMessaging messaging = FirebaseMessaging.instance;
      
      // فحص حالة الإذن الحالية
      NotificationSettings currentSettings = await messaging.getNotificationSettings();

      if (currentSettings.authorizationStatus == AuthorizationStatus.notDetermined) {
        if (!mounted) return;
        
        // إظهار رسالة الإفصاح قبل طلب النظام
        bool proceed = await _showNotificationDisclosure();
        
        if (proceed) {
          NotificationSettings settings = await messaging.requestPermission(
            alert: true, badge: true, sound: true,
          );
          _updateFcmToken(settings);
        }
      } else {
        _updateFcmToken(currentSettings);
      }
    } catch (e) {
      debugPrint("🚨 خطأ في إعداد الإشعارات: $e");
    }
  }

  // 🛡️ دالة الإفصاح البارز
  Future<bool> _showNotificationDisclosure() async {
    return await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.notifications_active, color: Color(0xff28a745)),
              SizedBox(width: 10),
              Text("تفعيل الإشعارات", style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
            ],
          ),
          content: const Text(
            "يقوم تطبيق أسواق أكسب بجمع بيانات الإشعارات لإرسال تنبيهات فورية حول الطلبات الجديدة، تحديثات حالة الشحن، والرسائل الإدارية لضمان متابعة عملك بدقة.",
            style: TextStyle(fontFamily: 'Cairo', fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("ليس الآن", style: TextStyle(color: Colors.grey, fontFamily: 'Cairo')),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xff28a745),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text("موافق وتفعيل", style: TextStyle(color: Colors.white, fontFamily: 'Cairo')),
            ),
          ],
        ),
      ),
    ) ?? false;
  }

  // دالة تحديث التوكن
  void _updateFcmToken(NotificationSettings settings) async {
    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      String? token = await FirebaseMessaging.instance.getToken();
      String? uid = UserSession.userId;

      if (token != null && uid != null) {
        String collection = (UserSession.isSubUser) ? 'subUsers' : 'sellers';
        await FirebaseFirestore.instance.collection(collection).doc(uid).set({
          'notificationToken': token,
          'fcmToken': token,
          'lastUpdate': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
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

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        if (_activeRoute != 'نظرة عامة') {
          setState(() {
            _activeRoute = 'نظرة عامة';
            _activeScreen = const SellerOverviewScreen();
          });
          return;
        }

        final now = DateTime.now();
        final isWarningTarget = _lastPressedAt == null || 
            now.difference(_lastPressedAt!) > const Duration(seconds: 2);

        if (isWarningTarget) {
          _lastPressedAt = now;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'اضغط مرة أخرى للخروج من التطبيق',
                textAlign: TextAlign.center,
                style: TextStyle(fontFamily: 'Cairo', color: Colors.white),
              ),
              backgroundColor: Colors.black87,
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              margin: EdgeInsets.only(bottom: 10.h, left: 20.w, right: 20.w),
            ),
          );
          return;
        }

        if (context.mounted) {
          SystemNavigator.pop(); 
        }
      },
      child: Scaffold(
        appBar: AppBar(
          elevation: 2,
          centerTitle: true,
          toolbarHeight: 8.h,
          title: Text(_activeRoute, style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Colors.white,
          actions: [
            _buildNotificationBell(),
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
      ),
    );
  }

  Widget _buildNotificationBell() {
    return StreamBuilder<QuerySnapshot>(
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
          child: Stack(
            alignment: Alignment.center,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Icon(Icons.notifications_none_rounded, size: 28),
              ),
              if (hasNotifications)
                Positioned(
                  top: 15, right: 15,
                  child: Container(
                    width: 10, height: 10,
                    decoration: BoxDecoration(
                      color: Colors.redAccent, shape: BoxShape.circle, 
                      border: Border.all(color: Colors.white, width: 1.5)),
                  ),
                )
            ],
          ),
          itemBuilder: (context) {
            if (!hasNotifications) {
              return [const PopupMenuItem(enabled: false, child: Center(child: Text("لا توجد إشعارات", style: TextStyle(fontFamily: 'Cairo', fontSize: 12))))];
            }
            return snapshot.data!.docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return PopupMenuItem<int>(
                enabled: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(data['title'] ?? 'تنبيه جديد', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, fontFamily: 'Cairo', color: Colors.black)),
                    const SizedBox(height: 4),
                    Text(data['message'] ?? '', style: const TextStyle(fontSize: 11, color: Colors.black54, fontFamily: 'Cairo')),
                    const Divider(),
                  ],
                ),
              );
            }).toList();
          },
        );
      }
    );
  }
}
