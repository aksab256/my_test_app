// lib/screens/web/web_consumer_home_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:my_test_app/screens/consumer/consumer_data_models.dart';
import 'package:my_test_app/services/consumer_data_service.dart';
import 'package:my_test_app/widgets/promo_slider_widget.dart';

class WebConsumerHomeScreen extends StatefulWidget {
  static const routeName = '/web-consumer-home';
  const WebConsumerHomeScreen({super.key});

  @override
  State<WebConsumerHomeScreen> createState() => _WebConsumerHomeScreenState();
}

class _WebConsumerHomeScreenState extends State<WebConsumerHomeScreen> {
  final ConsumerDataService dataService = ConsumerDataService();
  final Color primaryColor = const Color(0xFF2E7D32); // الأخضر الخاص بأكسب
  final Color accentColor = const Color(0xFFFF9800); // البرتقالي
  final String googlePlayUrl = "https://play.google.com/store/apps/details?id=com.aksabeg500&pcampaignid=web_share";

  Future<void> _launchAppDownload() async {
    final Uri url = Uri.parse(googlePlayUrl);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      debugPrint('Could not launch $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F5F7),
        // 1. Header علوي احترافي بستايل الويب
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(80),
          child: Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              children: [
                // اللوجو / العنوان
                Row(
                  children: [
                    Icon(Icons.shopping_bag_outlined, color: primaryColor, size: 32),
                    const SizedBox(width: 8),
                    Text(
                      'أسواق أكسب',
                      style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 22),
                    ),
                  ],
                ),
                const SizedBox(width: 30),

                // شريط بحث عريض زي أمازون
                Expanded(
                  child: Container(
                    height: 45,
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'ابحث عن منتجات، محلات، ملابس، مواد غذائية...',
                        prefixIcon: const Icon(Icons.search, color: Colors.grey),
                        suffixIcon: Container(
                          margin: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: primaryColor,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(Icons.search, color: Colors.white, size: 20),
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 20),

                // زرار "حمل التطبيق" المميز في الـ Header
                ElevatedButton.icon(
                  onPressed: _launchAppDownload,
                  icon: const Icon(Icons.android, color: Colors.white),
                  label: const Text('حمل التطبيق', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(width: 15),

                // سلة التسوق والحساب
                IconButton(
                  icon: const Icon(Icons.shopping_cart_outlined, color: Colors.black87),
                  onPressed: () {},
                ),
              ],
            ),
          ),
        ),
        body: SingleChildScrollView(
          child: Column(
            children: [
              // 2. شريط الأقسام السريع للويب
              Container(
                height: 50,
                color: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: FutureBuilder<List<ConsumerCategory>>(
                  future: dataService.fetchMainCategories(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const SizedBox.shrink();
                    return ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: snapshot.data!.length,
                      itemBuilder: (context, index) {
                        final cat = snapshot.data![index];
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          child: InkWell(
                            onTap: () {},
                            child: Text(
                              cat.name,
                              style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black87, fontSize: 14),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),

              // 3. المحتوى الرئيسي لصفحة الويب (محتوى عريض ومزحوم)
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    // البانر العلوي + خدمات أكسب على الجانب
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // السلايدر الرئيسي للعروض (ياخذ المساحة الأكبر)
                        Expanded(
                          flex: 3,
                          child: FutureBuilder<List<ConsumerBanner>>(
                            future: dataService.fetchPromoBanners(),
                            builder: (context, snapshot) {
                              if (!snapshot.hasData) {
                                return Container(
                                  height: 300,
                                  decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(12)),
                                );
                              }
                              return PromoSliderWidget(banners: snapshot.data!, height: 300.0);
                            },
                          ),
                        ),
                        const SizedBox(width: 15),

                        // بنرات خدمات أكسب السريعة على اليمين (رادار المحلات و ابعتلي حد)
                        Expanded(
                          flex: 1,
                          child: Column(
                            children: [
                              _buildSideServiceCard(
                                title: "رادار المحلات القريبة",
                                subtitle: "استكشف المتاجر حولك",
                                icon: Icons.radar,
                                color: primaryColor,
                                onTap: () => Navigator.pushNamed(context, '/store-search'),
                              ),
                              const SizedBox(height: 15),
                              _buildSideServiceCard(
                                title: "ابعتلي حد",
                                subtitle: "مندوب توصيل خاص لك",
                                icon: Icons.delivery_dining,
                                color: accentColor,
                                onTap: () => Navigator.pushNamed(context, '/abaatly-had'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 30),

                    // 4. قسم "حمل التطبيق" Banner عريض ملفت
                    _buildDownloadAppBanner(),
                    const SizedBox(height: 30),

                    // 5. شبكة المنتجات (Amazon-Style Product Grid)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'أحدث المنتجات والعروض',
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                        TextButton(onPressed: () {}, child: const Text('عرض الكل')),
                      ],
                    ),
                    const SizedBox(height: 15),
                    _buildProductsGrid(),
                  ],
                ),
              ),

              // 6. Footer سفلي ضخم زي أمازون
              _buildWebFooter(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSideServiceCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 142,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 36),
            const SizedBox(height: 10),
            Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            Text(subtitle, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildDownloadAppBanner() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [primaryColor, const Color(0xFF1B5E20)]),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          const Icon(Icons.phone_android, color: Colors.white, size: 50),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'تسوق أسرع وأسهل مع تطبيق أكسب على الموبايل!',
                  style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 5),
                Text(
                  'احصل على تنبيهات العروض اللحظية والخصومات الحصرية من التطبيق مباشرة.',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: _launchAppDownload,
            icon: const Icon(Icons.get_app, color: Colors.black87),
            label: const Text('حمل التطبيق الآن', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductsGrid() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('products').limit(12).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(40.0),
            child: Text('لا توجد منتجات متاحة حالياً', style: TextStyle(fontSize: 16)),
          );
        }

        final docs = snapshot.data!.docs;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: docs.length,
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 260, // العرض الأقصى لكل كارت لتناسب الشاشات المختلفة
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 0.72,
          ),
          itemBuilder: (context, index) {
            final prod = docs[index].data() as Map<String, dynamic>;
            return Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                        image: DecorationImage(
                          image: NetworkImage(prod['imageUrl'] ?? 'https://via.placeholder.com/200'),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          prod['name'] ?? 'منتج',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${prod['price'] ?? 0} ج.م',
                          style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: () {},
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: primaryColor),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            ),
                            child: const Text('إضافة للسلة'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildWebFooter() {
    return Container(
      color: Colors.grey[900],
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 40),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('أسواق أكسب - Aksab', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
                  const SizedBox(height: 10),
                  const Text('منصتك الأولى للتسوق المباشر والطلب السريع.', style: TextStyle(color: Colors.grey)),
                ],
              ),
              ElevatedButton.icon(
                onPressed: _launchAppDownload,
                icon: const Icon(Icons.android),
                label: const Text('تنزيل التطبيق من Google Play'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                ),
              ),
            ],
          ),
          const Divider(color: Colors.grey, height: 40),
          const Text('جميع الحقوق محفوظة © 2026 أسواق أكسب', style: TextStyle(color: Colors.grey, fontSize: 12)),
        ],
      ),
    );
  }
}