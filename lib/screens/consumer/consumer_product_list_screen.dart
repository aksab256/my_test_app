import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:sizer/sizer.dart';
import 'package:my_test_app/providers/cart_provider.dart';
import 'package:my_test_app/widgets/manufacturers_banner.dart';
import 'package:my_test_app/widgets/buyer_product_header.dart';
import '../../theme/app_theme.dart';

class ConsumerProductListScreen extends StatefulWidget {
  final String mainCategoryId;
  final String subCategoryId;
  final String? manufacturerId;
  final String? ownerId;

  static const routeName = '/product-list';

  const ConsumerProductListScreen({
    super.key,
    required this.mainCategoryId,
    required this.subCategoryId,
    this.manufacturerId,
    this.ownerId,
  });

  @override
  State<ConsumerProductListScreen> createState() => _ConsumerProductListScreenState();
}

class _ConsumerProductListScreenState extends State<ConsumerProductListScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  String _pageTitle = 'تحميل...';
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
          _pageTitle = docSnapshot.data()?['name'] ?? 'المنتجات';
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
        backgroundColor: const Color(0xFFFBFDFF),
        appBar: BuyerProductHeader(
          title: _pageTitle,
          isLoading: _isLoading,
        ),
        // سلة عائمة بتصميم عصري تظهر فقط عند وجود أصناف
        floatingActionButton: _buildFloatingCart(),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        body: Column(
          children: [
            ManufacturersBanner(
              subCategoryId: widget.subCategoryId,
              onManufacturerSelected: (id) {
                if (id == 'ALL') {
                  Navigator.of(context).pop();
                }
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

    if (widget.manufacturerId != null) {
      query = query.where('manufacturerId', isEqualTo: widget.manufacturerId);
    }

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text("لا توجد منتجات حالياً في هذا القسم"));
        }

        final products = snapshot.data!.docs;

        return GridView.builder(
          padding: EdgeInsets.fromLTRB(3.w, 2.h, 3.w, 12.h), 
          physics: const BouncingScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.70, // تناسب ثابت لضمان رص الكروت "مسطرة"
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
              width: 60.w,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("إتمام الطلب", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(color: Colors.white24, shape: BoxShape.circle),
                    child: Text("${cart.itemCount}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
            icon: const Icon(Icons.shopping_basket_rounded, color: Colors.white),
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
    
    // الربط مع هيكل بيانات الـ Provider الخاص بك (sellersOrders -> items)
    final cartItemIndex = cart.sellersOrders.values
        .expand((seller) => seller.items)
        .where((item) => item.productId == product['id'])
        .toList();
    
    final int quantity = cartItemIndex.isNotEmpty ? cartItemIndex.first.quantity : 0;
    final CartItem? currentItem = cartItemIndex.isNotEmpty ? cartItemIndex.first : null;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 12,
            child: Stack(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(15),
                    child: Image.network(
                      product['imageUrl'] ?? '',
                      fit: BoxFit.contain,
                      cacheWidth: 300, // تقليل استهلاك الرام
                    ),
                  ),
                ),
                if (product['discount'] != null)
                  Positioned(
                    right: 10, top: 10,
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(8)),
                      child: const Text("خصم", style: TextStyle(color: Colors.white, fontSize: 10)),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 3.w),
            child: Text(
              product['name'] ?? '',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, height: 1.2),
            ),
          ),
          const Spacer(),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 3.w),
            child: Text(
              "${product['price']} ج.م",
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: AppTheme.primaryGreen),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(2.w),
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
            // الربط مع دالة addItemToCart في البروفيدر الخاص بك
            cart.addItemToCart(
              offerId: product['id'],
              productId: product['id'],
              sellerId: product['ownerId'] ?? '',
              sellerName: product['ownerName'] ?? 'تاجر',
              name: product['name'] ?? '',
              price: (product['price'] as num).toDouble(),
              unit: product['unit'] ?? 'قطعة',
              unitIndex: 0, 
              imageUrl: product['imageUrl'] ?? '',
              userRole: 'consumer', // تحديد الـ Role كما يطلبه البروفيدر
              subId: product['subCategoryId'],
              mainId: product['mainCategoryId'],
            ).catchError((e) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
            });
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryGreen,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text("إضافة", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
        ),
      );
    } else {
      return Container(
        height: 4.h,
        decoration: BoxDecoration(
          color: AppTheme.primaryGreen.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.primaryGreen.withOpacity(0.2)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: Icon(Icons.add_circle, color: AppTheme.primaryGreen, size: 20),
              onPressed: () => cart.changeQty(item!, 1, 'consumer'),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            Text("$qty", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            IconButton(
              icon: Icon(Icons.remove_circle, color: Colors.redAccent.withOpacity(0.8), size: 20),
              onPressed: () => cart.changeQty(item!, -1, 'consumer'),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      );
    }
  }
}

