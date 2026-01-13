import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'consumer_data_models.dart';
// 🎯 استيراد صفحة الأقسام لربط الضغط
import 'package:my_test_app/screens/consumer/consumer_category_screen.dart'; 

// 1. الشريط الجانبي (Side Menu)
class ConsumerSideMenu extends StatelessWidget {
  const ConsumerSideMenu({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Drawer(
        child: Column(
          children: [
            StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance.collection('consumers').doc(user?.uid).snapshots(),
              builder: (context, snapshot) {
                String name = "مستخدِم كسبان";
                if (snapshot.hasData && snapshot.data!.exists) {
                  final data = snapshot.data!.data() as Map<String, dynamic>;
                  name = data['fullname'] ?? "مستخدِم كسبان";
                }
                return UserAccountsDrawerHeader(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(colors: [Color(0xFF43A047), Color(0xFF2E7D32)]),
                  ),
                  currentAccountPicture: const CircleAvatar(
                    backgroundColor: Colors.white,
                    child: Icon(Icons.person_rounded, size: 50, color: Color(0xFF43A047)),
                  ),
                  accountName: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  accountEmail: Text(user?.email ?? ""),
                );
              },
            ),
            _buildDrawerItem(Icons.history_rounded, 'سجل الطلبات', () => Navigator.pushNamed(context, '/consumer-purchases')),
            _buildDrawerItem(Icons.location_on_outlined, 'عناوين التوصيل', () {}),
            _buildDrawerItem(Icons.privacy_tip_outlined, 'سياسة الخصوصية', () async {
              final url = Uri.parse('https://amrshipl83.github.io/aksabprivce/');
              if (await canLaunchUrl(url)) await launchUrl(url, mode: LaunchMode.externalApplication);
            }),
            const Spacer(),
            const Divider(),
            _buildDrawerItem(Icons.logout_rounded, 'تسجيل الخروج', () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.clear();
              await FirebaseAuth.instance.signOut();
              if (context.mounted) Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
            }, color: Colors.red),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerItem(IconData icon, String title, VoidCallback onTap, {Color color = Colors.black87}) {
    return ListTile(
      leading: Icon(icon, color: color, size: 26),
      title: Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color)),
      onTap: onTap,
    );
  }
}

// 2. شريط التنقل السفلي (Footer Nav) - تم تحديث الأيقونات والمسارات
class ConsumerFooterNav extends StatelessWidget {
  final int cartCount;
  final int activeIndex;
  const ConsumerFooterNav({super.key, required this.cartCount, required this.activeIndex});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, -2))],
      ),
      child: BottomNavigationBar(
        currentIndex: activeIndex,
        selectedItemColor: const Color(0xFF43A047),
        unselectedItemColor: Colors.grey[400],
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        items: [
          const BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: 'الرئيسية'),
          const BottomNavigationBarItem(icon: Icon(Icons.grid_view_rounded), label: 'الأقسام'),
          BottomNavigationBarItem(
            icon: Badge(
              label: Text(cartCount.toString()),
              isLabelVisible: cartCount > 0,
              child: const Icon(Icons.shopping_basket_rounded),
            ),
            label: 'سلتك',
          ),
          const BottomNavigationBarItem(icon: Icon(Icons.receipt_long_rounded), label: 'طلباتي'),
        ],
        onTap: (index) {
          if (index == activeIndex) return;
          final routes = ['/consumerhome', '/all-categories', '/cart', '/consumer-purchases'];
          Navigator.pushNamed(context, routes[index]);
        },
      ),
    );
  }
}

// 3. العناوين (Section Titles)
class ConsumerSectionTitle extends StatelessWidget {
  final String title;
  const ConsumerSectionTitle({super.key, required this.title});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF2D3142))),
          const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
        ],
      ),
    );
  }
}

// 4. بانر الأقسام (Main Categories) - تم ربطه بصفحة الأقسام الجديدة
class ConsumerCategoriesBanner extends StatelessWidget {
  final List<ConsumerCategory> categories;
  const ConsumerCategoriesBanner({super.key, required this.categories});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 120,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final category = categories[index];
          return GestureDetector(
            onTap: () {
              // 🎯 التوجيه لصفحة الأقسام الجديدة للمستهلك
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ConsumerCategoryScreen(
                    mainCategoryId: category.id,
                    categoryName: category.name,
                  ),
                ),
              );
            },
            child: Container(
              width: 85,
              margin: const EdgeInsets.symmetric(horizontal: 5),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF43A047).withOpacity(0.2), width: 2),
                    ),
                    child: CircleAvatar(
                      radius: 32,
                      backgroundColor: Colors.grey[100],
                      backgroundImage: NetworkImage(category.imageUrl),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    category.name,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF455A64)),
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
