// lib/widgets/product_list_grid.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:my_test_app/widgets/buyer_product_card.dart';
import 'package:my_test_app/providers/product_offers_provider.dart';
import 'package:my_test_app/providers/buyer_data_provider.dart';
import 'package:my_test_app/utils/offer_geo_filter.dart';
import 'package:my_test_app/utils/seller_geo.dart';

/// شبكة منتجات سياق Product Offer Context:
/// منتج واحد -> أسعار Sellers متعددين لهذا المنتج، مع geo-filter.
/// عقد الإحداثيات: نقطة GPS المشتري ضد مضلعات الملف — بلا أسماء.
/// قاعدة العرض: المنتج بلا عرض سعر واحد ظاهر على الأقل لا يظهر أصلاً.
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
  double? _buyerLat;
  double? _buyerLng;
  bool _geoReady = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_geoReady) {
      _warmGeo();
    }
  }

  Future<void> _warmGeo() async {
    final buyer = Provider.of<BuyerDataProvider>(context, listen: false);
    final lat = buyer.effectiveLat;
    final lng = buyer.effectiveLng;
    try {
      await SellerGeo.ensureLoaded();
    } catch (_) {}
    if (mounted) {
      setState(() {
        _buyerLat = lat;
        _buyerLng = lng;
        _geoReady = true;
      });
    }
  }

  /// معرفات المنتجات التي تملك عرض سعر واحداً ظاهراً على الأقل
  /// (نشط + داخل مضلعات نقطة المشتري). دفعات whereIn حتى 10.
  Future<Set<String>> _visibleProductIds(List<String> ids) async {
    if (ids.isEmpty) return const {};
    final out = <String>{};
    for (var i = 0; i < ids.length; i += 10) {
      final chunk = ids.sublist(i, i + 10 > ids.length ? ids.length : i + 10);
      final snap = await FirebaseFirestore.instance
          .collection('productOffers')
          .where('productId', whereIn: chunk)
          .where('status', isEqualTo: 'active')
          .get();
      for (final doc in snap.docs) {
        final data = doc.data();
        final pid = (data['productId'] ?? '').toString();
        if (pid.isEmpty || out.contains(pid)) continue;
        if (await SellerGeo.isOfferVisibleByCoords(
          offerData: data,
          buyerLat: _buyerLat,
          buyerLng: _buyerLng,
          context: OfferListContext.productOffers,
        )) {
          out.add(pid);
        }
      }
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.subCategoryId.isEmpty) return const SizedBox.shrink();

    if (!_geoReady) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF43A047)));
    }

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

        return FutureBuilder<Set<String>>(
          future: _visibleProductIds(docs.map((d) => d.id).toList()),
          builder: (context, visSnap) {
            if (visSnap.connectionState == ConnectionState.waiting) {
              return const Center(
                  child: CircularProgressIndicator(color: Color(0xFF43A047)));
            }
            final visible = visSnap.data ?? const <String>{};
            // الفحص مكتمل هنا (الانتظار أعلاه سبينر): الفارغ = بلا عروض ظاهرة.
            final gated =
                docs.where((d) => visible.contains(d.id)).toList();
            if (gated.isEmpty) {
              return const Center(
                  child: Text('لا توجد منتجات بعروض متاحة لمنطقتك حالياً.'));
            }
            return GridView.builder(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 110),
              itemCount: gated.length,
              // 🎯 إضافة cacheExtent بيخلي السكرول ناعم جداً وبيمنع الـ ANR
              cacheExtent: 1000,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.54,
              ),
              itemBuilder: (context, index) {
                final doc = gated[index];
                final data = doc.data() as Map<String, dynamic>;

                return ChangeNotifierProvider<ProductOffersProvider>(
                  // 🎯 الـ Key هنا هو اللي هيمنع الـ nativePollOnce لأنه بيحافظ على الـ Widget
                  key: PageStorageKey('prod_${doc.id}'),
                  create: (_) => ProductOffersProvider(
                    productId: doc.id,
                    buyerLat: _buyerLat,
                    buyerLng: _buyerLng,
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
      },
    );
  }
}
