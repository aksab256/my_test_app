// lib/widgets/buyer_mobile_nav_widget.dart
import 'package:flutter/material.dart';

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

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      height: 65,
      // لضمان ظهور النص أسفل الأيقونة دائماً
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      selectedIndex: selectedIndex,
      onDestinationSelected: onItemSelected,
      backgroundColor: Colors.white,
      elevation: 8,
      indicatorColor: const Color(0xFF4CAF50).withOpacity(0.15),
      destinations: [
        // Index 0: التجار
        const NavigationDestination(
          icon: Icon(Icons.storefront_outlined, color: Colors.grey),
          selectedIcon: Icon(Icons.storefront_rounded, color: Color(0xFF4CAF50)),
          label: 'التجار',
        ),
        // Index 1: الرئيسية
        const NavigationDestination(
          icon: Icon(Icons.home_outlined, color: Colors.grey),
          selectedIcon: Icon(Icons.home_rounded, color: Color(0xFF4CAF50)),
          label: 'الرئيسية',
        ),
        // Index 2: طلباتي (مع إشعار التغيير)
        NavigationDestination(
          icon: Badge(
            isLabelVisible: ordersChanged,
            child: const Icon(Icons.assignment_outlined, color: Colors.grey),
          ),
          selectedIcon: const Icon(Icons.assignment_rounded, color: Color(0xFF4CAF50)),
          label: 'طلباتي',
        ),
        // Index 3: المحفظة
        const NavigationDestination(
          icon: Icon(Icons.account_balance_wallet_outlined, color: Colors.grey),
          selectedIcon: Icon(Icons.account_balance_wallet_rounded, color: Color(0xFF4CAF50)),
          label: 'المحفظة',
        ),
      ],
    );
  }
}
