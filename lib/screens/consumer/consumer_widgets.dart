import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'consumer_data_models.dart';
import 'package:my_test_app/screens/consumer/consumer_category_screen.dart'; 

// 1. الشريط الجانبي (Side Menu) - نسخة مؤمنة بـ SafeArea
class ConsumerSideMenu extends StatelessWidget {
  const ConsumerSideMenu({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Drawer(
        child: SafeArea(
          // 🛡️ SafeArea هنا تضمن عدم تداخل الهيدر مع الكاميرا الأمامية أو الحواف العلوية
          top: true,
          bottom: true,
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
                    margin: EdgeInsets.zero, // لإزالة المسافات الزائدة مع SafeArea
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
                  final url = Uri.parse('https://aksab.shop/');
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
              const SizedBox(height: 10), // مسافة أمان إضافية في الأسفل
            ],
          ),
        ),
      ),
    );
  }
}

// 2. شريط التنقل السفلي (Footer Nav) - نسخة مؤمنة بـ SafeArea للحواف السفلية
class ConsumerFooterNav extends StatelessWidget {
  final int cartCount;
  final int activeIndex;
  const ConsumerFooterNav({super.key, required this.cartCount, required this.activeIndex});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    // 🛡️ تغليف بـ Container ثم SafeArea لضمان بقاء الشريط فوق شريط السحب في الهواتف الحديثة
    return Container(
      color: Colors.white, 
      child: SafeArea(
        top: false, // لا نحتاج حماية علوية للشريط السفلي
        child: BottomNavigationBar(
          currentIndex: activeIndex == -1 ? 0 : activeIndex,
          selectedItemColor: const Color(0xFF43A047),
          unselectedItemColor: Colors.grey,
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          elevation: 0, // الإيليفيشن يتم من الحاوية الخارجية
          selectedLabelStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
          unselectedLabelStyle: const TextStyle(fontSize: 10, fontFamily: 'Cairo'),
          items: [
            const BottomNavigationBarItem(icon: Icon(Icons.store), label: 'المتجر'),
            const BottomNavigationBarItem(icon: Icon(Icons.receipt_long), label: 'طلباتي'),
            
            BottomNavigationBarItem(
              icon: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('specialRequests')
                    .where('userId', isEqualTo: user?.uid)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Icon(Icons.radar, color: Colors.grey, size: 28);
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Icon(Icons.radar, color: Colors.grey, size: 28);
                  }

                  var docs = snapshot.data!.docs.toList();
                  docs.sort((a, b) {
                    Timestamp t1 = a['createdAt'] ?? Timestamp.now();
                    Timestamp t2 = b['createdAt'] ?? Timestamp.now();
                    return t2.compareTo(t1);
                  });

                  final lastOrder = docs.first.data() as Map<String, dynamic>;
                  final String status = (lastOrder['status'] ?? 'pending').toString().toLowerCase().trim();
                  final bool isRated = lastOrder.containsKey('rating');
                  
                  final bool isFinished = status.contains('cancel') || 
                                         status.contains('no_drivers') || 
                                         status.contains('timeout') ||
                                         status == 'none' ||
                                         isRated;

                  Color iconColor = Colors.grey;
                  IconData iconData = Icons.radar;

                  if (!isFinished && status != 'delivered') {
                    if (status == 'pending') {
                      iconColor = Colors.orange;
                      iconData = Icons.hourglass_top_rounded;
                    } else if (status == 'accepted' || status == 'at_pickup') {
                      iconColor = Colors.blue;
                      iconData = Icons.directions_bike_rounded;
                    } else if (status == 'picked_up') {
                      iconColor = Colors.indigo;
                      iconData = Icons.local_shipping_rounded;
                    }
                  } else if (status == 'delivered' && !isRated) {
                    iconColor = Colors.green;
                    iconData = Icons.check_circle_rounded;
                  }

                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      Icon(iconData, color: iconColor, size: 28),
                      if (!isFinished && status != 'delivered' && status != '')
                        Positioned(
                          top: -2, right: -2,
                          child: Container(
                            width: 10, height: 10,
                            decoration: BoxDecoration(
                              color: Colors.red, 
                              shape: BoxShape.circle, 
                              border: Border.all(color: Colors.white, width: 1.5)
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
                final snap = await FirebaseFirestore.instance
                    .collection('specialRequests')
                    .where('userId', isEqualTo: user?.uid)
                    .get();

                if (snap.docs.isNotEmpty) {
                  var docs = snap.docs.toList();
                  docs.sort((a, b) {
                    Timestamp t1 = a['createdAt'] ?? Timestamp.now();
                    Timestamp t2 = b['createdAt'] ?? Timestamp.now();
                    return t2.compareTo(t1);
                  });

                  final lastOrder = docs.first.data() as Map<String, dynamic>;
                  final String status = (lastOrder['status'] ?? 'pending').toString().toLowerCase().trim();
                  final bool isRated = lastOrder.containsKey('rating');

                  if (status.contains('cancel') || status.contains('no_drivers') || isRated) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("لا توجد طلبات نشطة حالياً لمتابعتها"), 
                          backgroundColor: Colors.black87,
                          behavior: SnackBarBehavior.floating,
                          duration: Duration(seconds: 2),
                        ),
                      );
                    }
                    return;
                  }

                  if (context.mounted) {
                    Navigator.pushNamed(context, '/customerTracking', arguments: docs.first.id);
                  }
                } else {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("لا توجد طلبات نشطه حاليا لمتابعتها"), backgroundColor: Colors.black87),
                    );
                  }
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("عذراً، حدث خطأ في استعادة البيانات")),
                  );
                }
              }
              return;
            }

            final routes = ['/consumerhome', '/consumer-purchases', '', '/cart', '/myDetails'];
            if (index < routes.length && routes[index].isNotEmpty) {
              Navigator.pushNamed(context, routes[index]);
            }
          },
        ),
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
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
      child: Align(
        alignment: Alignment.centerRight,
        child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
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
                    backgroundImage: NetworkImage(category.imageUrl),
                    backgroundColor: Colors.grey[200],
                  ),
                  const SizedBox(height: 5),
                  Text(category.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
