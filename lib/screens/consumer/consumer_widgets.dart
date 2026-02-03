// lib/screens/consumer/consumer_widgets.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'consumer_data_models.dart';
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
                  decoration: const BoxDecoration(color: Color(0xFF43A047)),
                  currentAccountPicture: const CircleAvatar(
                    backgroundColor: Colors.white,
                    child: Icon(Icons.person_rounded, size: 50, color: Color(0xFF43A047)),
                  ),
                  accountName: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  accountEmail: Text(user?.email ?? ""),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.privacy_tip_outlined, color: Color(0xFF43A047), size: 28),
              title: const Text('سياسة الخصوصية', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              onTap: () async {
                final url = Uri.parse('https://amrshipl83.github.io/aksabprivce/');
                if (await canLaunchUrl(url)) await launchUrl(url, mode: LaunchMode.externalApplication);
              },
            ),
            const Spacer(),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout_rounded, color: Colors.red, size: 28),
              title: const Text('تسجيل الخروج', style: TextStyle(color: Colors.red, fontSize: 16, fontWeight: FontWeight.bold)),
              onTap: () async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.clear();
                await FirebaseAuth.instance.signOut();
                if (context.mounted) Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

// 2. شريط التنقل السفلي (Footer Nav) - تم إضافة الترتيب لضمان جلب أحدث طلب
class ConsumerFooterNav extends StatelessWidget {
  final int cartCount;
  final int activeIndex;
  const ConsumerFooterNav({super.key, required this.cartCount, required this.activeIndex});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    
    // الحالات التي يظهر فيها زر التتبع مفعلاً
    final List<String> trackingStatuses = ['pending', 'accepted', 'at_pickup', 'picked_up', 'delivered'];

    return BottomNavigationBar(
      currentIndex: activeIndex == -1 ? 0 : activeIndex,
      selectedItemColor: const Color(0xFF43A047),
      unselectedItemColor: Colors.grey,
      type: BottomNavigationBarType.fixed,
      selectedLabelStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
      unselectedLabelStyle: const TextStyle(fontSize: 10),
      items: [
        const BottomNavigationBarItem(icon: Icon(Icons.store), label: 'المتجر'),
        const BottomNavigationBarItem(icon: Icon(Icons.receipt_long), label: 'طلباتي'),
        
        // ✨ أيقونة "تتبع الطلب" الذكية
        BottomNavigationBarItem(
          icon: StreamBuilder<QuerySnapshot>(
            // تم إضافة الترتيب التنازلي هنا لضمان فتح الطلب الصحيح
            stream: FirebaseFirestore.instance
                .collection('specialRequests')
                .where('userId', isEqualTo: user?.uid)
                .where('status', whereIn: trackingStatuses)
                .orderBy('createdAt', descending: true) 
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                // 🛠️ علامة UI: لو ظهرت "!" في الـ Console، يعني محتاج تضغط على رابط الاندكس
                debugPrint("❌ Firebase Error: ${snapshot.error}");
                return const Icon(Icons.radar, color: Colors.grey);
              }

              bool hasActiveOrder = snapshot.hasData && snapshot.data!.docs.isNotEmpty;
              Color iconColor = Colors.grey;
              
              if (hasActiveOrder) {
                final lastStatus = snapshot.data!.docs.first['status'];
                iconColor = (lastStatus == 'delivered') ? Colors.green : Colors.orange;
              }

              return Stack(
                alignment: Alignment.center,
                children: [
                  Icon(
                    Icons.radar,
                    color: iconColor,
                    size: hasActiveOrder ? 28 : 24,
                  ),
                  if (hasActiveOrder)
                    Positioned(
                      top: 0,
                      right: 0,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: iconColor == Colors.green ? Colors.green : Colors.red, 
                          shape: BoxShape.circle
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          label: 'تتبع الطلب',
        ),

        BottomNavigationBarItem(
          icon: Badge(
            label: Text(cartCount.toString()),
            isLabelVisible: cartCount > 0,
            child: const Icon(Icons.shopping_cart),
          ),
          label: 'السلة',
        ),
        const BottomNavigationBarItem(icon: Icon(Icons.person), label: 'حسابي'),
      ],
      onTap: (index) async {
        if (index == activeIndex) return;

        if (index == 2) {
          try {
            final snapshot = await FirebaseFirestore.instance
                .collection('specialRequests')
                .where('userId', isEqualTo: user?.uid)
                .where('status', whereIn: trackingStatuses)
                .orderBy('createdAt', descending: true) // 👈 ترتيب ضروري جداً
                .limit(1)
                .get();

            if (snapshot.docs.isNotEmpty) {
              final orderId = snapshot.docs.first.id;
              if (context.mounted) Navigator.pushNamed(context, '/customerTracking', arguments: orderId);
            } else {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("لا توجد طلبات نشطة حالياً")),
                );
              }
            }
          } catch (e) {
            debugPrint("❌ Error fetching tracking order: $e");
            // تنبيه للمبرمج في حالة نقص الاندكس
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("خطأ في الاتصال، تأكد من إعدادات الاندكس")),
              );
            }
          }
          return;
        }

        final routes = ['/consumerhome', '/consumer-purchases', '', '/cart', '/myDetails'];
        if (routes[index].isNotEmpty) {
          Navigator.pushNamed(context, routes[index]);
        }
      },
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
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
      child: Align(
        alignment: Alignment.centerRight,
        child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ),
    );
  }
}

// 4. بانر الأقسام (Main Categories)
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
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final category = categories[index];
          return GestureDetector(
            onTap: () {
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
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 30, 
                    backgroundImage: NetworkImage(category.imageUrl)
                  ),
                  const SizedBox(height: 5),
                  Text(category.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

