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
import 'dart:math'; // مهم جداً لدالة max

// 1. شريط التنقل العلوي المخصص (Top Bar)
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
          
          // جلب الاسم: الأولوية لـ fullname الجديد ثم القديم
          displayUserName = data['fullname'] ?? data['fullName'] ?? data['name'] ?? userName;
          
          // 🎯 منطق النقاط: اختيار القيمة الأكبر بين points و loyaltyPoints
          int p1 = data['points'] is int ? data['points'] : 0;
          int p2 = data['loyaltyPoints'] is int ? data['loyaltyPoints'] : 0;
          displayPoints = max(p1, p2);
        }

        return AppBar(
          automaticallyImplyLeading: false,
          titleSpacing: 0,
          elevation: 0,
          backgroundColor: Theme.of(context).colorScheme.surface,
          shape: Border(bottom: BorderSide(color: Colors.grey.withOpacity(0.1), width: 1)),
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
                        const Text('مرحباً بك،',
                            style: TextStyle(fontSize: 10, color: Color(0xFF6C757D))),
                        Text(displayUserName,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
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
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4),
                      ],
                    ),
                    child: Row(
                      children: [
                        const Icon(FontAwesomeIcons.star, size: 12, color: Colors.black),
                        const SizedBox(width: 5),
                        Text('$displayPoints',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black)),
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

// 2. شريط البحث
class ConsumerSearchBar extends StatelessWidget {
  const ConsumerSearchBar({super.key});
  @override
  Widget build(BuildContext context) {
    return InkWell(
        onTap: () => Navigator.of(context).pushNamed(ConsumerStoreSearchScreen.routeName),
        child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.grey.withOpacity(0.2)),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 15, offset: const Offset(0, 5)),
          ],
        ),
        child: Row(
          children: [
            Icon(Icons.location_on_rounded, size: 28, color: AppTheme.primaryGreen),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('البحث عن الأقرب...',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text('سوبر ماركت، مطعم، صيدلية',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey),
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
      padding: const EdgeInsets.fromLTRB(20, 15, 20, 10),
      child: Row(
        children: [
          Container(
            width: 4, height: 20,
            decoration: BoxDecoration(color: AppTheme.primaryGreen, borderRadius: BorderRadius.circular(2)),
            margin: const EdgeInsets.only(left: 10),
          ),
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

// 4. بانر الأقسام
class ConsumerCategoriesBanner extends StatelessWidget {
  final List<ConsumerCategory> categories;
  const ConsumerCategoriesBanner({super.key, required this.categories});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 125,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemBuilder: (context, index) {
          final category = categories[index];
          return Padding(
            padding: const EdgeInsets.only(left: 15),
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
      child: SizedBox(
        width: 80,
        child: Column(
          children: [
            Container(
              width: 75, height: 75,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                border: Border.all(color: AppTheme.primaryGreen.withOpacity(0.5), width: 2),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5, offset: const Offset(0, 2))],
              ),
              child: ClipOval(
                child: CachedNetworkImage(
                  imageUrl: category.imageUrl, fit: BoxFit.cover,
                  placeholder: (context, url) => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                  errorWidget: (context, url, error) => Icon(FontAwesomeIcons.shoppingBasket, color: AppTheme.primaryGreen),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(category.name, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

// 5. بانر العروض
class ConsumerPromoBanners extends StatelessWidget {
  final List<ConsumerBanner> banners;
  const ConsumerPromoBanners({super.key, required this.banners});
  @override
  Widget build(BuildContext context) {
    if (banners.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: SizedBox(
        height: 180,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: banners.length,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemBuilder: (context, index) {
            final banner = banners[index];
            return Padding(
              padding: const EdgeInsets.only(left: 15),
              child: Container(
                width: MediaQuery.of(context).size.width * 0.85,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: CachedNetworkImage(imageUrl: banner.imageUrl, fit: BoxFit.cover,
                    placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
                  ),
                ),
              ),
            );
          },
        ),
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
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))],
      ),
      child: SafeArea(
        child: Container(
          height: 60,
          decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.grey.withOpacity(0.1)))),
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
    final color = isActive ? AppTheme.primaryGreen : AppTheme.secondaryTextColor;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(item.icon, size: 22, color: color),
              if (cartCount > 0)
                Positioned(
                  right: -8, top: -5,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(color: Color(0xFFdc3545), shape: BoxShape.circle),
                    constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                    child: Text('$cartCount', style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                  ),
                )
            ],
          ),
          const SizedBox(height: 4),
          Text(item.label, style: TextStyle(fontSize: 11, fontWeight: isActive ? FontWeight.bold : FontWeight.normal, color: color)),
        ],
      ),
    );
  }
}

class _ConsumerNavItem {
  final IconData icon; final String label; final String route;
  const _ConsumerNavItem({required this.icon, required this.label, required this.route});
}

// 7. القائمة الجانبية (Sidebar)
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
            padding: const EdgeInsets.fromLTRB(20, 50, 20, 20),
            color: appPrimary.withOpacity(0.05),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('القائمة', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: appPrimary)),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(15),
              children: [
                const _ConsumerSidebarItem(icon: FontAwesomeIcons.home, label: 'الرئيسية', route: '/consumerHome'),
                const _ConsumerSidebarItem(icon: FontAwesomeIcons.history, label: 'طلباتي', route: '/consumer-purchases'),
                const _ConsumerSidebarItem(icon: FontAwesomeIcons.gift, label: 'النقاط', route: PointsLoyaltyScreen.routeName),
                const _ConsumerSidebarItem(icon: FontAwesomeIcons.userCircle, label: 'حسابي', route: '/myDetails'),
              ],
            ),
          ),
          // 🛡️ استخدام SafeArea لرفع زر تسجيل الخروج فوق أزرار أندرويد
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    );
  }
}
