import 'package:flutter/material.dart';
import 'package:my_test_app/screens/consumer/consumer_widgets.dart';
import 'package:my_test_app/screens/consumer/consumer_data_models.dart';
import 'package:my_test_app/services/consumer_data_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ConsumerHomeScreen extends StatelessWidget {
  static const routeName = '/consumerHome';
  ConsumerHomeScreen({super.key});

  final ConsumerDataService dataService = ConsumerDataService();

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA), // خلفية فاتحة جداً تبرز العناصر
      // إضافة الـ Drawer هنا ليعمل مع زر المنيو
      drawer: const ConsumerSideMenu(),
      
      // 1. الـ AppBar مع تمرير الـ Context الصحيح لفتح المنيو
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(70),
        child: Builder(
          builder: (context) => ConsumerCustomAppBar(
            userName: user?.displayName ?? 'مستخدم',
            userPoints: 0, // سيتم تحديثها تلقائياً من الـ Stream داخل الودجت
            onMenuPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
      ),

      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 2. شريط الرادار (اكتشف ما حولك)
              const SizedBox(height: 10),
              const ConsumerSearchBar(),

              // 3. قسم الأقسام المميزة (تم حذف "عرض الكل" من داخل الودجت تلقائياً)
              const ConsumerSectionTitle(title: 'الأقسام المميزة'),
              FutureBuilder<List<ConsumerCategory>>(
                future: dataService.fetchMainCategories(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const SizedBox(
                      height: 130,
                      child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF43A047))),
                    );
                  }
                  final categories = snapshot.data ?? [];
                  return ConsumerCategoriesBanner(categories: categories);
                },
              ),

              const SizedBox(height: 10),

              // 4. قسم العروض الحصرية
              const ConsumerSectionTitle(title: 'أحدث العروض الحصرية'),
              FutureBuilder<List<ConsumerBanner>>(
                future: dataService.fetchPromoBanners(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const SizedBox(
                      height: 200,
                      child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF43A047))),
                    );
                  }
                  final banners = snapshot.data ?? [];
                  // ارتفاع 220 ليناسب الشاشات المختلفة دون ضغط العناصر
                  return ConsumerPromoBanners(banners: banners, height: 220);
                },
              ),

              const SizedBox(height: 80), // مساحة كافية قبل الشريط السفلي
            ],
          ),
        ),
      ),

      // 5. شريط التنقل السفلي - ثابت ومحمي بـ SafeArea
      bottomNavigationBar: const ConsumerFooterNav(cartCount: 0, activeIndex: 0),
    );
  }
}

