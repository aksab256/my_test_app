import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:my_test_app/data_sources/bundle_data_source.dart';
import 'package:my_test_app/models/bundle_model.dart';
import 'package:my_test_app/providers/buyer_data_provider.dart';

/// All-bundles explorer: editorial magazine layout grouped by seller.
/// Big stacked cards (no dense grid); each group carries the seller identity.
class AllBundlesScreen extends StatefulWidget {
  /// Test seam: when provided, no Firestore read happens.
  final List<SellerBundleModel>? bundles;

  const AllBundlesScreen({super.key, this.bundles});

  @override
  State<AllBundlesScreen> createState() => _AllBundlesScreenState();
}

class _AllBundlesScreenState extends State<AllBundlesScreen> {
  late Future<List<SellerBundleModel>> _future;

  @override
  void initState() {
    super.initState();
    if (widget.bundles != null) {
      _future = Future.value(widget.bundles);
    } else {
      final buyer =
          Provider.of<BuyerDataProvider>(context, listen: false);
      _future = BundleDataSource().loadActiveBundlesForBuyer(
        buyerLat: buyer.effectiveLat,
        buyerLng: buyer.effectiveLng,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('استكشف الباقات')),
      body: FutureBuilder<List<SellerBundleModel>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final bundles = snap.data ?? [];
          if (bundles.isEmpty) {
            return const Center(
                child: Text('لا توجد باقات متاحة لمنطقتك حاليًا.'));
          }
          final groups = <String, List<SellerBundleModel>>{};
          for (final b in bundles) {
            groups.putIfAbsent(b.sellerId, () => []).add(b);
          }
          final sellerIds = groups.keys.toList();
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: sellerIds.length,
            itemBuilder: (context, gi) {
              final list = groups[sellerIds[gi]]!;
              final first = list.first;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sellerHeader(first),
                  const SizedBox(height: 8),
                  for (final b in list) ...[
                    _bigCard(context, b),
                    const SizedBox(height: 14),
                  ],
                  const SizedBox(height: 12),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _sellerHeader(SellerBundleModel first) {
    final zones = first.deliveryZones;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(first.sellerName,
            style:
                const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
        Text(
            zones.isEmpty
                ? 'توصيل لجميع المناطق'
                : 'مناطق التوصيل: ${zones.take(3).join('، ')}${zones.length > 3 ? '…' : ''}',
            style:
                const TextStyle(color: Colors.black54, fontSize: 12)),
        const Divider(),
      ],
    );
  }

  Widget _bigCard(BuildContext context, SellerBundleModel b) {
    final cover = b.coverImageUrl ??
        (b.items.isNotEmpty ? b.items.first.imageUrl : null);
    return Card(
      key: Key('bundle-card-${b.id}'),
      clipBehavior: Clip.antiAlias,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () =>
            Navigator.of(context).pushNamed('/bundleDetails', arguments: b.id),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (cover != null && cover.isNotEmpty)
              Image.network(cover,
                  height: 190,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      Container(height: 190, color: Colors.green.shade900))
            else
              Container(height: 120, color: Colors.green.shade900),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(b.bundleName,
                      style: const TextStyle(
                          fontWeight: FontWeight.w900, fontSize: 17)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text('${b.totalPrice.toStringAsFixed(0)} ج.م',
                          style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                              color: Theme.of(context)
                                  .colorScheme
                                  .primary)),
                      const SizedBox(width: 8),
                      Text('${b.originalTotal.toStringAsFixed(0)} ج.م',
                          style: const TextStyle(
                              decoration: TextDecoration.lineThrough,
                              color: Colors.grey)),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.green.shade700,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                            'وفّر ${b.saving.toStringAsFixed(0)} ج.م',
                            style: const TextStyle(
                                color: Colors.white, fontSize: 12)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                      '${b.items.length} منتجات • المتاح: ${b.sellableNow}',
                      style: const TextStyle(
                          color: Colors.black54, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
