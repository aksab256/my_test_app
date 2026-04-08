import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:sizer/sizer.dart';
import 'package:my_test_app/providers/cart_provider.dart';
import 'package:my_test_app/widgets/buyer_product_header.dart';
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
    // 🎯 تأمين استلام البيانات لمنع الشاشة الرصاصي
    final dynamic rawArgs = ModalRoute.of(context)?.settings.arguments;
    final Map<String, dynamic> args = (rawArgs is Map<String, dynamic>) ? rawArgs : {};

    final String ownerId = args['ownerId'] ?? '';
    final String subId = args['subId'] ?? '';
    final String title = args['subCategoryName'] ?? 'المنتجات';

    // لو مفيش بيانات، بنعرض رسالة بدل ما الشاشة تضرب
    if (ownerId.isEmpty && subId.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text("المنتجات")),
        body: const Center(child: Text("برجاء اختيار قسم لعرض منتجاته")),
      );
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFFBFDFF),
        appBar: BuyerProductHeader(
          title: title,
          isLoading: false,
        ),
        body: _buildProductGrid(ownerId, subId),
        floatingActionButton: _buildFloatingCart(),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      ),
    );
  }

  Widget _buildProductGrid(String ownerId, String subId) {
    return StreamBuilder<QuerySnapshot>(
      // نجلب عروض التاجر النشطة
      stream: _db.collection('marketOffer')
          .where('ownerId', isEqualTo: ownerId)
          .where('status', isEqualTo: 'active')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text("لا توجد منتجات متاحة لهذا التاجر"));
        }

        final offers = snapshot.data!.docs;

        return GridView.builder(
          padding: EdgeInsets.fromLTRB(3.w, 2.h, 3.w, 15.h),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.62,
            crossAxisSpacing: 3.w,
            mainAxisSpacing: 3.w,
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

                // الفلترة لضمان عرض منتجات القسم المختار فقط
                if (subId.isNotEmpty && prodData['subId'] != subId) {
                  return const SizedBox.shrink();
                }

                return _ProductCard(
                  offer: offerData,
                  productData: prodData,
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
        borderRadius: BorderRadius.circular(15),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5)],
      ),
      child: Column(
        children: [
          Expanded(
            flex: 4,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: imgs.isNotEmpty
                  ? Image.network(imgs[0], fit: BoxFit.contain)
                  : const Icon(Icons.image, color: Colors.grey, size: 40),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(pName,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ),
          Text("${firstUnit['unitName']} - $price ج.م",
              style: TextStyle(color: AppTheme.primaryGreen, fontSize: 10, fontWeight: FontWeight.bold)),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: quantity == 0
                ? ElevatedButton(
                    onPressed: () => _addToCart(cart, firstUnit, pName, imgs.isNotEmpty ? imgs[0] : ''),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryGreen,
                      minimumSize: const Size(double.infinity, 35),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text("إضافة", style: TextStyle(color: Colors.white)),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      IconButton(
                          icon: const Icon(Icons.add_circle, color: Colors.green),
                          onPressed: () => cart.changeQty(cartItem, 1, 'consumer')),
                      Text("$quantity", style: const TextStyle(fontWeight: FontWeight.bold)),
                      IconButton(
                          icon: const Icon(Icons.remove_circle, color: Colors.red),
                          onPressed: () => cart.changeQty(cartItem, -1, 'consumer')),
                    ],
                  ),
          )
        ],
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

