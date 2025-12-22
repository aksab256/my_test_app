import 'package:flutter/material.dart';
import 'package:my_test_app/screens/consumer/consumer_widgets.dart';
import 'package:my_test_app/screens/consumer/consumer_data_models.dart';
import 'package:my_test_app/services/consumer_data_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sizer/sizer.dart'; // تأكد من استخدامه للخطوط والمساحات

class ConsumerHomeScreen extends StatelessWidget {
  static const routeName = '/consumerHome';
  ConsumerHomeScreen({super.key});

  final ConsumerDataService dataService = ConsumerDataService();

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F5), // خلفية مريحة تميل للأخضر البارد
      drawer: const ConsumerSideMenu(),
      body: Stack(
        children: [
          // 1. الخلفية العلوية الملونة (Header Background)
          Container(
            height: 25.h,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: [Color(0xFF1B5E20), Color(0xFF388E3C)],
              ),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(40),
                bottomRight: Radius.circular(40),
              ),
            ),
          ),

          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // الـ AppBar المدمج يدوياً للتحكم الكامل
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                    child: ConsumerCustomAppBar(
                      userName: user?.displayName ?? 'مستخدم',
                      userPoints: 1000,
                      isLight: true, // وسيلة لجعل النص أبيض فوق الأخضر
                      onMenuPressed: () => Scaffold.of(context).openDrawer(),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // 2. زر الرادار المطور
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _buildRadarButton(context),
                  ),

                  const SizedBox(height: 35), // مساحة تفصل الردار عن الأقسام

                  // 3. قسم الأقسام المميزة (مع زيادة الارتفاع)
                  const ConsumerSectionTitle(title: 'الأقسام المميزة', color: Colors.black87),
                  SizedBox(
                    height: 18.h, // زيادة الارتفاع لإعطاء راحة بصرية
                    child: FutureBuilder<List<ConsumerCategory>>(
                      future: dataService.fetchMainCategories(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        final categories = snapshot.data ?? [];
                        return ConsumerCategoriesBanner(categories: categories);
                      },
                    ),
                  ),

                  const SizedBox(height: 25),

                  // 4. أحدث العروض (تملأ المساحة السفلية)
                  const ConsumerSectionTitle(title: 'أحدث العروض الحصرية'),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: FutureBuilder<List<ConsumerBanner>>(
                      future: dataService.fetchPromoBanners(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        final banners = snapshot.data ?? [];
                        // هنا سنطلب من الودجت أن يكون ارتفاعه أكبر (مثلاً 30.h)
                        return ConsumerPromoBanners(banners: banners, height: 32.h);
                      },
                    ),
                  ),

                  const SizedBox(height: 80), // مساحة أمان للـ BottomNav
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: const ConsumerFooterNav(cartCount: 3, activeIndex: 0),
    );
  }

  // ودجت زر الرادار بتصميم احترافي
  Widget _buildRadarButton(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.radar, color: Colors.green, size: 28), // أيقونة الرادار
        ),
        title: Text(
          "اكتشف ما يدور حولك الآن",
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12.sp),
        ),
        subtitle: Text(
          "سوبر ماركت، مطعم، صيدلية بجوارك..",
          style: TextStyle(fontSize: 9.sp, color: Colors.grey),
        ),
        trailing: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.green[700],
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.location_on, color: Colors.white),
        ),
        onTap: () {
          // الانتقال لصفحة الرادار
        },
      ),
    );
  }
}
