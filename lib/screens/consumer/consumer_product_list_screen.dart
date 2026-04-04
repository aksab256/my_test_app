// lib/screens/consumer/consumer_product_list_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:my_test_app/providers/cart_provider.dart';
import 'package:my_test_app/widgets/product_list_grid.dart';
import 'package:my_test_app/widgets/manufacturers_banner.dart';
import 'package:my_test_app/widgets/buyer_product_header.dart';

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
                  Navigator.of(context).pop();
                } else if (id != null) {
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
            const Divider(height: 1.0, color: Colors.grey[300]),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: ProductListGrid(
                  subCategoryId: widget.subCategoryId,
                  pageTitle: _pageTitle,
                  manufacturerId: widget.manufacturerId,
                ),
              ),
            ),
          ],
        ),
        // تم الإبقاء على الزر العائم حسب طلبك السابق مع ربطه بالسلة
        floatingActionButton: _buildFloatingCart(context),
        
        // 🎯 تصميم الشريط السفلي المودرن (Floating & Minimalist)
        bottomNavigationBar: Container(
          margin: const EdgeInsets.fromLTRB(25, 0, 25, 20), // لجعله طائراً
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(35),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.12),
                blurRadius: 25,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(35),
            child: BottomNavigationBar(
              currentIndex: 1, // السلة نشطة
              selectedItemColor: const Color(0xFF43A047),
              unselectedItemColor: Colors.grey[400],
              type: BottomNavigationBarType.fixed,
              backgroundColor: Colors.white,
              elevation: 0,
              showSelectedLabels: true,
              showUnselectedLabels: false, // لمسة مودرن لإعطاء مساحة بصرية
              selectedLabelStyle: const TextStyle(
                fontSize: 11, 
                fontWeight: FontWeight.bold, 
                fontFamily: 'Cairo'
              ),
              items: [
                const BottomNavigationBarItem(
                  icon: Icon(Icons.storefront_outlined, size: 26),
                  activeIcon: Icon(Icons.storefront_rounded, size: 28),
                  label: 'المتجر',
                ),
                BottomNavigationBarItem(
                  icon: Consumer<CartProvider>(
                    builder: (context, cart, child) => Badge(
                      label: Text('${cart.cartTotalItems}', style: const TextStyle(fontSize: 10)),
                      isLabelVisible: cart.cartTotalItems > 0,
                      backgroundColor: Colors.redAccent,
                      child: const Icon(Icons.shopping_bag_outlined, size: 26),
                    ),
                  ),
                  activeIcon: const Icon(Icons.shopping_bag_rounded, size: 28),
                  label: 'السلة',
                ),
                const BottomNavigationBarItem(
                  icon: Icon(Icons.person_outline_rounded, size: 26),
                  activeIcon: Icon(Icons.person_rounded, size: 28),
                  label: 'حسابي',
                ),
              ],
              onTap: (index) {
                if (index == 1) return;
                if (index == 0) {
                  Navigator.pushNamedAndRemoveUntil(context, '/consumerhome', (route) => false);
                } else if (index == 2) {
                  Navigator.pushNamed(context, '/myDetails');
                }
              },
            ),
          ),
        ),
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
              heroTag: "product_list_fab",
              onPressed: () => Navigator.of(context).pushNamed('/cart'),
              backgroundColor: const Color(0xFF43A047),
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

