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
    // الفلترة بالتاجر + القسم الفرعي + الحالة
    Query query = _db.collection('marketOffer')
        .where('ownerId', isEqualTo: widget.ownerId)
        .where('subCategoryId', isEqualTo: widget.subCategoryId)
        .where('status', isEqualTo: 'active');

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text("لا توجد عروض متاحة لهذا القسم حالياً"));
        }

        final offers = snapshot.data!.docs;

        return GridView.builder(
          padding: EdgeInsets.fromLTRB(3.w, 2.h, 3.w, 12.h),
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
            return _ProductCard(offer: offerData);
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
          icon: const Icon(Icons.shopping_cart, color: Colors.white),
          label: Row(
            children: [
              const Text("عرض السلة", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                child: Text("${cart.itemCount}", 
                  style: TextStyle(color: AppTheme.primaryGreen, fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ProductCard extends StatelessWidget {
  final Map<String, dynamic> offer;
  const _ProductCard({required this.offer});

  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<CartProvider>(context);
    final productId = offer['productId'] ?? '';
    
    final List units = offer['units'] ?? [];
    final firstUnit = units.isNotEmpty ? units[0] : {'unitName': 'وحدة', 'price': 0};
    final double price = (firstUnit['price'] as num).toDouble();

    // البحث عن المنتج في السلة لمعرفة الكمية
    final cartItem = cart.sellersOrders.values
        .expand((seller) => seller.items)
        .firstWhere((item) => item.offerId == offer['offerId'], orElse: () => null as dynamic);
    
    final int quantity = cartItem != null ? cartItem.quantity : 0;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
        border: Border.all(color: quantity > 0 ? AppTheme.primaryGreen : Colors.transparent, width: 1),
      ),
      child: Column(
        children: [
          Expanded(
            flex: 5,
            child: FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance.collection('products').doc(productId).get(),
              builder: (context, snap) {
                if (snap.hasData && snap.data!.exists) {
                  final prodData = snap.data!.data() as Map<String, dynamic>;
                  return Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Image.network(prodData['imageUrl'] ?? '', fit: BoxFit.contain),
                  );
                }
                return const Center(child: Icon(Icons.image, color: Colors.grey));
              },
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Column(
              children: [
                Text(offer['supermarketName'] ?? 'متجر', 
                  maxLines: 1, style: const TextStyle(fontSize: 10, color: Colors.grey, overflow: TextOverflow.ellipsis)),
                Text(firstUnit['unitName'], 
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), maxLines: 1),
                Text("$price ج.م", 
                  style: TextStyle(color: AppTheme.primaryGreen, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: quantity == 0 
            ? ElevatedButton(
                onPressed: () => _addToCart(cart, firstUnit, productId),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryGreen,
                  minimumSize: Size(double.infinity, 4.h),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text("إضافة", style: TextStyle(color: Colors.white)),
              )
            : Container(
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.add_circle, color: Colors.green),
                      onPressed: () => cart.changeQty(cartItem, 1, 'consumer'),
                    ),
                    Text("$quantity", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    IconButton(
                      icon: const Icon(Icons.remove_circle, color: Colors.red),
                      onPressed: () => cart.changeQty(cartItem, -1, 'consumer'),
                    ),
                  ],
                ),
              ),
          )
        ],
      ),
    );
  }

  void _addToCart(CartProvider cart, dynamic unit, String productId) {
    cart.addItemToCart(
      offerId: offer['offerId'],
      productId: productId,
      sellerId: offer['ownerId'],
      sellerName: offer['supermarketName'] ?? 'تاجر',
      name: unit['unitName'],
      price: (unit['price'] as num).toDouble(),
      unit: unit['unitName'],
      unitIndex: 0,
      imageUrl: '', 
      userRole: 'consumer',
    );
  }
}

