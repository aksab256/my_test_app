// lib/screens/consumer/consumer_product_list_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:my_test_app/providers/cart_provider.dart';

// استيراد الأجزاء المشتركة (اللي بتبني الكارت والشبكة والشركات)
import 'package:my_test_app/widgets/product_list_grid.dart';
import 'package:my_test_app/widgets/manufacturers_banner.dart';
import 'package:my_test_app/widgets/buyer_product_header.dart'; // الهيدر الاحترافي

// استيراد الشريط السفلي الخاص بالمستهلك فقط
import 'package:my_test_app/screens/consumer/consumer_widgets.dart'; 

class ConsumerProductListScreen extends StatefulWidget {
  final String mainCategoryId;
  final String subCategoryId;
  final String? manufacturerId;

  const ConsumerProductListScreen({
    super.key,
    required this.mainCategoryId,
    required this.subCategoryId,
    this.manufacturerId,
  });

  @override
  State<ConsumerProductListScreen> createState() => _ConsumerProductListScreenState();
}

class _ConsumerProductListScreenState extends State<ConsumerProductListScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  String _pageTitle = 'المنتجات...';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSubCategoryDetails();
  }

  Future<void> _loadSubCategoryDetails() async {
    try {
      final docSnapshot = await _db.collection('subCategory').doc(widget.subCategoryId).get();
      if (docSnapshot.exists && mounted) {
        setState(() {
          _pageTitle = docSnapshot.data()?['name'] ?? 'قسم فرعي';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        // نستخدم نفس الهيدر عشان التصميم يكون متطابق ومحترف
        appBar: BuyerProductHeader(
          title: _pageTitle,
          isLoading: _isLoading,
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // بانر الشركات - بينادي صفحة المستهلك عند الضغط
            ManufacturersBanner(
              subCategoryId: widget.subCategoryId, 
              onManufacturerSelected: (id) {
                if (id == 'ALL') {
                  Navigator.of(context).pop();
                } else if (id != null) {
                  // 🎯 هنا السر: المستهلك بينادي صفحة المستهلك (نفسه) مش التاجر
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => ConsumerProductListScreen(
                        mainCategoryId: widget.mainCategoryId,
                        subCategoryId: widget.subCategoryId,
                        manufacturerId: id,
                      ),
                    ),
                  );
                }
              },
            ),
            Divider(height: 1.0, color: Colors.grey[300]),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                // 🎯 بنستخدم نفس الـ Grid المشترك اللي بيبني الكروت
                child: ProductListGrid(
                  subCategoryId: widget.subCategoryId,
                  pageTitle: _pageTitle,
                  manufacturerId: widget.manufacturerId,
                ),
              ),
            ),
          ],
        ),

        // 🎯 أيقونة السلة العائمة (نفس المنطق المشترك)
        floatingActionButton: _buildFloatingCart(context),

        // 🎯 أهم جزء: شريط التنقل السفلي للمستهلك فقط
        bottomNavigationBar: const ConsumerFooterNav(activeIndex: 1, cartCount: 0),
      ),
    );
  }

  Widget _buildFloatingCart(BuildContext context) {
    return Consumer<CartProvider>(
      builder: (context, cartProvider, child) {
        final cartCount = cartProvider.cartTotalItems;
        return Stack(
          alignment: Alignment.topRight,
          children: [
            FloatingActionButton(
              onPressed: () => Navigator.of(context).pushNamed('/cart'),
              backgroundColor: const Color(0xFF4CAF50),
              child: const Icon(Icons.shopping_cart, color: Colors.white),
            ),
            if (cartCount > 0)
              CircleAvatar(
                radius: 10,
                backgroundColor: Colors.red,
                child: Text('$cartCount', style: const TextStyle(color: Colors.white, fontSize: 10)),
              ),
          ],
        );
      },
    );
  }
}
