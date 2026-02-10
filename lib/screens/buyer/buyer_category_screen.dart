// المسار: lib/screens/buyer/buyer_category_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:my_test_app/widgets/buyer_category_header.dart';
import 'package:my_test_app/widgets/buyer_sub_categories_grid.dart';
import 'package:my_test_app/widgets/buyer_category_ads_banner.dart';
import 'package:my_test_app/widgets/category_bottom_nav_bar.dart'; 

class BuyerCategoryScreen extends StatefulWidget {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: BuyerCategoryHeader(
        title: _categoryName,
        isLoading: _isLoading,
      ),

      body: _isLoading
        ? const Center(child: CircularProgressIndicator(color: Color(0xFF4A6491))) 
        : SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 15.0, vertical: 10.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 🎯 التعديل هنا: تمرير المعرف للبانر ليعرف أي إعلانات يسحب
                BuyerCategoryAdsBanner(categoryId: widget.mainCategoryId),

                const SizedBox(height: 30),

                BuyerSubCategoriesGrid(mainCategoryId: widget.mainCategoryId),

                // ✅ تم حذف نص "المنتجات المرتبطة سيتم بناؤها لاحقاً" من هنا

                const SizedBox(height: 50),
              ],
            ),
          ),

      // ✅ تم إضافة selectedIndex: -1 لحل مشكلة عدم استجابة زر الهوم
      bottomNavigationBar: const CategoryBottomNavBar(selectedIndex: -1),
    );
  }
}
