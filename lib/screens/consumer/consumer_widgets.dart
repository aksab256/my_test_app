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
import 'package:sizer/sizer.dart';

// 1. شريط التنقل العلوي (شفاف ليتناسب مع الخلفية الخضراء الجديدة)
class ConsumerCustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String userName;
  final int userPoints;
  final VoidCallback onMenuPressed;
  final bool isLight; // إضافة لدعم النص الأبيض فوق الأخضر

  const ConsumerCustomAppBar({
    super.key,
    required this.userName,
    required this.userPoints,
    required this.onMenuPressed,
    this.isLight = false,
  });

  @override
  Widget build(BuildContext context) {
    final Color textColor = isLight ? Colors.white : Colors.black87;
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
          elevation: 0,
          backgroundColor: Colors.transparent, // شفاف للاندماج مع التدرج
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  InkWell(
                    onTap: onMenuPressed,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isLight ? Colors.white24 : Colors.black.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(FontAwesomeIcons.barsStaggered, size: 20, color: textColor),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('مرحباً بك،', style: TextStyle(fontSize: 9.sp, color: isLight ? Colors.white70 : Colors.grey)),
                      Text(displayUserName, style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w900, color: textColor)),
                    ],
                  ),
                ],
              ),
              GestureDetector(
                onTap: () => Navigator.of(context).pushNamed(PointsLoyaltyScreen.routeName),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFC107),
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8)],
                  ),
                  child: Row(
                    children: [
                      const Icon(FontAwesomeIcons.solidStar, size: 14, color: Colors.black87),
                      const SizedBox(width: 6),
                      Text('$displayPoints', style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.bold, color: Colors.black87)),
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

// 2. شريط البحث المبتكر (تحويله إلى رادار تفاعلي)
class ConsumerSearchBar extends StatelessWidget {
  const ConsumerSearchBar({super.key});
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.of(context).pushNamed(ConsumerStoreSearchScreen.routeName),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 25, offset: const Offset(0, 10)),
          ],
        ),
        child: Row(
          children: [
            // أيقونة الرادار مع تأثير خلفية دائرية
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 45, height: 45,
                  decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), shape: BoxShape.circle),
                ),
                const Icon(Icons.radar_rounded, color: Colors.green, size: 28),
              ],
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('اكتشف ما يدور حولك الآن', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12.sp)),
                  Text('رادار الخدمات في محيط 5 كيلو متر', style: TextStyle(fontSize: 9.sp, color: Colors.grey[500])),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, color: Colors.grey, size: 16),
          ],
        ),
      ),
    );
  }
}

// 3. عنوان القسم (بتصميم أكثر بروزاً)
class ConsumerSectionTitle extends StatelessWidget {
  final String title;
  final Color? color;
  const ConsumerSectionTitle({super.key, required this.title, this.color});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 25, 20, 15),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 4, height: 18,
                decoration: BoxDecoration(color: AppTheme.primaryGreen, borderRadius: BorderRadius.circular(10)),
              ),
              const SizedBox(width: 10),
              Text(title, style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w900, color: color ?? Colors.black87)),
            ],
          ),
          Text('عرض الكل', style: TextStyle(color: AppTheme.primaryGreen, fontSize: 9.sp, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

// 4. بانر الأقسام (تصميم دائري مع ظل ناعم وارتفاع أكبر)
class ConsumerCategoriesBanner extends StatelessWidget {
  final List<ConsumerCategory> categories;
  const ConsumerCategoriesBanner({super.key, required this.categories});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 150, // زيادة الارتفاع لراحة بصرية أكبر
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        padding: const EdgeInsets.symmetric(horizontal: 15),
        physics: const BouncingScrollPhysics(),
        itemBuilder: (context, index) {
          final category = categories[index];
          return Container(
            width: 90,
            margin: const EdgeInsets.symmetric(horizontal: 8),
            child: Column(
              children: [
                Container(
                  width: 75, height: 75,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
                    ],
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: ClipOval(
                    child: CachedNetworkImage(
                      imageUrl: category.imageUrl,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => const Center(child: CircularProgressIndicator(strokeWidth: 1)),
                      errorWidget: (context, url, error) => const Icon(Icons.category, color: Colors.grey),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  category.name,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  style: TextStyle(fontSize: 9.sp, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// 5. بانر العروض (تصميم ممتد لملء الفراغ السفلي)
class ConsumerPromoBanners extends StatelessWidget {
  final List<ConsumerBanner> banners;
  final double? height;
  const ConsumerPromoBanners({super.key, required this.banners, this.height});

  @override
  Widget build(BuildContext context) {
    if (banners.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: height ?? 220, // استخدام الارتفاع الممرر لملء الشاشة
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: banners.length,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemBuilder: (context, index) {
          final banner = banners[index];
          return Container(
            width: 85.w,
            margin: const EdgeInsets.only(left: 15, bottom: 20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(25),
              boxShadow: [
                BoxShadow(color: Colors.black12, blurRadius: 15, offset: const Offset(0, 8)),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(25),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(imageUrl: banner.imageUrl, fit: BoxFit.cover),
                  // تدرج لوني لجعل النص والعروض تبرز
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [Colors.black.withOpacity(0.4), Colors.transparent],
                      ),
                    ),
                  ),
                  Positioned(
                    top: 15, right: 15,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.redAccent,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 5)],
                      ),
                      child: Text('عرض حصري 🔥', style: TextStyle(color: Colors.white, fontSize: 8.sp, fontWeight: FontWeight.bold)),
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

// 6. شريط التنقل السفلي (أكثر أناقة)
class ConsumerFooterNav extends StatelessWidget {
  final int cartCount;
  final int activeIndex;
  const ConsumerFooterNav({super.key, required this.cartCount, required this.activeIndex});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, -5))],
      ),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _navItem(context, FontAwesomeIcons.shop, 'المتجر', 0, '/consumerHome'),
            _navItem(context, FontAwesomeIcons.rectangleList, 'طلباتي', 1, '/consumer-purchases'),
            _navItem(context, FontAwesomeIcons.basketShopping, 'السلة', 2, '/cart', count: cartCount),
            _navItem(context, FontAwesomeIcons.circleUser, 'حسابي', 3, '/myDetails'),
          ],
        ),
      ),
    );
  }

  Widget _navItem(BuildContext context, IconData icon, String label, int index, String route, {int count = 0}) {
    final bool isActive = activeIndex == index;
    final color = isActive ? AppTheme.primaryGreen : Colors.grey[400];

    return GestureDetector(
      onTap: () => isActive ? null : Navigator.of(context).pushNamed(route),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(icon, size: 20, color: color),
              if (count > 0)
                Positioned(
                  right: -8, top: -5,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                    child: Text('$count', style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
                  ),
                )
            ],
          ),
          const SizedBox(height: 5),
          Text(label, style: TextStyle(fontSize: 8.sp, fontWeight: isActive ? FontWeight.bold : FontWeight.normal, color: color)),
        ],
      ),
    );
  }
}

// ... كود الـ ConsumerSideMenu يظل كما هو مع تحديث الألوان للتماشي مع الثيم الأخضر الجديد ...
class ConsumerSideMenu extends StatelessWidget {
  const ConsumerSideMenu({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.horizontal(left: Radius.circular(30))),
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            decoration: BoxDecoration(color: AppTheme.primaryGreen.withOpacity(0.1)),
            currentAccountPicture: const CircleAvatar(backgroundColor: Colors.white, child: Icon(Icons.person, size: 40, color: Colors.green)),
            accountName: const Text('أهلاً بك', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
            accountEmail: Text(FirebaseAuth.instance.currentUser?.email ?? '', style: const TextStyle(color: Colors.black54)),
          ),
          // بقية عناصر القائمة...
        ],
      ),
    );
  }
}
