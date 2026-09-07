
// المسار: lib/screens/buyer/buyer_category_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// استبدال الـ Import بالشريط السفلي الموحد
import 'package:my_test_app/widgets/buyer_category_header.dart';
import 'package:my_test_app/widgets/buyer_sub_categories_grid.dart';
import 'package:my_test_app/widgets/buyer_category_ads_banner.dart';
import 'package:my_test_app/widgets/buyer_mobile_nav_widget.dart'; // 🎯 الشريط الموحد
import 'package:my_test_app/screens/buyer/my_orders_screen.dart'; // للتوجيه

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

  // نفس منطق التنقل الموجود في الـ Home لتوحيد الأداء
  void _onItemTapped(int index) {
    switch (index) {
      case 0: 
        Navigator.pushReplacementNamed(context, '/traders'); 
        break;
      case 1: 
        // العودة للرئيسية
        Navigator.of(context).pushNamedAndRemoveUntil('/buyerHome', (route) => false);
        break;
      case 2:
        Navigator.push(context, MaterialPageRoute(builder: (context) => const MyOrdersScreen()));
        break;
      case 3: 
        Navigator.pushReplacementNamed(context, '/wallet'); 
        break;
    }
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
    return SafeArea( // 🛡️ حل مشكلة التداخل مع شريط الهاتف والساعة
      child: Scaffold(
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
                  BuyerCategoryAdsBanner(categoryId: widget.mainCategoryId),
                  const SizedBox(height: 30),
                  BuyerSubCategoriesGrid(mainCategoryId: widget.mainCategoryId),
                  // تم حذف نص "المنتجات المرتبطة" هنا
                  const SizedBox(height: 50),
                ],
              ),
            ),

        // 🎯 استخدام الـ Widget الموحد بدلاً من القديم
        bottomNavigationBar: BuyerMobileNavWidget(
          selectedIndex: -1, // لكي لا تظهر أي أيقونة كأنها نشطة بشكل خاطئ
          onItemSelected: _onItemTapped,
          cartCount: 0, // يمكنك تمرير المتغير الفعلي لو أردت
          ordersChanged: false,
        ),
      ),
    );
  }
}

