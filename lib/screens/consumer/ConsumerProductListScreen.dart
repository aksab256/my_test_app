import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:sizer/sizer.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:my_test_app/providers/cart_provider.dart';
import 'package:my_test_app/widgets/buyer_product_header.dart';
import 'package:my_test_app/screens/consumer/consumer_widgets.dart';
import '../../theme/app_theme.dart';

class ConsumerProductListScreen extends StatefulWidget {
  static const routeName = '/product-list';
  const ConsumerProductListScreen({super.key});

  @override
  State<ConsumerProductListScreen> createState() => _ConsumerProductListScreenState();
}

class _ConsumerProductListScreenState extends State<ConsumerProductListScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    final dynamic rawArgs = ModalRoute.of(context)?.settings.arguments;
    final Map<String, dynamic> args = (rawArgs is Map<String, dynamic>) ? rawArgs : {};

    final String ownerId = args['ownerId'] ?? '';
    final String subId = args['subId'] ?? '';
    final String title = args['subCategoryName'] ?? 'المنتجات';

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        appBar: BuyerProductHeader(
          title: title,
          isLoading: false,
        ),
        body: SafeArea(
          child: _buildProductGrid(ownerId, subId),
        ),
        bottomNavigationBar: Consumer<CartProvider>(
          builder: (context, cart, _) => ConsumerFooterNav(
            cartCount: cart.itemCount,
            activeIndex: -1,
          ),
        ),
        floatingActionButton: _buildFloatingCart(),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      ),
    );
  }

  Widget _buildProductGrid(String ownerId, String subId) {
    // 🚀 تم استبدال الـ FutureBuilder بفلترة مباشرة من الـ Stream لسرعة خرافية
    return StreamBuilder<QuerySnapshot>(
      stream: _db.collection('marketOffer')
          .where('ownerId', isEqualTo: ownerId)
          .where('subCategoryId', isEqualTo: subId) // 🎯 فلترة مباشرة بالقسم الفرعي
          .where('status', isEqualTo: 'active')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState();
        }

        final docs = snapshot.data!.docs;

        return GridView.builder(
          padding: EdgeInsets.fromLTRB(3.w, 2.h, 3.w, 15.h),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.68,
            crossAxisSpacing: 3.w,
            mainAxisSpacing: 3.w,
          ),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final offerData = docs[index].data() as Map<String, dynamic>;
            offerData['offerId'] = docs[index].id;

            // 🎯 نستخدم البيانات المحشورة في العرض مباشرة لإلغاء طلبات السيرفر المتكررة
            return _ProductCard(
              offer: offerData,
              productData: {
                'name': offerData['productName'] ?? 'منتج',
                'imageUrls': [offerData['productImage'] ?? ''],
              },
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.category_outlined, size: 70, color: Colors.grey[300]),
          const SizedBox(height: 15),
          const Text("لا توجد منتجات متاحة في هذا القسم حالياً",
              style: TextStyle(color: Colors.grey, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildFloatingCart() {
    return Consumer<CartProvider>(
      builder: (context, cart, _) {
        if (cart.itemCount == 0) return const SizedBox.shrink();
        return FloatingActionButton.extended(
          onPressed: () => Navigator.pushNamed(context, '/cart'),
          backgroundColor: AppTheme.primaryGreen,
          label: Text("سلة المشتريات (${cart.itemCount})",
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          icon: const Icon(Icons.shopping_basket, color: Colors.white),
        );
      },
    );
  }
}

class _ProductCard extends StatelessWidget {
  final Map<String, dynamic> offer;
  final Map<String, dynamic> productData;

  const _ProductCard({required this.offer, required this.productData});

  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<CartProvider>(context);
    final units = offer['units'] as List? ?? [];
    final firstUnit = units.isNotEmpty ? units[0] : {'unitName': 'وحدة', 'price': 0};
    final double price = (firstUnit['price'] as num).toDouble();
    final String pName = productData['name'];
    final List imgs = productData['imageUrls'];

    int quantity = 0;
    var cartItem;
    try {
      cartItem = cart.sellersOrders.values
          .expand((s) => s.items)
          .firstWhere((i) => i.offerId == offer['offerId']);
      quantity = cartItem.quantity;
    } catch (_) {}

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10)],
      ),
      child: Column(
        children: [
          Expanded(
            flex: 5,
            child: Container(
              padding: const EdgeInsets.all(8.0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: imgs.isNotEmpty && imgs[0] != ''
                    ? CachedNetworkImage(
                        imageUrl: imgs[0],
                        fit: BoxFit.contain,
                        placeholder: (context, url) => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                      )
                    : const Icon(Icons.image, color: Colors.grey, size: 40),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              pName,
              maxLines: 2,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const Spacer(),
          Text("$price ج.م",
              style: TextStyle(color: AppTheme.primaryGreen, fontWeight: FontWeight.w900, fontSize: 14)),
          Text(firstUnit['unitName'], style: const TextStyle(color: Colors.grey, fontSize: 10)),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: quantity == 0
                ? InkWell(
                    onTap: () => _addToCart(cart, firstUnit, pName, imgs.isNotEmpty ? imgs[0] : ''),
                    child: Container(
                      height: 35,
                      width: double.infinity,
                      decoration: BoxDecoration(color: AppTheme.primaryGreen, borderRadius: BorderRadius.circular(8)),
                      child: const Center(
                          child: Text("إضافة", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _qtyBtn(Icons.add, () => cart.changeQty(cartItem, 1, 'consumer'), Colors.green),
                      Text("$quantity", style: const TextStyle(fontWeight: FontWeight.bold)),
                      _qtyBtn(Icons.remove, () => cart.changeQty(cartItem, -1, 'consumer'), Colors.red),
                    ],
                  ),
          )
        ],
      ),
    );
  }

  Widget _qtyBtn(IconData icon, VoidCallback tap, Color color) {
    return InkWell(
      onTap: tap,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(border: Border.all(color: color.withOpacity(0.5)), borderRadius: BorderRadius.circular(6)),
        child: Icon(icon, size: 18, color: color),
      ),
    );
  }

  void _addToCart(CartProvider cart, dynamic unit, String name, String img) {
    cart.addItemToCart(
      offerId: offer['offerId'],
      productId: offer['productId'],
      sellerId: offer['ownerId'],
      sellerName: offer['supermarketName'] ?? 'التاجر',
      name: name,
      price: (unit['price'] as num).toDouble(),
      unit: unit['unitName'],
      unitIndex: 0,
      imageUrl: img,
      userRole: 'consumer',
    );
  }
}

