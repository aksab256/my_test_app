// lib/screens/consumer/consumer_home_screen.dart

import 'package:flutter/material.dart';
import 'package:my_test_app/screens/consumer/consumer_widgets.dart';
import 'package:my_test_app/screens/consumer/consumer_data_models.dart';
import 'package:my_test_app/services/consumer_data_service.dart';
                                                        
class ConsumerHomeScreen extends StatelessWidget {
  static const routeName = '/consumerHome';
                                                          // 💡 يجب إزالة كلمة 'const' هنا! هذا هو الحل النهائي لهذا الخطأ.
  ConsumerHomeScreen({super.key});
                                                          // هذا يعمل الآن كـ 'late final'
  late final ConsumerDataService dataService = ConsumerDataService();
                                                          @override
  Widget build(BuildContext context) {
    // 💡 يجب جلب الـ userId الحقيقي هنا
    const String mockUserId = 'user_id_from_auth_service';

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(

        // 1. شريط التنقل العلوي (AppBar)
        appBar: ConsumerCustomAppBar(
          userName: 'عبدالله',
          userPoints: 1250,
          onMenuPressed: () => Scaffold.of(context).openEndDrawer(),
          // ❌ تم حذف onThemeToggle: () => print("Toggle Theme Logic"),
        ),

        endDrawer: const ConsumerSideMenu(),

        // 2. محتوى الشاشة
        body: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 10),
              const ConsumerSearchBar(),
                                                                      // 3. قسم الأقسام المميزة (Categories) - ربط Firebase
              const ConsumerSectionTitle(title: 'الأقسام المميزة'),
              FutureBuilder<List<ConsumerCategory>>(
                future: dataService.fetchMainCategories(),
                builder: (context, snapshot) {
                  // ... (منطق عرض حالات التحميل والخطأ)
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: Padding(
                      padding: EdgeInsets.all(40.0),
                      child: CircularProgressIndicator(),
                    ));
                  }
                  final categories = snapshot.data ?? [];
                  if (categories.isEmpty || snapshot.hasError) {
                    return const Padding(
                      padding: EdgeInsets.all(20.0),
                      child: Center(child: Text('لا توجد أقسام نشطة حالياً.')),
                    );
                  }
                  return ConsumerCategoriesBanner(categories: categories);
                },
              ),

              // 4. قسم العروض الحصرية (Banners) - ربط Firebase
              const ConsumerSectionTitle(title: 'أحدث العروض الحصرية'),
              FutureBuilder<List<ConsumerBanner>>(
                future: dataService.fetchPromoBanners(),
                builder: (context, snapshot) {
                  // ... (منطق عرض حالات التحميل والخطأ)
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: Padding(
                      padding: EdgeInsets.only(top: 20.0, bottom: 20.0),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ));
                  }
                  final banners = snapshot.data ?? [];
                  if (banners.isEmpty || snapshot.hasError) {
                    return const SizedBox.shrink();
                  }
                  return ConsumerPromoBanners(banners: banners);
                },
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),

        bottomNavigationBar: const ConsumerFooterNav(cartCount: 3, activeIndex: 0),
      ),
    );
  }
}
