// lib/screens/consumer/consumer_widgets.dart
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:my_test_app/theme/app_theme.dart';
import 'consumer_data_models.dart';
import 'package:my_test_app/screens/consumer/consumer_store_search_screen.dart';
import 'package:my_test_app/screens/consumer/points_loyalty_screen.dart';
import 'dart:math';

// 1. شريط التنقل العلوي (نفس المنطق مع تحسين الظلال)
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
    final Color appPrimary = AppTheme.primaryGreen;
    final user = FirebaseAuth.instance.currentUser;

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('consumers')
          .doc(user?.uid)
          .snapshots(),
      builder: (context, snapshot) {
        String displayUserName = userName;
        int displayPoints = userPoints;

        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>;
          displayUserName = data['fullname'] ?? data['fullName'] ?? data['name'] ?? userName;
          int p1 = data['points'] is int ? data['points'] : 0;
          int p2 = data['loyaltyPoints'] is int ? data['loyaltyPoints'] : 0;
          displayPoints = max(p1, p2);
        }

        return AppBar(
          automaticallyImplyLeading: false,
          titleSpacing: 0,
          elevation: 0,
          backgroundColor: Theme.of(context).colorScheme.surface,
          title: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    InkWell(
                      onTap: () => Scaffold.of(context).openDrawer(),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: appPrimary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(FontAwesomeIcons.bars, size: 18, color: appPrimary),
                      ),
                    ),
                    const SizedBox(width: 15),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('مرحباً بك،', style: TextStyle(fontSize: 10, color: Color(0xFF6C757D))),
                        Text(displayUserName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: () => Navigator.of(context).pushNamed(PointsLoyaltyScreen.routeName),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFC107),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4)],
                    ),
                    child: Row(
                      children: [
                        const Icon(FontAwesomeIcons.star, size: 12, color: Colors.black),
                        const SizedBox(width: 5),
                        Text('$displayPoints', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(60);
}

// 2. شريط البحث المبتكر (تصميم عائم 3D)
class ConsumerSearchBar extends StatelessWidget {
  const ConsumerSearchBar({super.key});
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.of(context).pushNamed(ConsumerStoreSearchScreen.routeName),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryGreen.withOpacity(0.15),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primaryGreen,
                borderRadius: BorderRadius.circular(15),
              ),
              child: const Icon(Icons.location_on_rounded, color: Colors.white, size: 26),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('البحث عن الأقرب...', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text('سوبر ماركت، مطعم، صيدلية', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                ],
              ),
            ),
            const Icon(Icons.tune_rounded, color: Colors.grey, size: 20),
            const SizedBox(width: 10),
          ],
        ),
      ),
    );
  }
}

// 3. عنوان القسم
class ConsumerSectionTitle extends StatelessWidget {
  final String title;
  const ConsumerSectionTitle({super.key, required this.title});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      child: Row(
        children: [
          Container(
            width: 5, height: 22,
            decoration: BoxDecoration(color: AppTheme.primaryGreen, borderRadius: BorderRadius.circular(10)),
            margin: const EdgeInsets.only(left: 10),
          ),
          Text(title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

// 4. بانر الأقسام (تصميم 3D للأيقونات)
class ConsumerCategoriesBanner extends StatelessWidget {
  final List<ConsumerCategory> categories;
  const ConsumerCategoriesBanner({super.key, required this.categories});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 135,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemBuilder: (context, index) {
          final category = categories[index];
          return Padding(
            padding: const EdgeInsets.only(left: 18),
            child: ConsumerCategoryItem(category: category),
          );
        },
      ),
    );
  }
}

class ConsumerCategoryItem extends StatelessWidget {
  final ConsumerCategory category;
  const ConsumerCategoryItem({super.key, required this.category});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).pushNamed('/category', arguments: category.id),
      child: Column(
        children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryGreen.withOpacity(0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 5), // تأثير الارتفاع عن الأرض
                ),
                const BoxShadow(
                  color: Colors.white,
                  offset: Offset(-2, -2),
                  blurRadius: 5,
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(3.0),
              child: ClipOval(
                child: CachedNetworkImage(
                  imageUrl: category.imageUrl,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                  errorWidget: (context, url, error) => Icon(FontAwesomeIcons.shoppingBasket, color: AppTheme.primaryGreen),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(category.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

// 5. بانر العروض (تصميم الـ Hot Deals المبتكر)
class ConsumerPromoBanners extends StatelessWidget {
  final List<ConsumerBanner> banners;
  const ConsumerPromoBanners({super.key, required this.banners});

  @override
  Widget build(BuildContext context) {
    if (banners.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 200,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: banners.length,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemBuilder: (context, index) {
          final banner = banners[index];
          return Container(
            width: MediaQuery.of(context).size.width * 0.8,
            margin: const EdgeInsets.only(left: 15, bottom: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(25),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 12, offset: const Offset(0, 6)),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(25),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(imageUrl: banner.imageUrl, fit: BoxFit.cover),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.center,
                        colors: [Colors.black.withOpacity(0.6), Colors.transparent],
                      ),
                    ),
                  ),
                  Positioned(
                    top: 15, right: 15,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(10)),
                      child: const Text('عرض مميز 🔥', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// 6. شريط التنقل السفلي
class ConsumerFooterNav extends StatelessWidget {
  final int cartCount;
  final int activeIndex;
  const ConsumerFooterNav({super.key, required this.cartCount, required this.activeIndex});

  @override
  Widget build(BuildContext context) {
    final List<_ConsumerNavItem> items = [
      const _ConsumerNavItem(icon: FontAwesomeIcons.store, label: 'المتجر', route: '/consumerHome'),
      const _ConsumerNavItem(icon: FontAwesomeIcons.clipboardList, label: 'الطلبات', route: '/consumer-purchases'),
      const _ConsumerNavItem(icon: FontAwesomeIcons.shoppingCart, label: 'السلة', route: '/cart'),
      const _ConsumerNavItem(icon: FontAwesomeIcons.user, label: 'حسابي', route: '/myDetails'),
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, -5))],
      ),
      child: SafeArea(
        child: SizedBox(
          height: 65,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(items.length, (index) {
              final item = items[index];
              final isActive = index == activeIndex;
              return Expanded(
                child: ConsumerFooterNavItem(
                  item: item, isActive: isActive, cartCount: index == 2 ? cartCount : 0,
                  onTap: () { if (!isActive) Navigator.of(context).pushNamed(item.route); },
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class ConsumerFooterNavItem extends StatelessWidget {
  final _ConsumerNavItem item;
  final bool isActive;
  final int cartCount;
  final VoidCallback onTap;

  const ConsumerFooterNavItem({super.key, required this.item, required this.isActive, required this.cartCount, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = isActive ? AppTheme.primaryGreen : Colors.grey;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(item.icon, size: 20, color: color),
              if (cartCount > 0)
                Positioned(
                  right: -8, top: -5,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                    constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                    child: Text('$cartCount', style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                  ),
                )
            ],
          ),
          const SizedBox(height: 5),
          Text(item.label, style: TextStyle(fontSize: 10, fontWeight: isActive ? FontWeight.bold : FontWeight.normal, color: color)),
        ],
      ),
    );
  }
}

class _ConsumerNavItem {
  final IconData icon; final String label; final String route;
  const _ConsumerNavItem({required this.icon, required this.label, required this.route});
}

// 7. القائمة الجانبية
class ConsumerSideMenu extends StatelessWidget {
  const ConsumerSideMenu({super.key});

  @override
  Widget build(BuildContext context) {
    final Color appPrimary = AppTheme.primaryGreen;
    return Drawer(
      width: 280,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 60, 20, 30),
            color: appPrimary.withOpacity(0.05),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('إعداداتي', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: appPrimary)),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(15),
              children: [
                const _ConsumerSidebarItem(icon: FontAwesomeIcons.home, label: 'الرئيسية', route: '/consumerHome'),
                const _ConsumerSidebarItem(icon: FontAwesomeIcons.history, label: 'سجل الطلبات', route: '/consumer-purchases'),
                const _ConsumerSidebarItem(icon: FontAwesomeIcons.gift, label: 'نقاطي ومكافآتي', route: PointsLoyaltyScreen.routeName),
                const _ConsumerSidebarItem(icon: FontAwesomeIcons.userCircle, label: 'الملف الشخصي', route: '/myDetails'),
              ],
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: _ConsumerSidebarItem(
                icon: FontAwesomeIcons.signOutAlt,
                label: 'تسجيل الخروج',
                isLogout: true,
                onTap: () {
                  FirebaseAuth.instance.signOut();
                  Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConsumerSidebarItem extends StatelessWidget {
  final IconData icon; final String label; final bool isLogout; final String route; final VoidCallback? onTap;
  const _ConsumerSidebarItem({required this.icon, required this.label, this.isLogout = false, this.route = '', this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = isLogout ? Colors.red : Colors.black87;
    return ListTile(
      leading: Icon(icon, size: 20, color: isLogout ? Colors.red : AppTheme.primaryGreen),
      title: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
      onTap: onTap ?? () { Navigator.pop(context); Navigator.pushNamed(context, route); },
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }
}
