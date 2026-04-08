import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:sizer/sizer.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:my_test_app/providers/cart_provider.dart';
import 'package:my_test_app/widgets/buyer_product_header.dart';
import 'package:my_test_app/screens/consumer/consumer_widgets.dart'; // عشان الشريط السفلي
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
    // 🎯 استلام وتأمين البيانات
    final dynamic rawArgs = ModalRoute.of(context)?.settings.arguments;
    final Map<String, dynamic> args = (rawArgs is Map<String, dynamic>) ? rawArgs : {};

    final String ownerId = args['ownerId'] ?? '';
    final String subId = args['subId'] ?? '';
    final String title = args['subCategoryName'] ?? 'المنتجات';

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7F9), // لون خلفية التطبيقات الهادئ
        appBar: BuyerProductHeader(
          title: title,
          isLoading: false,
        ),
        // 💡 إضافة الـ Body مع SafeArea لضمان عدم التداخل مع الحواف
        body: SafeArea(
          child: _buildProductGrid(ownerId, subId),
        ),
        
        // 🎯 إضافة الشريط السفلي عشان الصفحة تحسس المستخدم إنه لسه جوه التطبيق
        bottomNavigationBar: Consumer<CartProvider>(
          builder: (context, cart, _) => ConsumerFooterNav(
            cartCount: cart.itemCount,
            activeIndex: -1, // عشان ميبقاش فيه زرار منور لأننا في صفحة فرعية
          ),
        ),
        
        floatingActionButton: _buildFloatingCart(),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      ),
    );
  }

  Widget _buildProductGrid(String ownerId, String subId) {
    return StreamBuilder<QuerySnapshot>(
      stream: _db.collection('marketOffer')
          .where('ownerId', isEqualTo: ownerId)
          .where('status', isEqualTo: 'active')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState();
        }

        final offers = snapshot.data!.docs;

        return GridView.builder(
          padding: EdgeInsets.fromLTRB(4.w, 2.h, 4.w, 12.h),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.72, // ضبط التوازن بين الطول والعرض
            crossAxisSpacing: 4.w,
            mainAxisSpacing: 4.w,
          ),
          itemCount: offers.length,
          itemBuilder: (context, index) {
            final offerData = offers[index].data() as Map<String, dynamic>;
            offerData['offerId'] = offers[index].id;
            final pId = offerData['productId'] ?? '';

            return FutureBuilder<DocumentSnapshot>(
              future: _db.collection('products').doc(pId).get(),
              builder: (context, prodSnap) {
                if (!prodSnap.hasData || !prodSnap.data!.exists) return const SizedBox.shrink();
                final prodData = prodSnap.data!.data() as Map<String, dynamic>;

                if (subId.isNotEmpty && prodData['subId'] != subId) {
                  return const SizedBox.shrink();
                }

                return _ProductCard(offer: offerData, productData: prodData);
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
          Icon(Icons.inventory_2_outlined, size: 60, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text("لا توجد منتجات حالياً", style: TextStyle(color: Colors.grey[600], fontSize: 16)),
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
          elevation: 4,
          label: Text("إتمام الطلب (${cart.itemCount})",
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
          icon: const Icon(Icons.shopping_basket_outlined, color: Colors.white),
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
    final String pName = productData['name'] ?? 'منتج';
    final List imgs = productData['imageUrls'] as List? ?? [];

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
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: imgs.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: imgs[0],
                        fit: BoxFit.contain,
                        placeholder: (context, url) => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                      )
                    : Icon(Icons.image_not_supported_outlined, color: Colors.grey[300], size: 40),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              pName,
              maxLines: 2,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, height: 1.2),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "$price ج.م",
            style: TextStyle(color: AppTheme.primaryGreen, fontWeight: FontWeight.w900, fontSize: 14),
          ),
          Text(
            firstUnit['unitName'],
            style: TextStyle(color: Colors.grey[500], fontSize: 10),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: quantity == 0
                ? InkWell(
                    onTap: () => _addToCart(cart, firstUnit, pName, imgs.isNotEmpty ? imgs[0] : ''),
                    child: Container(
                      height: 35,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryGreen,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Center(
                        child: Text("إضافة", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
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
        decoration: BoxDecoration(
          border: Border.all(color: color.withOpacity(0.5)),
          borderRadius: BorderRadius.circular(6),
        ),
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

