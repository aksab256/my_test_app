// lib/widgets/product_list_grid.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:my_test_app/widgets/buyer_product_card.dart';
import 'package:my_test_app/providers/product_offers_provider.dart';
import 'package:my_test_app/providers/buyer_data_provider.dart';
import 'package:my_test_app/services/buyer_area_resolver.dart';
import 'package:my_test_app/utils/offer_geo_filter.dart';

/// شبكة منتجات سياق Product Offer Context:
/// منتج واحد -> أسعار Sellers متعددين لهذا المنتج، مع geo-filter.
/// المناطق المستخدمة مكتشفة من GPS المشتري (BuyerAreaResolver) — وليست
/// عنوان الشارع الحر (userAddress) الذي لا يطابق مفردات مناطق التوصيل.
class ProductListGrid extends StatefulWidget {
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
  State<ProductListGrid> createState() => _ProductListGridState();
}

class _ProductListGridState extends State<ProductListGrid> {
  List<String>? _buyerAreas;
  bool _areasLoading = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_buyerAreas == null && _areasLoading) {
      _resolveBuyerAreas();
    }
  }

  Future<void> _resolveBuyerAreas() async {
    final buyer = Provider.of<BuyerDataProvider>(context, listen: false);
    final areas = await BuyerAreaResolver.resolveBuyerAreas(
      lat: buyer.effectiveLat,
      lng: buyer.effectiveLng,
    );
    if (mounted) {
      setState(() {
        _buyerAreas = areas;
        _areasLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.subCategoryId.isEmpty) return const SizedBox.shrink();

    if (_areasLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF43A047)));
    }
    final List<String> userAreas = _buyerAreas ?? const [];

    return StreamBuilder<QuerySnapshot>(
      // 🎯 تحسين: منع إعادة إنشاء الـ Stream في كل Build
      stream: FirebaseFirestore.instance.collection('products')
          .where('subId', isEqualTo: widget.subCategoryId)
          .where('status', isEqualTo: 'active')
          .orderBy('order', descending: false)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFF43A047)));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(child: Text('لا توجد منتجات في ${widget.pageTitle}'));
        }

        // 🎯 تصفية الـ Manufacturer محلياً لو أمكن لتقليل ضغط الـ Query
        var docs = snapshot.data!.docs;
        if (widget.manufacturerId != null) {
          docs = docs.where((d) => d['manufacturerId'] == widget.manufacturerId).toList();
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
                geoContext: OfferListContext.productOffers,
              ),
              child: BuyerProductCard(
                productId: doc.id,
                productData: data,
                onTap: (pid, oid) {
                  Navigator.of(context).pushNamed('/productDetails', arguments: {'productId': pid, 'offerId': oid});
                  widget.onProductTap?.call(pid, oid);
                },
              ),
            );
          },
        );
      },
    );
  }
}
