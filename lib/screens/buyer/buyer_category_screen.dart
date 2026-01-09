// المسار: lib/screens/buyer/buyer_category_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ✅ المسارات الصحيحة (باستخدام اسم الحزمة my_test_app)
import 'package:my_test_app/widgets/buyer_category_header.dart';
import 'package:my_test_app/widgets/buyer_sub_categories_grid.dart';
import 'package:my_test_app/widgets/buyer_category_ads_banner.dart';
// 🚀 استيراد الشريط السفلي المستقل الجديد
import 'package:my_test_app/widgets/category_bottom_nav_bar.dart'; 

// ❌ تم حذف استيرادات المسارات الثابتة (BuyerHomeScreen.routeName, TradersScreen.routeName, إلخ)
// ❌ وتم حذف استيراد BuyerMobileNavWidget


class BuyerCategoryScreen extends StatefulWidget {
  // استقبال الـ ID من الـ route arguments
  final String mainCategoryId;

  const BuyerCategoryScreen({
    super.key,
    required this.mainCategoryId,
  });

  @override
  State<BuyerCategoryScreen> createState() => _BuyerCategoryScreenState();
}

class _BuyerCategoryScreenState extends State<BuyerCategoryScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  String _categoryName = 'جارٍ التحميل...';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCategoryDetails();
  }

  // دالة جلب اسم القسم الرئيسي لعرضه في العنوان
  Future<void> _loadCategoryDetails() async {
    try {
      final docSnapshot = await _db.collection('mainCategory').doc(widget.mainCategoryId).get();
      if (docSnapshot.exists && mounted) {
        setState(() {
          _categoryName = docSnapshot.data()?['name'] ?? 'قسم غير معروف';
          _isLoading = false;
        });
      } else if (mounted) {
        setState(() {
          _categoryName = 'القسم غير موجود';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _categoryName = 'خطأ في التحميل';
          _isLoading = false;
        });
      }
    }
  }

  // ❌ تم حذف دالة _handleNavigation بالكامل لأن منطق التوجيه أصبح داخل CategoryBottomNavBar.

  @override
  Widget build(BuildContext context) {
    // Scaffold هو الهيكل الأساسي للشاشة
    return Scaffold(
      // 1. استدعاء المكون الأول: Header
      appBar: BuyerCategoryHeader(
        title: _categoryName,
        isLoading: _isLoading,
      ),

      body: _isLoading
        ? const Center(child: CircularProgressIndicator(color: Color(0xFF4A6491))) // لون شريط العنوان
        : SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 15.0, vertical: 10.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 🚀 التعديل: نقل البانر الإعلاني ليكون في الأعلى
                BuyerCategoryAdsBanner(),

                const SizedBox(height: 30),

                // 2. استدعاء المكون الثاني: شبكة الأقسام الفرعية
                BuyerSubCategoriesGrid(mainCategoryId: widget.mainCategoryId),

                const SizedBox(height: 30),

                // 3. مساحة المنتجات المرتبطة (تأتي في الأسفل)
                const Center(
                  child: Text(
                    'قائمة المنتجات المرتبطة مباشرة (سيتم بناؤها لاحقاً)',
                    style: TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                ),

                const SizedBox(height: 50),
              ],
            ),
          ),

      // 🚀 التعديل: استخدام الشريط السفلي المستقل
      bottomNavigationBar: const CategoryBottomNavBar(),
    );
  }
}
