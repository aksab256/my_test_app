import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:sizer/sizer.dart';
import 'package:my_test_app/providers/cart_provider.dart';
import 'package:my_test_app/widgets/manufacturers_banner.dart';
import 'package:my_test_app/widgets/buyer_product_header.dart';
import '../../theme/app_theme.dart';

class ConsumerProductListScreen extends StatefulWidget {
  final String mainCategoryId; // مطابقة للي بيبعته الماين
  final String subCategoryId;  // مطابقة للي بيبعته الماين
  final String? ownerId;
  final String? subCategoryName;

  static const routeName = '/product-list';

  const ConsumerProductListScreen({
    super.key,
    required this.mainCategoryId,
    required this.subCategoryId,
    this.ownerId,
    this.subCategoryName,
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
        // السلة العائمة بديلة الشريط السفلي
        floatingActionButton: _buildFloatingCart(),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        body: Column(
          children: [
            ManufacturersBanner(
              subCategoryId: widget.subCategoryId,
              onManufacturerSelected: (id) {
                if (id == 'ALL') Navigator.of(context).pop();
              },
            ),
            const Divider(height: 1),
            Expanded(
              child: _buildProductGrid(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductGrid() {
    Query query = _db.collection('products')
        .where('subCategoryId', isEqualTo: widget.subCategoryId)
        .where('status', isEqualTo: 'active');

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text("لا توجد منتجات حالياً"));
        }

        final products = snapshot.data!.docs;

        return GridView.builder(
          padding: EdgeInsets.fromLTRB(3.w, 2.h, 3.w, 12.h),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.70,
            crossAxisSpacing: 3.5.w,
            mainAxisSpacing: 3.5.w,
          ),
          itemCount: products.length,
          itemBuilder: (context, index) {
            final data = products[index].data() as Map<String, dynamic>;
            data['id'] = products[index].id;
            return _ProductCard(product: data);
          },
        );
      },
    );
  }

  Widget _buildFloatingCart() {
    return Consumer<CartProvider>(
      builder: (context, cart, _) {
        if (cart.itemCount == 0) return const SizedBox.shrink();
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          child: FloatingActionButton.extended(
            onPressed: () => Navigator.pushNamed(context, '/cart'),
            backgroundColor: AppTheme.primaryGreen,
            elevation: 8,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            label: SizedBox(
              width: 65.w,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("عرض السلة وإتمام الطلب", 
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white)),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(color: Colors.white24, shape: BoxShape.circle),
                    child: Text("${cart.itemCount}", 
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ProductCard extends StatelessWidget {
  final Map<String, dynamic> product;
  const _ProductCard({required this.product});

  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<CartProvider>(context);
    
    // الربط مع البروفيدر الخاص بك
    final cartItemIndex = cart.sellersOrders.values
        .expand((seller) => seller.items)
        .where((item) => item.productId == product['id'])
        .toList();
    
    final int quantity = cartItemIndex.isNotEmpty ? cartItemIndex.first.quantity : 0;
    final CartItem? currentItem = cartItemIndex.isNotEmpty ? cartItemIndex.first : null;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
      ),
      child: Column(
        children: [
          Expanded(
            flex: 10,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Image.network(product['imageUrl'] ?? '', fit: BoxFit.contain),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Text(product['name'] ?? '', maxLines: 2, textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          ),
          const Spacer(),
          Text("${product['price']} ج.م", 
            style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryGreen)),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: _buildAddButton(context, cart, quantity, currentItem),
          ),
        ],
      ),
    );
  }

  Widget _buildAddButton(BuildContext context, CartProvider cart, int qty, CartItem? item) {
    if (qty == 0) {
      return SizedBox(
        width: double.infinity,
        height: 4.h,
        child: ElevatedButton(
          onPressed: () {
            cart.addItemToCart(
              offerId: product['id'],
              productId: product['id'],
              sellerId: product['ownerId'] ?? '',
              sellerName: product['ownerName'] ?? 'تاجر',
              name: product['name'] ?? '',
              price: (product['price'] as num).toDouble(),
              unit: product['unit'] ?? 'وحدة',
              unitIndex: 0,
              imageUrl: product['imageUrl'] ?? '',
              userRole: 'consumer',
            ).catchError((e) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()))));
          },
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryGreen, elevation: 0),
          child: const Text("إضافة", style: TextStyle(color: Colors.white)),
        ),
      );
    } else {
      return Container(
        height: 4.h,
        decoration: BoxDecoration(
          color: AppTheme.primaryGreen.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(icon: Icon(Icons.add, size: 18, color: AppTheme.primaryGreen), 
              onPressed: () => cart.changeQty(item!, 1, 'consumer')),
            Text("$qty", style: const TextStyle(fontWeight: FontWeight.bold)),
            IconButton(icon: const Icon(Icons.remove, size: 18, color: Colors.red), 
              onPressed: () => cart.changeQty(item!, -1, 'consumer')),
          ],
        ),
      );
    }
  }
}

