// المسار: lib/screens/buyer/buyer_product_list_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart'; 
import 'package:my_test_app/providers/cart_provider.dart'; 

import 'package:my_test_app/widgets/buyer_product_header.dart';
import 'package:my_test_app/widgets/product_list_grid.dart';
import 'package:my_test_app/widgets/manufacturers_banner.dart';
import 'package:my_test_app/widgets/buyer_mobile_nav_widget.dart'; // 🎯 استيراد الشريط الموحد
import 'package:my_test_app/screens/buyer/my_orders_screen.dart'; // للتوجيه

class BuyerProductListScreen extends StatefulWidget {
  final String mainCategoryId;
  final String subCategoryId;
  final String? manufacturerId;

  const BuyerProductListScreen({
    super.key,
    required this.mainCategoryId,
    required this.subCategoryId,
    this.manufacturerId,
  });

  @override
  State<BuyerProductListScreen> createState() => _BuyerProductListScreenState();
}

class _BuyerProductListScreenState extends State<BuyerProductListScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  String _pageTitle = 'المنتجات...';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSubCategoryDetails();
    });
  }

  // 🎯 دالة التنقل الموحدة لضمان عمل الشريط السفلي
  void _onItemTapped(int index) {
    switch (index) {
      case 0: 
        Navigator.pushReplacementNamed(context, '/traders'); 
        break;
      case 1: 
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

  Future<void> _loadSubCategoryDetails() async {
    try {
      final docSnapshot = await _db.collection('subCategory').doc(widget.subCategoryId).get();
      if (docSnapshot.exists && mounted) {
        setState(() {
          _pageTitle = docSnapshot.data()?['name'] ?? 'قسم فرعي غير معروف';
          _isLoading = false;
        });
      } else if (mounted) {
        setState(() {
          _pageTitle = 'القسم غير موجود';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _pageTitle = 'خطأ في التحميل';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: BuyerProductHeader(
        title: _pageTitle,
        isLoading: _isLoading,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ManufacturersBanner(
            subCategoryId: widget.subCategoryId, 
            onManufacturerSelected: (id) {
              if (id == 'ALL') {
                if (Navigator.of(context).canPop()) Navigator.of(context).pop();
              } else if (id != null) {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => BuyerProductListScreen(
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
              padding: const EdgeInsets.only(top: 12.0, left: 10.0, right: 10.0, bottom: 0.0),
              child: ProductListGrid(
                subCategoryId: widget.subCategoryId,
                pageTitle: _pageTitle,
                manufacturerId: widget.manufacturerId,
              ),
            ),
          ),
        ],
      ),

      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: Consumer<CartProvider>(
        builder: (context, cartProvider, child) {
          final cartCount = cartProvider.cartTotalItems; 

          return Stack(
            alignment: Alignment.topRight,
            children: [
              FloatingActionButton(
                heroTag: "product_list_cart_btn", // إضافة تاغ فريد لمنع خطأ Hero
                onPressed: () => Navigator.of(context).pushNamed('/cart'),
                backgroundColor: const Color(0xFF4CAF50), 
                elevation: 6,
                child: const Icon(Icons.shopping_cart, color: Colors.white, size: 28),
              ),
              if (cartCount > 0)
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.redAccent,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                    child: Text(
                      '$cartCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          );
        },
      ),

      // 🎯 استدعاء الشريط الموحد الجديد بدلاً من القديم
      bottomNavigationBar: Consumer<CartProvider>(
        builder: (context, cart, child) {
          return BuyerMobileNavWidget(
            selectedIndex: -1, // لضمان عدم إضاءة أي أيقونة بشكل خاطئ في صفحات التصفح
            onItemSelected: _onItemTapped,
            cartCount: cart.cartTotalItems,
            ordersChanged: false, // يمكن ربطها بحالة الإشعارات لاحقاً
          );
        },
      ),
    );
  }
}

