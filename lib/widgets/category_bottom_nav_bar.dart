// lib/widgets/category_bottom_nav_bar.dart

import 'package:flutter/material.dart';

import 'package:my_test_app/screens/buyer/buyer_home_screen.dart';
import 'package:my_test_app/screens/buyer/traders_screen.dart';
import 'package:my_test_app/screens/buyer/my_orders_screen.dart';
import 'package:my_test_app/screens/search/search_screen.dart';

class CategoryBottomNavBar extends StatelessWidget {
  // ✅ أضفنا هذا المتغير لاستقبال رقم الصفحة الحالية
  final int selectedIndex;
  
  // ✅ جعلنا القيمة الافتراضية 0 لضمان عدم حدوث خطأ في الصفحات القديمة
  const CategoryBottomNavBar({super.key, this.selectedIndex = 0});

  void _handleNavigation(BuildContext context, int index) {
    // 💡 منع إعادة تحميل نفس الصفحة إذا ضغط المستخدم على أيقونة الصفحة التي يتواجد فيها بالفعل
    if (index == selectedIndex) return;

    String routeName = '';
    
    if (index == 0) {
       routeName = BuyerHomeScreen.routeName;
       Navigator.of(context).pushNamedAndRemoveUntil(routeName, (Route<dynamic> route) => false);
       return;
    } else if (index == 1) { 
      routeName = TradersScreen.routeName;
    } else if (index == 2) { 
      routeName = MyOrdersScreen.routeName;
    } else if (index == 3) { 
      routeName = SearchScreen.routeName;
    } else if (index == 4) {
      routeName = '/wallet';
    }
    
    if (routeName.isNotEmpty) {
       // ✅ استبدال الصفحة الحالية بالجديدة لمنع تراكم الصفحات في الـ Stack بشكل مفرط
       Navigator.of(context).pushReplacementNamed(routeName);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      currentIndex: selectedIndex, // ✅ الآن يستخدم الرقم الممرر له (مثلاً 3 للبحث)
      selectedItemColor: const Color(0xFF4CAF50), 
      unselectedItemColor: Colors.grey.shade600,
      
      onTap: (index) => _handleNavigation(context, index),
      
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'الرئيسية'),
        BottomNavigationBarItem(icon: Icon(Icons.store_rounded), label: 'التجار'),
        BottomNavigationBarItem(icon: Icon(Icons.shopping_bag_rounded), label: 'مشترياتي'),
        BottomNavigationBarItem(icon: Icon(Icons.search_rounded), label: 'بحث'),
        BottomNavigationBarItem(icon: Icon(Icons.account_balance_wallet_rounded), label: 'محفظتي'),
      ],
    );
  }
}

