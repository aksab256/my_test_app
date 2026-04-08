import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:sizer/sizer.dart';
import 'package:my_test_app/providers/cart_provider.dart';
import 'package:my_test_app/widgets/buyer_product_header.dart';
import '../../theme/app_theme.dart';

class ConsumerProductListScreen extends StatefulWidget {
  final String mainCategoryId;
  final String subCategoryId; // دي اللي هنقارنها بـ subId في كولكشن المنتجات
  final String? ownerId;
  final String? subCategoryName;
  final String? manufacturerId;

  static const routeName = '/product-list';

  const ConsumerProductListScreen({
    super.key,
    required this.mainCategoryId,
    required this.subCategoryId,
    this.ownerId,
    this.subCategoryName,
    this.manufacturerId,
  });

  @override
  State<ConsumerProductListScreen> createState() => _ConsumerProductListScreenState();
}

class _ConsumerProductListScreenState extends State<ConsumerProductListScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFFBFDFF),
        appBar: BuyerProductHeader(
          title: widget.subCategoryName ?? 'عروض المتجر',
          isLoading: false,
        ),
        floatingActionButton: _buildFloatingCart(),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        body: _buildProductGrid(),
      ),
    );
  }

  Widget _buildProductGrid() {
    // 1️⃣ هنجيب كل عروض التاجر ده الأول
    return StreamBuilder<QuerySnapshot>(
      stream: _db.collection('marketOffer')
          .where('ownerId', isEqualTo: widget.ownerId)
          .where('status', isEqualTo: 'active')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text("لا توجد عروض لهذا التاجر حالياً"));
        }

        final allOffers = snapshot.data!.docs;

        // 2️⃣ نستخدم ListView أو GridView مع FutureBuilder لكل منتج للتحقق من القسم
        return GridView.builder(
          padding: EdgeInsets.fromLTRB(3.w, 2.h, 3.w, 15.h),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.62,
            crossAxisSpacing: 3.w,
            mainAxisSpacing: 3.w,
          ),
          itemCount: allOffers.length,
          itemBuilder: (context, index) {
            final offerData = allOffers[index].data() as Map<String, dynamic>;
            offerData['offerId'] = allOffers[index].id;
            final productId = offerData['productId'] ?? '';

            // 3️⃣ هنا اللعبة: نتحقق إذا كان المنتج يتبع القسم المطلوب
            return FutureBuilder<DocumentSnapshot>(
              future: _db.collection('products').doc(productId).get(),
              builder: (context, prodSnap) {
                if (!prodSnap.hasData || !prodSnap.data!.exists) return const SizedBox.shrink();
                
                final prodData = prodSnap.data!.data() as Map<String, dynamic>;
                
                // الفلترة بالقسم الفرعي (subId في كولكشن products)
                if (prodData['subId'] != widget.subCategoryId) {
                  return const SizedBox.shrink(); // لو مش نفس القسم، أخفيه
                }

                return _ProductCard(
                  offer: offerData, 
                  productImageUrl: (prodData['imageUrls'] as List?)?.first ?? '',
                  productName: prodData['name'] ?? 'منتج',
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildFloatingCart() {
    return Consumer<CartProvider>(
      builder: (context, cart, _) {
        if (cart.itemCount == 0) return const SizedBox.shrink();
        return FloatingActionButton.extended(
          onPressed: () => Navigator.pushNamed(context, '/cart'),
          backgroundColor: AppTheme.primaryGreen,
          label: Text("عرض السلة (${cart.itemCount})", 
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          icon: const Icon(Icons.shopping_basket, color: Colors.white),
        );
      },
    );
  }
}

class _ProductCard extends StatelessWidget {
  final Map<String, dynamic> offer;
  final String productImageUrl;
  final String productName;

  const _ProductCard({
    required this.offer, 
    required this.productImageUrl,
    required this.productName,
  });

  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<CartProvider>(context);
    final List units = offer['units'] ?? [];
    final firstUnit = units.isNotEmpty ? units[0] : {'unitName': 'وحدة', 'price': 0};
    final double price = (firstUnit['price'] as num).toDouble();

    // البحث عن المنتج في السلة
    var cartItem;
    try {
      cartItem = cart.sellersOrders.values
          .expand((seller) => seller.items)
          .firstWhere((item) => item.offerId == offer['offerId']);
    } catch (_) { cartItem = null; }
    
    final int quantity = cartItem != null ? cartItem.quantity : 0;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5)],
      ),
      child: Column(
        children: [
          Expanded(
            flex: 4,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: productImageUrl.isNotEmpty 
                ? Image.network(productImageUrl, fit: BoxFit.contain)
                : const Icon(Icons.image, color: Colors.grey),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: Column(
              children: [
                Text(productName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11), maxLines: 1),
                Text("${firstUnit['unitName']}", style: const TextStyle(fontSize: 10, color: Colors.grey)),
                Text("$price ج.م", style: TextStyle(color: AppTheme.primaryGreen, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: quantity == 0 
              ? ElevatedButton(
                  onPressed: () => _addToCart(cart, firstUnit),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryGreen,
                    minimumSize: const Size(double.infinity, 32),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text("إضافة", style: TextStyle(color: Colors.white, fontSize: 12)),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton(icon: const Icon(Icons.add_circle, color: Colors.green, size: 28), 
                      onPressed: () => cart.changeQty(cartItem, 1, 'consumer')),
                    Text("$quantity", style: const TextStyle(fontWeight: FontWeight.bold)),
                    IconButton(icon: const Icon(Icons.remove_circle, color: Colors.red, size: 28), 
                      onPressed: () => cart.changeQty(cartItem, -1, 'consumer')),
                  ],
                ),
          )
        ],
      ),
    );
  }

  void _addToCart(CartProvider cart, dynamic unit) {
    cart.addItemToCart(
      offerId: offer['offerId'],
      productId: offer['productId'],
      sellerId: offer['ownerId'],
      sellerName: offer['supermarketName'] ?? 'التاجر',
      name: productName,
      price: (unit['price'] as num).toDouble(),
      unit: unit['unitName'],
      unitIndex: 0,
      imageUrl: productImageUrl, 
      userRole: 'consumer',
    );
  }
}

