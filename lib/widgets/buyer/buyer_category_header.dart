// المسار: lib/widgets/buyer_category_header.dart

import 'package:flutter/material.dart';

class BuyerCategoryHeader extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final bool isLoading;

  const BuyerCategoryHeader({
    super.key, 
    required this.title, 
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      // محاكاة الألوان من الـ CSS: header-bg
      backgroundColor: const Color(0xFF2C3E50), 
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          // محاكاة التدرج اللوني: linear-gradient(to right, #2c3e50, #4a6491)
          gradient: LinearGradient(
            colors: [Color(0xFF2C3E50), Color(0xFF4A6491)],
            begin: Alignment.centerRight,
            end: Alignment.centerLeft,
          ),
        ),
      ),
      elevation: 4,
      
      title: Text(
        title,
        style: const TextStyle(
          color: Colors.white, // header-text
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      centerTitle: true,

      // زر العودة: back-btn
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
        onPressed: () {
          // وظيفة العودة للشاشة السابقة
          Navigator.of(context).pop();
        },
      ),
      
      // زر البحث (محاكاة للـ theme-toggle الذي تم إلغاء منطق تخصيص الثيم به)
      actions: [
        IconButton(
          icon: const Icon(Icons.search, color: Colors.white, size: 24),
          onPressed: () {
            // هنا يتم التوجيه إلى شاشة البحث
            // Navigator.of(context).pushNamed('/search');
            print('Search button pressed');
          },
        ),
        const SizedBox(width: 10),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

