// lib/widgets/seller/seller_sidebar.dart
import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import 'package:my_test_app/services/user_session.dart'; 
import 'package:my_test_app/screens/seller/seller_overview_screen.dart';
import 'package:my_test_app/screens/seller/add_offer_screen.dart';
import 'package:my_test_app/screens/seller/offers_screen.dart';
import 'package:my_test_app/screens/orders_screen.dart';
import 'package:my_test_app/screens/reports_screen.dart';
import 'package:my_test_app/screens/seller/create_gift_promo_screen.dart';
import 'package:my_test_app/screens/seller/seller_settings_screen.dart';
import 'package:my_test_app/screens/delivery_area_screen.dart';
import 'package:my_test_app/screens/platform_balance_screen.dart';

class SellerUserData {
  final String? fullname;
  final bool isSubUser; // تم إضافة هذا الحقل
  SellerUserData({this.fullname, this.isSubUser = false});
}

// ... كود _SidebarItem يبقى كما هو بدون تغيير ...

class SellerSidebar extends StatefulWidget {
  final SellerUserData userData;
  final int newOrdersCount;
  final String activeRoute;
  final Function(String route, Widget screen) onMenuSelected;
  final String sellerId;
  final Function() onLogout;

  const SellerSidebar({
    super.key,
    required this.userData,
    required this.newOrdersCount,
    required this.activeRoute,
    required this.onMenuSelected,
    required this.sellerId,
    required this.onLogout,
  });

  @override
  State<SellerSidebar> createState() => _SellerSidebarState();
}

class _SellerSidebarState extends State<SellerSidebar> {
  late List<Map<String, dynamic>> _menuItems;

  @override
  void initState() {
    super.initState();
    _initializeMenu();
  }

  @override
  void didUpdateWidget(covariant SellerSidebar oldWidget) {
    super.didUpdateWidget(oldWidget);
    _initializeMenu();
  }

  void _initializeMenu() {
    final currentSellerId = widget.sellerId;
    
    // تحديد نوع الصلاحية من الجلسة
    // نفترض أن UserSession.role يحدد: 'full' للأساسي، 'editor' للصلاحية الكاملة، 'viewer' للقراءة فقط
    final bool isOwner = !widget.userData.isSubUser; 
    final bool canEdit = UserSession.canEdit; // true للأساسي والـ editor

    List<Map<String, dynamic>> items = [];

    // 1. نظرة عامة (للجميع)
    items.add({
      'title': 'نظرة عامة',
      'icon': Icons.dashboard_rounded,
      'screen': const SellerOverviewScreen(),
      'route': 'نظرة عامة'
    });

    // 2. إضافة عرض (للأساسي والكامل فقط)
    if (canEdit) {
      items.add({
        'title': 'إضافة عرض',
        'icon': Icons.add_box_rounded,
        'screen': const AddOfferScreen(),
        'route': 'إضافة عرض'
      });
    }

    // 3. العروض والطلبات والتقارير (للجميع)
    items.addAll([
      {
        'title': 'العروض المتاحة',
        'icon': Icons.local_offer_rounded,
        'screen': const OffersScreen(),
        'route': 'العروض المتاحة'
      },
      {
        'title': 'الطلبات',
        'icon': Icons.assignment_rounded,
        'screen': OrdersScreen(sellerId: currentSellerId),
        'route': 'الطلبات'
      },
      {
        'title': 'التقارير',
        'icon': Icons.pie_chart_rounded,
        'screen': ReportsScreen(sellerId: currentSellerId),
        'route': 'التقارير'
      },
    ]);

    // 4. الهدايا ومناطق التوصيل (للأساسي والكامل فقط)
    if (canEdit) {
      items.addAll([
        {
          'title': 'الهدايا الترويجية',
          'icon': Icons.card_giftcard_rounded,
          'screen': CreateGiftPromoScreen(currentSellerId: currentSellerId),
          'route': 'الهدايا الترويجية'
        },
        {
          'title': 'تحديد مناطق التوصيل',
          'icon': Icons.map_rounded,
          'screen': DeliveryAreaScreen(
              currentSellerId: currentSellerId,
              hasWriteAccess: true),
          'route': 'تحديد مناطق التوصيل'
        },
      ]);
    }

    // 5. حساب المنصة (للجميع)
    items.add({
      'title': 'حساب المنصة',
      'icon': Icons.account_balance_rounded,
      'screen': const PlatformBalanceScreen(),
      'route': 'حساب المنصة'
    });

    // 6. "حسابي" (للأساسي فقط 🚫 يُحظر على كل الموظفين)
    if (isOwner) {
      items.add({
        'title': 'حسابي',
        'icon': Icons.manage_accounts_rounded,
        'screen': SellerSettingsScreen(currentSellerId: currentSellerId),
        'route': 'حسابي'
      });
    }

    _menuItems = items;
  }

  @override
  Widget build(BuildContext context) {
    // ... كود الـ UI (Drawer, Header, ListView) يبقى كما هو ...
    // تأكد فقط من استخدام Cairo Font للأناقة
    return Drawer(
      backgroundColor: const Color(0xff1a1d21),
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            decoration: const BoxDecoration(color: Color(0xff212529)),
            currentAccountPicture: CircleAvatar(
              backgroundColor: const Color(0xff28a745),
              child: Text(
                widget.userData.fullname?.substring(0, 1).toUpperCase() ?? "S",
                style: TextStyle(fontSize: 22.sp, color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
            accountName: Text(
              widget.userData.fullname ?? "مورد أكساب",
              style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold, color: Colors.white, fontFamily: 'Cairo'),
            ),
            accountEmail: Text(
              widget.userData.isSubUser ? "حساب موظف" : "حساب إداري (مالك)",
              style: const TextStyle(color: Colors.white70, fontFamily: 'Cairo'),
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: _menuItems.map((item) {
                return _SidebarItem(
                  icon: item['icon'] as IconData,
                  title: item['title'] as String,
                  targetScreen: item['screen'] as Widget,
                  onNavigate: (screen) {
                    Navigator.pop(context);
                    widget.onMenuSelected(item['route'] as String, screen);
                  },
                  isActive: widget.activeRoute == item['route'],
                  notificationCount: item['route'] == 'الطلبات' ? widget.newOrdersCount : 0,
                );
              }).toList(),
            ),
          ),
          const Divider(color: Colors.white10),
          SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 2.h, vertical: 1.h),
              child: TextButton.icon(
                onPressed: widget.onLogout,
                icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
                label: Text('تسجيل الخروج', style: TextStyle(color: Colors.redAccent, fontSize: 13.sp, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
                style: TextButton.styleFrom(minimumSize: Size(double.infinity, 6.h), alignment: Alignment.centerRight),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

