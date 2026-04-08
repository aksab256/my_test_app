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
  final String? ownerId; // معرف التاجر اللي هنجيب عروضه
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
    // الفلترة بناءً على التاجر المختار والحالة النشطة
    Query query = _db.collection('marketOffer')
        .where('ownerId', isEqualTo: widget.ownerId)
        .where('status', isEqualTo: 'active');

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text("لا توجد عروض متاحة لهذا التاجر حالياً"));
        }

        final offers = snapshot.data!.docs;

        return GridView.builder(
          padding: EdgeInsets.fromLTRB(3.w, 2.h, 3.w, 12.h),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.65, // زودنا الطول شوية عشان تفاصيل الوحدات
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

  // ويدجت السلة العائمة (نفس الكود السابق)
  Widget _buildFloatingCart() {
    return Consumer<CartProvider>(
      builder: (context, cart, _) {
        if (cart.itemCount == 0) return const SizedBox.shrink();
        return FloatingActionButton.extended(
          onPressed: () => Navigator.pushNamed(context, '/cart'),
          backgroundColor: AppTheme.primaryGreen,
          label: SizedBox(
            width: 60.w,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("إتمام الطلب", style: TextStyle(color: Colors.white)),
                Text("${cart.itemCount}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ],
            ),
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
    
    // استخراج أول وحدة وسعرها
    final List units = offer['units'] ?? [];
    final firstUnit = units.isNotEmpty ? units[0] : {'unitName': 'وحدة', 'price': 0};
    final double price = (firstUnit['price'] as num).toDouble();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: Column(
        children: [
          // 🖼️ جلب الصورة من كولكشن products بشكل منفصل
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
                return const Center(child: Icon(Icons.image_not_supported, color: Colors.grey));
              },
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: [
                Text(offer['supermarketName'] ?? 'منتج', 
                  maxLines: 1, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                Text(firstUnit['unitName'], 
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 5),
                Text("$price ج.م", 
                  style: TextStyle(color: AppTheme.primaryGreen, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          
          // زرار الإضافة للسلة (مبسط)
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: ElevatedButton(
              onPressed: () {
                cart.addItemToCart(
                  offerId: offer['offerId'],
                  productId: productId,
                  sellerId: offer['ownerId'],
                  sellerName: offer['supermarketName'] ?? 'تاجر',
                  name: firstUnit['unitName'],
                  price: price,
                  unit: firstUnit['unitName'],
                  unitIndex: 0,
                  imageUrl: '', // سيتم تحديثها من السلة
                  userRole: 'consumer',
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryGreen,
                minimumSize: Size(double.infinity, 4.h),
              ),
              child: const Text("إضافة", style: TextStyle(color: Colors.white)),
            ),
          )
        ],
      ),
    );
  }
}

