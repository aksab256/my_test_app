import 'package:flutter/material.dart';

// 🟢 استيراد الشاشات الحقيقية كما وردت في main.dart
import 'package:my_test_app/screens/buyer/my_orders_screen.dart';
import 'package:my_test_app/screens/buyer/cart_screen.dart';
import 'package:my_test_app/widgets/home_content.dart';

// ملاحظة: إذا كان اسم ملف التجار هو TradersScreen تأكد من وجود الملف في هذا المسار
// بناءً على سياق المشروع، سنحاول استيراده أو استبداله بالويدجت المناسب
import 'package:my_test_app/screens/buyer/traders_screen.dart'; 

class BuyerMobileNavWidget extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onItemSelected;
  final int cartCount;
  final bool ordersChanged;

  const BuyerMobileNavWidget({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
    this.cartCount = 0,
    this.ordersChanged = false,
  });

  // 🟢 ربط الصفحات الحقيقية بالترتيب الصحيح للأيقونات
  static final List<Widget> mainPages = [
    const MyOrdersScreen(),    // Index 0: مشترياتي (شغالة فعلياً)
    const HomeContent(),       // Index 1: الرئيسية (البانرات والأقسام)
    const CartScreen(),        // Index 2: السلة (شغالة فعلياً)
    const TradersScreen(),     // Index 3: التجار (هنا سيظهر الوميض لإصلاحه لاحقاً)
    const Center(child: Text('محفظتي قيد التطوير')), // Index 4: المحفظة
  ];

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      selectedIndex: selectedIndex,
      onDestinationSelected: onItemSelected,
      backgroundColor: Colors.white,
      indicatorColor: const Color(0xFF4CAF50).withOpacity(0.1),
      destinations: [
        NavigationDestination(
          icon: Badge(
            isLabelVisible: ordersChanged,
            child: const Icon(Icons.shopping_bag_outlined),
          ),
          selectedIcon: const Icon(Icons.shopping_bag_rounded),
          label: 'مشترياتي',
        ),
        const NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home_rounded),
          label: 'الرئيسية',
        ),
        NavigationDestination(
          icon: Badge(
            label: Text('$cartCount'),
            isLabelVisible: cartCount > 0,
            child: const Icon(Icons.shopping_cart_outlined),
          ),
          selectedIcon: const Icon(Icons.shopping_cart_rounded),
          label: 'السلة',
        ),
        const NavigationDestination(
          icon: Icon(Icons.store_outlined),
          selectedIcon: Icon(Icons.store_rounded),
          label: 'التجار',
        ),
        const NavigationDestination(
          icon: Icon(Icons.account_balance_wallet_outlined),
          selectedIcon: Icon(Icons.account_balance_wallet_rounded),
          label: 'محفظتي',
        ),
      ],
    );
  }
}
