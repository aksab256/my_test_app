// lib/screens/consumer/consumer_widgets.dart

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'consumer_data_models.dart';
import 'package:my_test_app/screens/consumer/consumer_store_search_screen.dart';
import 'package:my_test_app/screens/consumer/points_loyalty_screen.dart';

// 1. العنوان (تم إضافة const للمشد)
class ConsumerSectionTitle extends StatelessWidget {
  final String title;
  const ConsumerSectionTitle({super.key, required this.title}); // ✅ تم إضافة const هنا

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 28,
            decoration: BoxDecoration(color: const Color(0xFF43A047), borderRadius: BorderRadius.circular(10)),
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87)
          ),
        ],
      ),
    );
  }
}

// 2. شريط التنقل السفلي (تم إضافة const للمشد)
class ConsumerFooterNav extends StatelessWidget {
  final int cartCount;
  final int activeIndex;
  
  const ConsumerFooterNav({ // ✅ تم إضافة const هنا
    super.key, 
    required this.cartCount, 
    required this.activeIndex
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -2))],
      ),
      child: SafeArea(
        child: SizedBox(
          height: 70,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(context, Icons.storefront_rounded, 'المتجر', 0, '/consumerhome'),
              _buildNavItem(context, Icons.assignment_outlined, 'طلباتي', 1, '/consumer-purchases'),
              _buildNavItem(context, Icons.shopping_cart_outlined, 'السلة', 2, '/cart', count: cartCount),
              _buildNavItem(context, Icons.person_outline_rounded, 'حسابي', 3, '/myDetails'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(BuildContext context, IconData icon, String label, int index, String route, {int count = 0}) {
    final bool isActive = activeIndex == index;
    final color = isActive ? const Color(0xFF43A047) : Colors.grey;

    return InkWell(
      onTap: () => isActive ? null : Navigator.of(context).pushNamed(route),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(icon, color: color, size: 30),
              if (count > 0)
                Positioned(
                  right: -5,
                  top: -5,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                    child: Text('$count', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                )
            ],
          ),
          Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: isActive ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
  }
}

// 3. بانر الأقسام (تأكد من هذا الاسم تحديداً)
class ConsumerCategoriesBanner extends StatelessWidget {
  final List<ConsumerCategory> categories;
  const ConsumerCategoriesBanner({super.key, required this.categories});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 140,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        padding: const EdgeInsets.symmetric(horizontal: 15),
        itemBuilder: (context, index) {
          final category = categories[index];
          return Container(
            width: 100,
            margin: const EdgeInsets.symmetric(horizontal: 5),
            child: Column(
              children: [
                Container(
                  width: 85,
                  height: 85,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 3))],
                  ),
                  child: ClipOval(
                    child: CachedNetworkImage(
                      imageUrl: category.imageUrl,
                      fit: BoxFit.cover,
                      errorWidget: (context, url, error) => const Icon(Icons.category),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(category.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), textAlign: TextAlign.center),
              ],
            ),
          );
        },
      ),
    );
  }
}

// 4. بانر العروض
class ConsumerPromoBanners extends StatelessWidget {
  final List<ConsumerBanner> banners;
  final double height;
  const ConsumerPromoBanners({super.key, required this.banners, this.height = 220});

  @override
  Widget build(BuildContext context) {
    if (banners.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: height,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: banners.length,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemBuilder: (context, index) {
          final banner = banners[index];
          return Container(
            width: MediaQuery.of(context).size.width * 0.85,
            margin: const EdgeInsets.only(left: 15, bottom: 15),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: CachedNetworkImage(imageUrl: banner.imageUrl, fit: BoxFit.cover),
            ),
          );
        },
      ),
    );
  }
}

// 5. الـ AppBar والـ SideMenu (كما في الكود السابق مع التأكد من الـ const)
class ConsumerCustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String userName;
  final int userPoints;
  final VoidCallback onMenuPressed;

  const ConsumerCustomAppBar({
    super.key,
    required this.userName,
    required this.userPoints,
    required this.onMenuPressed,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      automaticallyImplyLeading: false,
      backgroundColor: const Color(0xFF43A047),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              IconButton(icon: const Icon(Icons.menu, color: Colors.white, size: 30), onPressed: onMenuPressed),
              Text(userName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ],
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.orange, borderRadius: BorderRadius.circular(10)),
            child: Text('$userPoints نقطة', style: const TextStyle(fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(65);
}

class ConsumerSideMenu extends StatelessWidget {
  const ConsumerSideMenu({super.key});
  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        children: [
          const DrawerHeader(decoration: BoxDecoration(color: Color(0xFF43A047)), child: Icon(Icons.person, size: 50, color: Colors.white)),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('خروج'),
            onTap: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.clear();
              await FirebaseAuth.instance.signOut();
              Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
            },
          ),
        ],
      ),
    );
  }
}

// إضافة الـ SearchBar لضمان عدم وجود نقص
class ConsumerSearchBar extends StatelessWidget {
  const ConsumerSearchBar({super.key});
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.pushNamed(context, ConsumerStoreSearchScreen.routeName),
      child: Container(
        margin: const EdgeInsets.all(20),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 5)]),
        child: const Row(children: [Icon(Icons.radar, color: Color(0xFF43A047)), SizedBox(width: 10), Text('رادار المحلات القريبة')]),
      ),
    );
  }
}
