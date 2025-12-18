// lib/screens/consumer/consumer_home_screen.dart
import 'package:flutter/material.dart';
import 'package:my_test_app/screens/consumer/consumer_widgets.dart';
import 'package:my_test_app/screens/consumer/consumer_data_models.dart';
import 'package:my_test_app/services/consumer_data_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:my_test_app/theme/app_theme.dart';

class ConsumerHomeScreen extends StatelessWidget {
  static const routeName = '/consumerHome';
  ConsumerHomeScreen({super.key});

  final ConsumerDataService dataService = ConsumerDataService();

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Builder(
      builder: (context) {
        return Scaffold(
          // خلفية هادئة لتعزيز بروز العناصر
          backgroundColor: const Color(0xFFF8F9FA),
          
          drawer: const ConsumerSideMenu(),

          // استخدام الـ AppBar المطور الذي قمنا بتعديله سابقاً لجلب الاسم والنقاط
          appBar: ConsumerCustomAppBar(
            userName: user?.displayName ?? 'مستخدم',
            userPoints: 0,
            onMenuPressed: () {
              Scaffold.of(context).openDrawer();
            },
          ),
          
          body: SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. قسم البحث المبتكر (تصميم بارز يشبه الصورة)
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        height: 60,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: const BorderRadius.only(
                            bottomLeft: Radius.circular(30),
                            bottomRight: Radius.circular(30),
                          ),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.only(top: 10),
                        child: ConsumerSearchBar(), // هذا الودجت يحتوي على زر البحث المبتكر
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // 2. قسم الأقسام المميزة بتنسيق دائري
                  const ConsumerSectionTitle(title: 'الأقسام المميزة'),
                  FutureBuilder<List<ConsumerCategory>>(
                    future: dataService.fetchMainCategories(),
                    builder: (context, snapshot) {
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
                      // هذا الودجت سيعرض الدوائر كما في الصورة
                      return ConsumerCategoriesBanner(categories: categories);
                    },
                  ),

                  const SizedBox(height: 15),

                  // 3. قسم العروض الحصرية (Banners)
                  const ConsumerSectionTitle(title: 'أحدث العروض الحصرية'),
                  FutureBuilder<List<ConsumerBanner>>(
                    future: dataService.fetchPromoBanners(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 20.0),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ));
                      }
                      final banners = snapshot.data ?? [];
                      if (banners.isEmpty || snapshot.hasError) {
                        return const SizedBox(height: 20);
                      }
                      return ConsumerPromoBanners(banners: banners);
                    },
                  ),

                  // مسافة جمالية في نهاية الصفحة
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
          
          // شريط التنقل السفلي المطور
          bottomNavigationBar: const ConsumerFooterNav(cartCount: 3, activeIndex: 0),
        );
      }
    );
  }
}
