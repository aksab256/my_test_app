import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:my_test_app/theme/app_theme.dart';
import 'consumer_data_models.dart';
import 'package:my_test_app/screens/consumer/consumer_store_search_screen.dart';
import 'package:my_test_app/screens/consumer/points_loyalty_screen.dart';

// 1. شريط التنقل العلوي - لون أخضر فاتح وأيقونة منيو صريحة
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
    final user = FirebaseAuth.instance.currentUser;

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('consumers').doc(user?.uid).snapshots(),
      builder: (context, snapshot) {
        String displayUserName = userName;
        int displayPoints = userPoints;

        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>;
          displayUserName = data['fullname'] ?? data['fullName'] ?? userName;
          displayPoints = data['points'] ?? data['loyaltyPoints'] ?? 0;
        }

        return AppBar(
          automaticallyImplyLeading: false,
          elevation: 2,
          backgroundColor: const Color(0xFF43A047), // الأخضر الفاتح المريح
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.menu, color: Colors.white, size: 32), // أيقونة المنيو التقليدية
                    onPressed: onMenuPressed,
                  ),
                  const SizedBox(width: 5),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('مرحباً بك،', style: TextStyle(fontSize: 12, color: Colors.white70)),
                      Text(
                        displayUserName,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)
                      ),
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
                    boxShadow: [const BoxShadow(color: Colors.black26, blurRadius: 4)],
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.stars, size: 18, color: Colors.black87),
                      const SizedBox(width: 4),
                      Text(
                        '$displayPoints',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87)
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(70);
}

// 2. زر الرادار
class ConsumerSearchBar extends StatelessWidget {
  const ConsumerSearchBar({super.key});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.of(context).pushNamed(ConsumerStoreSearchScreen.routeName),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 15, offset: const Offset(0, 5)),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: const Color(0xFF43A047).withOpacity(0.1), shape: BoxShape.circle),
              child: const Icon(Icons.radar_rounded, color: Color(0xFF43A047), size: 32),
            ),
            const SizedBox(width: 15),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'اكتشف ما يدور حولك الآن',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black)
                  ),
                  Text(
                    'رادار الخدمات في محيط 5 كم',
                    style: TextStyle(fontSize: 13, color: Colors.grey)
                  ),
                ],
              ),
            ),
            const Icon(Icons.location_on, color: Color(0xFF43A047), size: 24),
          ],
        ),
      ),
    );
  }
}

// 3. عنوان القسم - تم حذف "عرض الكل" بناءً على طلبك
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
            width: 5,
            height: 24,
            decoration: BoxDecoration(
              color: const Color(0xFF43A047), 
              borderRadius: BorderRadius.circular(10)
            ),
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)
          ),
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
      height: 130,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        padding: const EdgeInsets.symmetric(horizontal: 15),
        physics: const BouncingScrollPhysics(),
        itemBuilder: (context, index) {
          final category = categories[index];
          return Container(
            width: 90,
            margin: const EdgeInsets.symmetric(horizontal: 5),
            child: Column(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    boxShadow: [const BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 3))],
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: ClipOval(
                    child: CachedNetworkImage(
                      imageUrl: category.imageUrl,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                      errorWidget: (context, url, error) => const Icon(Icons.category, color: Colors.grey),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  category.name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// 5. بانر العروض
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
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              boxShadow: [const BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 5))],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(imageUrl: banner.imageUrl, fit: BoxFit.cover),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [Colors.black.withOpacity(0.5), Colors.transparent],
                      ),
                    ),
                  ),
                  Positioned(
                    top: 15,
                    right: 15,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(10)),
                      child: const Text('عرض مميز 🔥', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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

// 6. شريط التنقل السفلي - مدمج مع SafeArea لمنع تداخله مع أزرار الموبايل
class ConsumerFooterNav extends StatelessWidget {
  final int cartCount;
  final int activeIndex;
  const ConsumerFooterNav({super.key, required this.cartCount, required this.activeIndex});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: const Offset(0, -2))],
      ),
      child: SafeArea(
        child: SizedBox(
          height: 65, // ارتفاع متوازن
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(context, Icons.storefront_rounded, 'المتجر', 0, '/consumerHome'),
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
              Icon(icon, color: color, size: 28),
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
          Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: isActive ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
  }
}

// 7. القائمة الجانبية المحدثة
class ConsumerSideMenu extends StatelessWidget {
  const ConsumerSideMenu({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(color: Color(0xFF43A047)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircleAvatar(
                  radius: 30, 
                  backgroundColor: Colors.white, 
                  child: Icon(Icons.person, size: 40, color: Color(0xFF43A047))
                ),
                const SizedBox(height: 10),
                Text(user?.email ?? 'المستخدم', style: const TextStyle(color: Colors.white, fontSize: 14)),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.home_outlined),
            title: const Text('الرئيسية'),
            onTap: () => Navigator.pop(context),
          ),
          ListTile(
            leading: const Icon(Icons.shopping_bag_outlined),
            title: const Text('طلباتي'),
            onTap: () => Navigator.pushNamed(context, '/consumer-purchases'),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('تسجيل الخروج', style: TextStyle(color: Colors.red)),
            onTap: () {
              FirebaseAuth.instance.signOut();
              Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
            },
          ),
        ],
      ),
    );
  }
}
