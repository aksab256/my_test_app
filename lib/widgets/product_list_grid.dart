// lib/widgets/product_list_grid.dart
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

  @override
  Widget build(BuildContext context) {
    if (subCategoryId.isEmpty) return const SizedBox.shrink();

    // 🎯 استخدم select عشان نراقب فقط العنوان، مش كل بيانات المشتري
    final userAddress = context.select<BuyerDataProvider, String?>((p) => p.userAddress);
    final List<String> userAreas = userAddress != null ? [userAddress] : [];

    return StreamBuilder<QuerySnapshot>(
      // 🎯 تحسين: منع إعادة إنشاء الـ Stream في كل Build
      stream: FirebaseFirestore.instance.collection('products')
          .where('subId', isEqualTo: subCategoryId)
          .where('status', isEqualTo: 'active')
          .orderBy('order', descending: false)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFF43A047)));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(child: Text('لا توجد منتجات في $pageTitle'));
        }

        // 🎯 تصفية الـ Manufacturer محلياً لو أمكن لتقليل ضغط الـ Query
        var docs = snapshot.data!.docs;
        if (manufacturerId != null) {
          docs = docs.where((d) => d['manufacturerId'] == manufacturerId).toList();
        }

        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 110),
          itemCount: docs.length,
          // 🎯 إضافة cacheExtent بيخلي السكرول ناعم جداً وبيمنع الـ ANR
          cacheExtent: 1000, 
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.54, 
          ),
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;

            return ChangeNotifierProvider<ProductOffersProvider>(
              // 🎯 الـ Key هنا هو اللي هيمنع الـ nativePollOnce لأنه بيحافظ على الـ Widget
              key: PageStorageKey('prod_${doc.id}'),
              create: (_) => ProductOffersProvider(
                productId: doc.id,
                userDetectedAreas: userAreas,
              ),
              child: BuyerProductCard(
                productId: doc.id,
                productData: data,
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

