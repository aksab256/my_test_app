// lib/screens/consumer/consumer_home_screen.dart
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

    // 🎯 استخدام Builder هنا ضروري جداً لتوفير Context يرى الـ Scaffold
    // لكي يعمل أمر فتح القائمة (Drawer) بدون مشاكل
    return Builder(
      builder: (context) {
        return Scaffold(
          // القائمة الجانبية ستفتح من اليمين تلقائياً بسبب إعدادات main.dart
          drawer: const ConsumerSideMenu(),

          appBar: ConsumerCustomAppBar(
            userName: user?.displayName ?? 'مستخدم',
            userPoints: 0,
            onMenuPressed: () {
              // ✅ التصحيح: استدعاء مباشر لفتح القائمة
              Scaffold.of(context).openDrawer();
            },
          ),

          body: SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 10),
                    child: ConsumerSearchBar(),
                  ),

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
                      return ConsumerCategoriesBanner(categories: categories);
                    },
                  ),

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

                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),

          bottomNavigationBar: const ConsumerFooterNav(cartCount: 3, activeIndex: 0),
        );
      }
    );
  }
}
