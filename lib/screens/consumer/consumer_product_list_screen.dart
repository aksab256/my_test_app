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
        extendBody: true, // مهم جداً لانسيابية الشريط العائم
        backgroundColor: Colors.grey[50],
        appBar: BuyerProductHeader(
          title: _pageTitle,
          isLoading: _isLoading,
        ),
        body: Column(
          children: [
            ManufacturersBanner(
              subCategoryId: widget.subCategoryId,
              onManufacturerSelected: (id) {
                if (id == 'ALL') {
                  Navigator.of(context).pop();
                } else {
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
              child: ProductListGrid(
                subCategoryId: widget.subCategoryId,
                pageTitle: _pageTitle,
                manufacturerId: widget.manufacturerId,
              ),
            ),
          ],
        ),
        floatingActionButton: _buildModernFAB(context),
        bottomNavigationBar: _buildModernBottomNav(context),
      ),
    );
  }

  // 🎯 بناء الشريط السفلي يدوياً لضمان السرعة والرسم الصحيح
  Widget _buildModernBottomNav(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      height: 65,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 15, offset: const Offset(0, 8)),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _navItem(context, Icons.storefront_rounded, 'المتجر', 0, '/consumerhome'),
          _navItem(context, Icons.shopping_bag_rounded, 'السلة', 1, '/cart', isCart: true),
          _navItem(context, Icons.person_rounded, 'حسابي', 2, '/myDetails'),
        ],
      ),
    );
  }

  Widget _navItem(BuildContext context, IconData icon, String label, int index, String route, {bool isCart = false}) {
    bool isActive = index == 1; // السلة نشطة هنا
    return InkWell(
      onTap: () => index == 1 ? null : Navigator.pushNamed(context, route),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          isCart 
            ? Consumer<CartProvider>(
                builder: (context, cart, _) => Badge(
                  label: Text('${cart.cartTotalItems}', style: const TextStyle(fontSize: 10)),
                  isLabelVisible: cart.cartTotalItems > 0,
                  backgroundColor: Colors.redAccent,
                  child: Icon(icon, color: const Color(0xFF43A047), size: 28),
                ),
              )
            : Icon(icon, color: isActive ? const Color(0xFF43A047) : Colors.grey[400], size: 26),
          Text(label, style: TextStyle(
            fontSize: 10, 
            fontFamily: 'Cairo', 
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            color: isActive ? const Color(0xFF43A047) : Colors.grey[600]
          )),
        ],
      ),
    );
  }

  Widget _buildModernFAB(BuildContext context) {
    return Consumer<CartProvider>(
      builder: (context, cart, _) => FloatingActionButton(
        heroTag: "fab_aksab_prod", // تاجي فريد لمنع التعليق
        onPressed: () => Navigator.pushNamed(context, '/cart'),
        backgroundColor: const Color(0xFF43A047),
        child: const Icon(Icons.shopping_cart, color: Colors.white),
      ),
    );
  }
}

