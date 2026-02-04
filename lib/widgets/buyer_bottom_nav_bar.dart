// المسار: lib/widgets/buyer_bottom_nav_bar.dart

import 'package:flutter/material.dart';
import 'package:my_test_app/screens/buyer/buyer_home_screen.dart'; // تأكد من الاستيراد
import 'package:my_test_app/screens/buyer/my_orders_screen.dart';   // تأكد من الاستيراد

class BuyerBottomNavBar extends StatelessWidget {
  final int currentIndex; // أضفنا هذا لاستقبال الصفحة الحالية
  const BuyerBottomNavBar({super.key, this.currentIndex = 0});

  void _onItemTapped(BuildContext context, int index) {
    if (index == currentIndex) return;

    String routeName;
    switch (index) {
      case 0:
        // نستخدم الـ routeName المعرف في الـ main.dart
        routeName = BuyerHomeScreen.routeName; 
        break;
      case 1:
        routeName = MyOrdersScreen.routeName;
        break;
      case 2:
        routeName = '/myDetails'; // حسب الـ main.dart عندك
        break;
      default:
        return;
    }
    
    // التنقل الذكي: نذهب للمسار ونمسح ما قبله لضمان عدم تراكم الشاشات
    Navigator.of(context).pushNamedAndRemoveUntil(
      routeName,
      (Route<dynamic> route) => route.isFirst,
    );
  }

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      items: const <BottomNavigationBarItem>[
        BottomNavigationBarItem(
          icon: Icon(Icons.home_outlined),
          activeIcon: Icon(Icons.home),
          label: 'الرئيسية',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.list_alt_outlined),
          activeIcon: Icon(Icons.list_alt),
          label: 'طلباتي',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person_outline),
          activeIcon: Icon(Icons.person),
          label: 'حسابي',
        ),
      ],
      currentIndex: currentIndex,
      selectedItemColor: const Color(0xFF43A047), // اللون الأخضر الموحد لبراند أكسب
      unselectedItemColor: Colors.grey,
      onTap: (index) => _onItemTapped(context, index),
      backgroundColor: Colors.white,
      elevation: 15,
      type: BottomNavigationBarType.fixed,
    );
  }
}
