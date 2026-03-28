// lib/screens/buyer/buyer_home_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'dart:convert';

// استيراد الـ Widgets والمحتويات
import 'package:my_test_app/widgets/home_content.dart';
import 'package:my_test_app/widgets/buyer_header_widget.dart';
import 'package:my_test_app/widgets/buyer_mobile_nav_widget.dart';
import 'package:my_test_app/widgets/chat_support_widget.dart';

// 🎯 استيراد الصفحة مباشرة لضمان عمل التوجيه المستقل
import 'package:my_test_app/screens/buyer/my_orders_screen.dart';

final FirebaseAuth _auth = FirebaseAuth.instance;
final FirebaseFirestore _db = FirebaseFirestore.instance;

class BuyerHomeScreen extends StatefulWidget {
  static const String routeName = '/buyerHome';
  const BuyerHomeScreen({super.key});

  @override
  State<BuyerHomeScreen> createState() => _BuyerHomeScreenState();
}

// 🛑 إضافة SingleTickerProviderStateMixin للتحكم في الأنميشن
class _BuyerHomeScreenState extends State<BuyerHomeScreen> with SingleTickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // 🎯 نحن في الصفحة الرئيسية، لذا الاندكس هو 1 دائماً في هذا الملف
  final int _selectedIndex = 1;

  String _userName = 'مرحباً بك!';
  String? _currentUserId;
  int _newOrdersCount = 0;
  int _cartCount = 0;
  bool _deliverySettingsAvailable = false;
  bool _deliveryPricesAvailable = false;
  bool _deliveryIsActive = false;

  // 🚀 متغيرات الأنميشن (النبض)
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAppLogic();

    // 🚀 تهيئة أنميشن النبض: الحركة ناعمة وبطيئة (ثانية ونصف للنبضة الواحدة)
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    // النبض بيبدأ من الحجم الطبيعي (1.0) لزيادة خفيفة جداً (1.1) ويرجع تاني
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // جعل الأنميشن يستمر للأبد (ينبض ويرجع)
    _pulseController.repeat(reverse: true);
  }

  @override
  void dispose() {
    // 🛑 مهم جداً: إغلاق الكنترولر عند إغلاق الصفحة لمنع تسريب الذاكرة
    _pulseController.dispose();
    super.dispose();
  }

  // --- منطق تهيئة التطبيق ---
  void _initializeAppLogic() async {
    final userAuth = _auth.currentUser;
    if (userAuth == null) return;
    _currentUserId = userAuth.uid;

    final prefs = await SharedPreferences.getInstance();
    _updateCartCount(prefs);

    try {
      final userDoc = await _db.collection('users').doc(_currentUserId).get();
      if (userDoc.exists && mounted) {
        final fullName = userDoc.data()?['fullname'] ?? 'زائر أكسب';
        setState(() => _userName = 'أهلاً بك، $fullName!');
      }
    } catch (e) {
      debugPrint('Error loading user data: $e');
    }

    // استدعاء دالة الفحص
    await _checkDeliveryStatusAndDisplayIcons();
    await _updateNewDealerOrdersCount();

    // استدعاء الإشعارات في النهاية بعد فحص الحالة والبيانات
    _setupNotifications();
  }

  // --- منطق الإشعارات المطور: يمنع الظهور إذا كان الإذن ممنوحاً بالفعل ---
  Future<void> _setupNotifications() async {
    if (_currentUserId == null) return;

    // 1. فحص حالة الإذن الحالية للجهاز
    FirebaseMessaging messaging = FirebaseMessaging.instance;
    NotificationSettings currentSettings = await messaging.getNotificationSettings();

    // إذا كان الإذن ممنوحاً بالفعل، نحدث التوكن بصمت ونخرج
    if (currentSettings.authorizationStatus == AuthorizationStatus.authorized) {
      String? token = await messaging.getToken();
      if (token != null) {
        await _db.collection('users').doc(_currentUserId).update({
          'fcmToken': token,
          'notificationsEnabled': true,
        });
      }
      return;
    }

    // 2. إذا لم يكن لديه إذن، نتحقق من الـ SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    bool alreadyShown = prefs.getBool('notifications_dialog_shown') ?? false;
    if (alreadyShown) return;

    if (!mounted) return;

    bool? userAgreed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Text("تفعيل التنبيهات", textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
        content: const Text("يرجى تفعيل التنبيهات لتتمكن من متابعة حالة طلباتك والعروض الجديدة فور حدوثها.", textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Tajawal')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("ليس الآن", style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4CAF50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            child: const Text("موافق", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    await prefs.setBool('notifications_dialog_shown', true);

    if (userAgreed == true) {
      NotificationSettings settings = await messaging.requestPermission(alert: true, badge: true, sound: true);

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        String? token = await messaging.getToken();
        if (token != null) {
          await _db.collection('users').doc(_currentUserId).update({
            'fcmToken': token,
            'role': 'buyer',
            'lastTokenUpdate': FieldValue.serverTimestamp(),
            'notificationsEnabled': true,
          });
        }
      }
    }
  }

  void _updateCartCount(SharedPreferences prefs) {
    String? cartData = prefs.getString('cart_items');
    if (cartData != null) {
      List<dynamic> items = jsonDecode(cartData);
      if (mounted) setState(() => _cartCount = items.length);
    } else {
      if (mounted) setState(() => _cartCount = 0);
    }
  }

  // ✅ التعديل الجوهري بناءً على المنطق الجديد:
  Future<void> _checkDeliveryStatusAndDisplayIcons() async {
    if (_currentUserId == null) return;
    try {
      // 1. فحص مجموعة الانتظار لحظياً
      _db.collection('pendingSupermarkets').doc(_currentUserId).snapshots().listen((pendingDoc) {
        // 2. فحص مجموعة المقبولين لحظياً
        _db.collection('deliverySupermarkets').doc(_currentUserId).snapshots().listen((approvedDoc) {
          if (mounted) {
            setState(() {
              // أيقونة الاشتراك تظهر فقط لو مش موجود في الاثنين
              if (!pendingDoc.exists && !approvedDoc.exists) {
                _deliverySettingsAvailable = true;
              } else {
                _deliverySettingsAvailable = false;
              }

              // أيقونات الإدارة تظهر فقط لو موجود في المقبولين
              if (approvedDoc.exists) {
                final data = approvedDoc.data() as Map<String, dynamic>;
                _deliveryPricesAvailable = true;
                _deliveryIsActive = data['isActive'] ?? false;
              } else {
                _deliveryPricesAvailable = false;
                _deliveryIsActive = false;
              }
            });
          }
        });
      });
    } catch (e) {
      debugPrint("Delivery Status Error: $e");
    }
  }

  Future<void> _updateNewDealerOrdersCount() async {
    if (_currentUserId == null) return;
    final q = await _db.collection('consumerorders')
        .where("supermarketId", isEqualTo: _currentUserId)
        .where("status", isEqualTo: "new-order").get();
    if (mounted) setState(() => _newOrdersCount = q.size);
  }

  void _onItemTapped(int index) {
    if (index == _selectedIndex) return;
    switch (index) {
      case 0:
        Navigator.pushNamed(context, '/traders');
        break;
      case 1:
        break; // نحن هنا بالفعل
      case 2:
        Navigator.push(context, MaterialPageRoute(builder: (context) => const MyOrdersScreen()));
        break;
      case 3:
        Navigator.pushNamed(context, '/wallet');
        break;
    }
  }

  void _handleLogout() async {
    try {
      await _auth.signOut();
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      if (mounted) Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
    } catch (e) {
      debugPrint('Logout Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: const Color(0xFFf5f7fa),
        endDrawer: BuyerHeaderWidget.buildSidebar(
          context: context,
          onLogout: _handleLogout,
          newOrdersCount: _newOrdersCount,
          deliverySettingsAvailable: _deliverySettingsAvailable,
          deliveryPricesAvailable: _deliveryPricesAvailable,
          deliveryIsActive: _deliveryIsActive,
        ),
        body: Column(
          children: <Widget>[
            BuyerHeaderWidget(
              onMenuToggle: () => _scaffoldKey.currentState?.openEndDrawer(),
              menuNotificationDotActive: _newOrdersCount > 0,
              userName: _userName,
              onLogout: _handleLogout,
            ),
            const Expanded(child: HomeContent()),
          ],
        ),
        bottomNavigationBar: BuyerMobileNavWidget(
          selectedIndex: _selectedIndex,
          onItemSelected: _onItemTapped,
          cartCount: _cartCount,
          ordersChanged: false,
        ),
        // 🚀 تحديث أيقونة شـيرا لتكون هي اللوجو الجديد وتصميم عصري عائم
        floatingActionButton: GestureDetector(
          onTap: () {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (context) => const ChatSupportWidget(),
            );
          },
          // 🚀 استخدام ScaleTransition لتنفيذ تأثير النبض
          child: ScaleTransition(
            scale: _pulseAnimation,
            child: Hero(
              tag: "buyer_home_chat_btn",
              child: Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xff1a237e), Color(0xFF4CAF50)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xff1a237e).withOpacity(0.4),
                      blurRadius: 15,
                      spreadRadius: 2,
                      offset: const Offset(0, 5),
                    ),
                  ],
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // استخدام اللوجو الجديد كخلفية للزر
                    ClipOval(
                      child: Image.asset(
                        'assets/images/shira_logo.png',
                        width: 55,
                        height: 55,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => 
                            const Icon(Icons.auto_awesome, color: Colors.white, size: 30),
                      ),
                    ),
                    // مؤشر "الذكاء" النشط
                    Positioned(
                      top: 5,
                      right: 5,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: Colors.yellowAccent,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

