// lib/screens/consumer/ConsumerProductListScreen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:my_test_app/services/marketplace_data_service.dart';
import 'package:my_test_app/models/product_model.dart';
import 'package:my_test_app/models/offer_model.dart'; 
import 'package:my_test_app/providers/theme_notifier.dart';
import 'package:my_test_app/providers/cart_provider.dart';
import 'package:my_test_app/screens/consumer/consumer_product_details_screen.dart';

class ConsumerProductListScreen extends StatefulWidget {
  static const routeName = '/consumerProducts';

  final String ownerId;
  final String mainId;
  final String subId;
  final String subCategoryName;

  const ConsumerProductListScreen({
    super.key,
    required this.ownerId,
    required this.mainId,
    required this.subId,
    required this.subCategoryName,
  });

  @override
  State<ConsumerProductListScreen> createState() => _ConsumerProductListScreenState();
}

class _ConsumerProductListScreenState extends State<ConsumerProductListScreen> {
  final MarketplaceDataService _dataService = MarketplaceDataService();
  late Future<List<Map<String, dynamic>>> _productsFuture;

  @override
  void initState() {
    super.initState();
    _productsFuture = _fetchProductsWithOffers();
  }

  Future<List<Map<String, dynamic>>> _fetchProductsWithOffers() async {
    return _dataService.fetchProductsAndOffersBySubCategory(
      ownerId: widget.ownerId,
      mainId: widget.mainId,
      subId: widget.subId,
    );
  }

  void _addToCart(BuildContext context, ProductModel product, ProductOfferModel offer) async {
    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    if (offer.units.isEmpty) return;
    final firstUnit = offer.units.first;
    final passedName = offer.sellerName ?? "متجر";

    try {
      await cartProvider.addItemToCart(
        productId: product.id,
        name: product.name,
        offerId: offer.id!,
        sellerId: offer.sellerId!,
        sellerName: passedName,
        unitIndex: 0,
        unit: firstUnit.unitName,
        price: firstUnit.price,
        quantityToAdd: 1,
        userRole: 'consumer',
        imageUrl: product.imageUrls.isNotEmpty ? product.imageUrls.first : '',
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم إضافة المنتج بنجاح إلى السلة.', textDirection: TextDirection.rtl),
          duration: Duration(seconds: 3),
          backgroundColor: Color(0xFF4CAF50),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('فشل الإضافة: $e', textDirection: TextDirection.rtl),
          duration: const Duration(seconds: 6),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  Widget _buildProductCard(BuildContext context, Map<String, dynamic> productOfferMap) {
    final product = productOfferMap['product'] as ProductModel;
    final offer = productOfferMap['offer'] as ProductOfferModel;

    if (offer.units.isEmpty || offer.units.first.price <= 0) {
      return const SizedBox.shrink();
    }
    final firstUnit = offer.units.first;
    final price = firstUnit.price;

    final themeNotifier = Provider.of<ThemeNotifier>(context, listen: false);
    final shadowColor = themeNotifier.isDarkMode ? Colors.black45 : Colors.black12;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [BoxShadow(color: shadowColor, blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () {
          Navigator.of(context).pushNamed(
            ConsumerProductDetailsScreen.routeName,
            arguments: {'productId': product.id, 'offerId': offer.id},
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
              child: Image.network(
                product.imageUrls.isNotEmpty ? product.imageUrls.first : 'https://via.placeholder.com/150',
                height: 120,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => const SizedBox(height: 120, child: Center(child: Icon(Icons.broken_image, size: 40, color: Colors.grey))),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(product.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold), maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 5),
                  Text('${price.toStringAsFixed(2)} ج.م', style: TextStyle(fontSize: 18, color: Theme.of(context).colorScheme.error, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _addToCart(context, product, offer),
                      icon: const Icon(FontAwesomeIcons.cartPlus, size: 16, color: Colors.white),
                      label: const Text('أضف إلى السلة', style: TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4CAF50), padding: const EdgeInsets.symmetric(vertical: 8), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5))),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cartCount = Provider.of<CartProvider>(context).itemCount;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: const Color(0xFF4a6491),
          foregroundColor: Colors.white,
          title: Text(widget.subCategoryName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
          centerTitle: true,
        ),
        body: FutureBuilder<List<Map<String, dynamic>>>(
          future: _productsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [CircularProgressIndicator(), SizedBox(height: 15), Text('جاري تحميل المنتجات...', style: TextStyle(fontSize: 18))]));
            }
            if (snapshot.hasError) {
              return Center(child: Padding(padding: const EdgeInsets.all(20.0), child: Text('حدث خطأ: ${snapshot.error}', textAlign: TextAlign.center, style: const TextStyle(color: Colors.red, fontSize: 18))));
            }
            final products = snapshot.data ?? [];
            if (products.isEmpty) {
              return const Center(child: Padding(padding: EdgeInsets.all(20.0), child: Text('لا توجد منتجات متاحة حالياً.', textAlign: TextAlign.center, style: TextStyle(fontSize: 18, color: Colors.grey))));
            }
            return GridView.builder(
              padding: const EdgeInsets.all(15),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 15, mainAxisSpacing: 15, childAspectRatio: 0.7),
              itemCount: products.length,
              itemBuilder: (context, index) => _buildProductCard(context, products[index]),
            );
          },
        ),
        // ✅ تم تغليف الشريط بالمنطقة الآمنة لحل مشكلة التداخل
        bottomNavigationBar: SafeArea(
          top: false, // لا نريد حماية الجزء العلوي هنا
          child: _buildMobileNav(context, cartCount),
        ),
      ),
    );
  }

  Widget _buildMobileNav(BuildContext context, int cartCount) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(color: Theme.of(context).shadowColor.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, -2)),
        ],
      ),
      padding: const EdgeInsets.only(top: 12, bottom: 8), // تم ضبط المسافات قليلاً لتناسب SafeArea
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavItem(context, FontAwesomeIcons.home, 'الرئيسية', '/marketplaceHome', isActive: false, targetRoute: '/marketplaceHome'),
          _buildNavItem(context, FontAwesomeIcons.shoppingCart, 'السلة', '/cart', isActive: false, count: cartCount, targetRoute: '/cart'),
          _buildNavItem(context, FontAwesomeIcons.store, 'التجار', '/consumerStoreSearch', isActive: false, targetRoute: '/consumerStoreSearch'),
        ],
      ),
    );
  }

  Widget _buildNavItem(BuildContext context, IconData icon, String label, String route, {required bool isActive, int count = 0, String? targetRoute}) {
    final inactiveColor = Theme.of(context).colorScheme.onSurface.withOpacity(0.7);
    final activeColor = Theme.of(context).colorScheme.primary;

    return InkWell(
      onTap: () { if (targetRoute != null) Navigator.of(context).pushNamed(targetRoute); },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(icon, size: 22, color: isActive ? activeColor : inactiveColor),
              if (count > 0 && targetRoute == '/cart')
                Positioned(
                  top: -5,
                  right: -10,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(10)),
                    constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                    child: Text(count.toString(), style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 12, color: isActive ? activeColor : inactiveColor, fontWeight: FontWeight.w600, fontFamily: 'Cairo')),
        ],
      ),
    );
  }
}
