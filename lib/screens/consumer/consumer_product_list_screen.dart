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
        extendBody: true, 
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
            Divider(height: 1.0, color: Colors.grey[300]), // من غير const عشان ميضربش
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                // RepaintBoundary بيفصل رسم الـ Grid عن الـ Nav عشان السرعة
                child: RepaintBoundary(
                  child: ProductListGrid(
                    subCategoryId: widget.subCategoryId,
                    pageTitle: _pageTitle,
                    manufacturerId: widget.manufacturerId,
                  ),
                ),
              ),
            ),
          ],
        ),
        // بناء يدوي 100% بعيداً عن consumer_widgets
        bottomNavigationBar: _buildAksabBottomNav(context),
      ),
    );
  }

  Widget _buildAksabBottomNav(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(25, 0, 25, 20),
      height: 70,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(35),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _navItem(context, Icons.storefront_outlined, 'المتجر', '/consumerhome'),
          _navItem(context, Icons.shopping_bag_outlined, 'السلة', '/cart', isCart: true),
          _navItem(context, Icons.person_outline_rounded, 'حسابي', '/myDetails'),
        ],
      ),
    );
  }

  Widget _navItem(BuildContext context, IconData icon, String label, String route, {bool isCart = false}) {
    bool isActive = isCart; // في هذه الصفحة نعتبر السلة هي الوجهة الأساسية
    return InkWell(
      onTap: () {
        if (isCart) return; // لو ضغط على السلة وهو فيها ميعملش حاجة
        Navigator.pushNamedAndRemoveUntil(context, route, (route) => false);
      },
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
            : Icon(icon, color: Colors.grey[400], size: 26),
          Text(
            label, 
            style: TextStyle(
              fontSize: 10, 
              fontFamily: 'Cairo', 
              color: isActive ? const Color(0xFF43A047) : Colors.grey[600],
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal
            ),
          ),
        ],
      ),
    );
  }
}

