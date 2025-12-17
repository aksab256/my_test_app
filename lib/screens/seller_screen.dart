// lib/screens/seller_screen.dart (النسخة النهائية المطورة بصرياً)

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:my_test_app/controllers/seller_dashboard_controller.dart';
import 'package:my_test_app/widgets/seller/seller_sidebar.dart';
import 'package:my_test_app/models/seller_dashboard_data.dart';
import 'package:my_test_app/screens/seller/seller_overview_screen.dart';
import 'package:sizer/sizer.dart'; // تأكد من استيراد Sizer للتحكم في الأحجام

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
    // حذف المفاتيح لضمان الخروج الآمن [cite: 16-12-2025]
    await prefs.remove('loggedUser');
    await prefs.remove('userToken');
    await prefs.remove('userRole');

    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/');
    }
  }

  @override
  void initState() {
    super.initState();
    // استدعاء البيانات فوراً لكسر حالة التحميل اللانهائية [cite: 16-12-2025]
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
      // --- تطوير الـ AppBar ليكون أضخم وأفخم ---
      appBar: AppBar(
        elevation: 2, // إضافة ظل خفيف للعمق
        centerTitle: true,
        toolbarHeight: 8.h, // زيادة ارتفاع الشريط العلوي قليلاً
        title: Text(
          _activeRoute,
          style: TextStyle(
            fontSize: 16.sp, 
            fontWeight: FontWeight.w900, // خط عريض جداً
            letterSpacing: 0.5,
          ),
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        actions: [
          // إضافة أيقونة تنبيهات سريعة تعطي مظهراً احترافياً
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_none_rounded, size: 28),
                onPressed: () {
                  // يمكن ربطها لاحقاً بصفحة التنبيهات
                },
              ),
              if (controller.data.newOrdersCount > 0)
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: Colors.redAccent,
                      shape: BoxShape.circle,
                    ),
                  ),
                )
            ],
          ),
          const SizedBox(width: 10),
        ],
      ),

      // محتوى الشاشة النشط
      body: _activeScreen,

      // الشريط الجانبي المطور
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
