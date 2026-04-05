import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:my_test_app/widgets/buyer_product_card.dart';
import 'package:my_test_app/providers/product_offers_provider.dart';
import 'package:my_test_app/providers/buyer_data_provider.dart';

class ProductListGrid extends StatelessWidget {
  final String subCategoryId;
  final String pageTitle;
  final String? manufacturerId;
  final Function(String productId, String? offerId)? onProductTap;

  const ProductListGrid({
    super.key,
    required this.subCategoryId,
    required this.pageTitle,
    this.manufacturerId,
    this.onProductTap,
  });

  // 🎯 تحسين: جعل الـ Stream ثابت ولا يتغير مع كل Build
  Stream<QuerySnapshot> _getProductsStream() {
    Query query = FirebaseFirestore.instance.collection('products')
        .where('subId', isEqualTo: subCategoryId)
        .where('status', isEqualTo: 'active')
        .orderBy('order', descending: false);

    if (manufacturerId != null) {
      query = query.where('manufacturerId', isEqualTo: manufacturerId);
    }
    return query.snapshots();
  }

  @override
  Widget build(BuildContext context) {
    if (subCategoryId.isEmpty) return const Center(child: Text('خطأ في القسم'));

    // 🎯 استخدم select بدلاً من watch عشان الـ Grid ميعملش Rebuild لو بيانات تانية اتغيرت
    final userAddress = context.select<BuyerDataProvider, String?>((p) => p.userAddress);
    List<String> userAreas = userAddress != null ? [userAddress] : [];

    return StreamBuilder<QuerySnapshot>(
      stream: _getProductsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFF43A047)));
        }
        
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(child: Text('لا توجد منتجات في "$pageTitle"'));
        }

        final products = snapshot.data!.docs;

        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 100), // مسافة للشريط السفلي
          itemCount: products.length,
          physics: const BouncingScrollPhysics(), // سكرول أنعم
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 0.55, // تحسين النسبة لشكل أرشق
          ),
          itemBuilder: (context, index) {
            final productDoc = products[index];
            final productData = productDoc.data() as Map<String, dynamic>;

            // 🎯 السر هنا: استخدام key فريد لكل منتج عشان فلاتر ميعيدش رسمه لو مش محتاج
            return ChangeNotifierProvider<ProductOffersProvider>(
              key: ValueKey('prod_${productDoc.id}'), 
              create: (_) => ProductOffersProvider(
                productId: productDoc.id,
                userDetectedAreas: userAreas,
              ),
              child: BuyerProductCard(
                productId: productDoc.id,
                productData: productData,
                onTap: (pid, oid) {
                  Navigator.of(context).pushNamed('/productDetails', arguments: {'productId': pid, 'offerId': oid});
                  onProductTap?.call(pid, oid);
                },
              ),
            );
          },
        );
      },
    );
  }
}

