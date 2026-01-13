import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'consumer_data_models.dart';
import 'package:my_test_app/screens/consumer/consumer_store_search_screen.dart';
import 'package:my_test_app/screens/consumer/points_loyalty_screen.dart';

// 1. AppBar - العودة للأصل مع تكبير الخطوط فقط
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
          backgroundColor: const Color(0xFF43A047),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.menu, color: Colors.white, size: 32),
                    onPressed: onMenuPressed,
                  ),
                  const SizedBox(width: 5),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('مرحباً بك،', style: TextStyle(fontSize: 14, color: Colors.white70)),
                      Text(
                        displayUserName,
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)
                      ),
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
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.stars, size: 20, color: Colors.black87),
                      const SizedBox(width: 5),
                      Text('$displayPoints', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
  Size get preferredSize => const Size.fromHeight(75);
}

// 2. البانر - تأكد من مطابقة الاسم لما هو موجود في consumer_home_screen.dart
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
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(20)),
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

// 3. القائمة الجانبية - المحافظة على الأصل مع إضافة روابط الخصوصية
class ConsumerSideMenu extends StatelessWidget {
  const ConsumerSideMenu({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        children: [
          const DrawerHeader(
            decoration: BoxDecoration(color: Color(0xFF43A047)),
            child: Center(child: Icon(Icons.person, size: 60, color: Colors.white)),
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip),
            title: const Text('سياسة الخصوصية', style: TextStyle(fontSize: 18)),
            onTap: () async {
              final url = Uri.parse('https://amrshipl83.github.io/aksabprivce/');
              if (await canLaunchUrl(url)) await launchUrl(url);
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('تسجيل الخروج', style: TextStyle(color: Colors.red, fontSize: 18)),
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

// أضف بقية الكلاسات (ConsumerSearchBar, ConsumerSectionTitle, ConsumerCategoriesBanner, ConsumerFooterNav)
// من الكود الأول الذي أرسلته لك "بدون تعديل مسميات" لضمان نجاح الـ Build.
