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
    // 🎯 استلام وتأمين البيانات القادمة من Navigator
    final dynamic rawArgs = ModalRoute.of(context)?.settings.arguments;
    final Map<String, dynamic> args = (rawArgs is Map<String, dynamic>) ? rawArgs : {};

    final String ownerId = args['ownerId'] ?? '';
    final String subId = args['subId'] ?? '';
    final String title = args['subCategoryName'] ?? 'المنتجات';

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FA), // خلفية فاتحة تبرز الكروت
        appBar: BuyerProductHeader(
          title: title,
          isLoading: false,
        ),
        // استخدام SafeArea لمنع التداخل مع حواف الشاشة
        body: SafeArea(
          child: _buildProductGrid(ownerId, subId),
        ),
        
        // 🎯 الشريط السفلي لضمان هوية التطبيق
        bottomNavigationBar: Consumer<CartProvider>(
          builder: (context, cart, _) => ConsumerFooterNav(
            cartCount: cart.itemCount,
            activeIndex: -1, // لا يوجد اختيار نشط لأننا في صفحة فرعية
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
          // 👈 Padding مدروس عشان يملى الشاشة صح
          padding: EdgeInsets.fromLTRB(3.w, 2.h, 3.w, 15.h),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,         // كارتين في الصف الواحد
            childAspectRatio: 0.68,    // 👈 النسبة المثالية لملء الفراغ الطولي
            crossAxisSpacing: 3.w,     // المسافة بين الكروت عرضياً
            mainAxisSpacing: 3.w,      // المسافة بين الكروت طولياً
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

                // الفلترة اليدوية للقسم الفرعي
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
          Icon(Icons.shopping_bag_outlined, size: 70, color: Colors.grey[300]),
          const SizedBox(height: 15),
          Text("عذراً، لا توجد منتجات حالياً", 
            style: TextStyle(color: Colors.grey[500], fontSize: 16, fontWeight: FontWeight.bold)),
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
          elevation: 6,
          label: Text("إتمام الطلب (${cart.itemCount})",
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
          icon: const Icon(Icons.shopping_cart_checkout, color: Colors.white),
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
    final String pName = productData['name'] ?? 'منتج غير معروف';
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
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          // 🖼️ جزء الصورة
          Expanded(
            flex: 5,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8.0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: imgs.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: imgs[0],
                        fit: BoxFit.contain,
                        placeholder: (context, url) => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                        errorWidget: (context, url, error) => const Icon(Icons.error_outline),
                      )
                    : Icon(Icons.image, color: Colors.grey[200], size: 50),
              ),
            ),
          ),
          
          // 📝 تفاصيل المنتج
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
          
          const Spacer(),
          
          // 💰 السعر والوحدة
          Text(
            "$price ج.م",
            style: TextStyle(color: AppTheme.primaryGreen, fontWeight: FontWeight.w900, fontSize: 15),
          ),
          Text(
            firstUnit['unitName'],
            style: TextStyle(color: Colors.grey[600], fontSize: 10),
          ),
          
          const SizedBox(height: 8),

          // 🛒 زر الإضافة أو التحكم في الكمية
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: quantity == 0
                ? InkWell(
                    onTap: () => _addToCart(cart, firstUnit, pName, imgs.isNotEmpty ? imgs[0] : ''),
                    child: Container(
                      height: 38,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryGreen,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Center(
                        child: Text("إضافة للسلة", 
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                      ),
                    ),
                  )
                : Container(
                    height: 38,
                    decoration: BoxDecoration(
                      border: Border.all(color: AppTheme.primaryGreen.withOpacity(0.3)),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _qtyActionBtn(Icons.add, () => cart.changeQty(cartItem, 1, 'consumer'), Colors.green),
                        Text("$quantity", style: const TextStyle(fontWeight: FontWeight.bold)),
                        _qtyActionBtn(Icons.remove, () => cart.changeQty(cartItem, -1, 'consumer'), Colors.red),
                      ],
                    ),
                  ),
          )
        ],
      ),
    );
  }

  Widget _qtyActionBtn(IconData icon, VoidCallback action, Color color) {
    return InkWell(
      onTap: action,
      child: Container(
        width: 35,
        height: 38,
        child: Icon(icon, size: 20, color: color),
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

