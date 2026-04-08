import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:sizer/sizer.dart';
import 'package:my_test_app/providers/cart_provider.dart';
import 'package:my_test_app/widgets/buyer_product_header.dart';
import '../../theme/app_theme.dart';

class ConsumerProductListScreen extends StatefulWidget {
  final String mainCategoryId;
  final String subCategoryId;
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
          title: widget.subCategoryName ?? 'المنتجات',
          isLoading: false,
        ),
        floatingActionButton: _buildFloatingCart(),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        body: _buildProductGrid(),
      ),
    );
  }

  Widget _buildProductGrid() {
    // 1️⃣ جلب عروض التاجر فقط بدون تعقيد في الـ Query
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
          return const Center(child: Text("لا توجد عروض متاحة لهذا التاجر"));
        }

        final offers = snapshot.data!.docs;

        return GridView.builder(
          padding: EdgeInsets.fromLTRB(3.w, 2.h, 3.w, 15.h),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.60,
            crossAxisSpacing: 3.w,
            mainAxisSpacing: 3.w,
          ),
          itemCount: offers.length,
          itemBuilder: (context, index) {
            final offerData = offers[index].data() as Map<String, dynamic>;
            offerData['offerId'] = offers[index].id;
            final pId = offerData['productId'] ?? '';

            // 2️⃣ جلب بيانات المنتج لكل عرض بشكل منفصل
            return FutureBuilder<DocumentSnapshot>(
              future: _db.collection('products').doc(pId).get(),
              builder: (context, prodSnap) {
                if (!prodSnap.hasData || !prodSnap.data!.exists) {
                   return const SizedBox.shrink(); 
                }

                final prodData = prodSnap.data!.data() as Map<String, dynamic>;
                
                // 3️⃣ الفلترة بالقسم الفرعي يدوياً (subId)
                if (prodData['subId'] != widget.subCategoryId) {
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
          label: Text("سلة المشتريات (${cart.itemCount})", style: const TextStyle(color: Colors.white)),
          icon: const Icon(Icons.shopping_cart, color: Colors.white),
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
    
    // بيانات العرض
    final List units = offer['units'] ?? [];
    final firstUnit = units.isNotEmpty ? units[0] : {'unitName': 'وحدة', 'price': 0};
    final double price = (firstUnit['price'] as num).toDouble();

    // بيانات المنتج (الصورة والاسم)
    final String name = productData['name'] ?? 'منتج';
    final List imageUrls = productData['imageUrls'] ?? [];
    final String img = imageUrls.isNotEmpty ? imageUrls[0] : '';

    // حساب الكمية في السلة
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
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: Column(
        children: [
          Expanded(
            flex: 4,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: img.isNotEmpty 
                ? Image.network(img, fit: BoxFit.contain)
                : const Icon(Icons.image_not_supported, color: Colors.grey),
            ),
          ),
          Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12), maxLines: 1),
          Text("${firstUnit['unitName']} - $price ج.م", style: TextStyle(color: AppTheme.primaryGreen, fontSize: 11)),
          
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: quantity == 0 
            ? ElevatedButton(
                onPressed: () => _addToCart(cart, firstUnit, name, img),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryGreen,
                  minimumSize: const Size(double.infinity, 35),
                ),
                child: const Text("إضافة", style: TextStyle(color: Colors.white)),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  IconButton(icon: const Icon(Icons.add_circle, color: Colors.green), onPressed: () => cart.changeQty(cartItem, 1, 'consumer')),
                  Text("$quantity", style: const TextStyle(fontWeight: FontWeight.bold)),
                  IconButton(icon: const Icon(Icons.remove_circle, color: Colors.red), onPressed: () => cart.changeQty(cartItem, -1, 'consumer')),
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
      sellerName: offer['supermarketName'] ?? 'تاجر',
      name: name,
      price: (unit['price'] as num).toDouble(),
      unit: unit['unitName'],
      unitIndex: 0,
      imageUrl: img, 
      userRole: 'consumer',
    );
  }
}

