import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:my_test_app/data_sources/bundle_data_source.dart';
import 'package:my_test_app/models/bundle_model.dart';
import 'package:my_test_app/providers/buyer_data_provider.dart';
import 'package:my_test_app/providers/cart_provider.dart';

/// One bundle, fully explained: hero cover, prices, every component with
/// its required quantity, the single-offer notice, and live availability.
class BundleDetailsScreen extends StatefulWidget {
  /// Test seam: when provided, no Firestore read happens.
  final SellerBundleModel? bundle;
  final String? bundleId;

  const BundleDetailsScreen({super.key, this.bundle, this.bundleId});

  @override
  State<BundleDetailsScreen> createState() => _BundleDetailsScreenState();
}

class _BundleDetailsScreenState extends State<BundleDetailsScreen> {
  Future<SellerBundleModel?>? _future;
  int _qty = 1;
  bool _adding = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    if (widget.bundle != null) {
      _future = Future.value(widget.bundle);
    } else {
      _future = BundleDataSource().loadBundle(widget.bundleId ?? '');
    }
  }

  Future<void> _addToCart(SellerBundleModel b) async {
    setState(() {
      _adding = true;
      _message = null;
    });
    try {
      final cart = Provider.of<CartProvider>(context, listen: false);
      final buyer =
          Provider.of<BuyerDataProvider>(context, listen: false);
      final sellable = await BundleDataSource()
          .loadBundleSellable(b.id ?? '');
      if (sellable < _qty) {
        setState(() => _message = 'المتاح من هذه الباقة: $sellable فقط');
        return;
      }
      await cart.addBundleToCart(
        bundleId: b.id ?? '',
        sellerId: b.sellerId,
        sellerName: b.sellerName,
        bundleName: b.bundleName,
        bundlePrice: b.totalPrice,
        bundleOriginalTotal: b.originalTotal,
        imageUrl: b.coverImageUrl ??
            (b.items.isNotEmpty ? b.items.first.imageUrl ?? '' : ''),
        itemsSnapshot: b.items.map((e) => e.toMap()).toList(),
        deliveryZones: b.deliveryZones,
        quantityToAdd: _qty,
        userRole: 'buyer',
        buyerLat: buyer.effectiveLat,
        buyerLng: buyer.effectiveLng,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تمت إضافة الباقة إلى السلة')));
      Navigator.of(context).pop();
    } catch (e) {
      setState(() => _message = e
          .toString()
          .replaceFirst('Exception: ', 'تعذر الإضافة: '));
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تفاصيل الباقة')),
      body: FutureBuilder<SellerBundleModel?>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final b = snap.data;
          if (b == null) {
            return const Center(
                child: Text('الباقة غير متاحة حاليًا.'));
          }
          return _body(context, b);
        },
      ),
    );
  }

  Widget _body(BuildContext context, SellerBundleModel b) {
    final cover = b.coverImageUrl ??
        (b.items.isNotEmpty ? b.items.first.imageUrl : null);
    final maxQty = b.sellableNow < 1 ? 1 : b.sellableNow;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (cover != null && cover.isNotEmpty)
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.network(cover,
                height: 230,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                    height: 230, color: Colors.green.shade900)),
          ),
        const SizedBox(height: 12),
        Text(b.bundleName,
            style:
                const TextStyle(fontWeight: FontWeight.w900, fontSize: 20)),
        Text(b.sellerName,
            style:
                const TextStyle(color: Colors.black54, fontSize: 14)),
        const SizedBox(height: 10),
        Row(
          children: [
            Text('${b.totalPrice.toStringAsFixed(0)} ج.م',
                style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 22,
                    color: Theme.of(context).colorScheme.primary)),
            const SizedBox(width: 10),
            Text('${b.originalTotal.toStringAsFixed(0)} ج.م',
                style: const TextStyle(
                    decoration: TextDecoration.lineThrough,
                    color: Colors.grey,
                    fontSize: 15)),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.green.shade700,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
              'وفّر ${b.saving.toStringAsFixed(0)} ج.م (${b.items.length} منتجات)',
              style:
                  const TextStyle(color: Colors.white, fontSize: 13)),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.amber.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.amber.shade200),
          ),
          child: const Text(
              'عرض واحد بسعر واحد — هذه المكونات تُباع معًا داخل الباقة، وليست منتجات منفصلة.',
              style: TextStyle(fontSize: 13)),
        ),
        const SizedBox(height: 14),
        const Text('مكونات الباقة',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
        const SizedBox(height: 6),
        for (final it in b.items)
          Card(
            key: Key('bundle-component-${it.offerId}-${it.unitIndex}'),
            child: ListTile(
              leading: (it.imageUrl != null && it.imageUrl!.isNotEmpty)
                  ? Image.network(it.imageUrl!,
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          const Icon(Icons.image_not_supported))
                  : const Icon(Icons.image_not_supported),
              title: Text(
                  '${it.productName} (${it.unitName})',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(
                  'الكمية في الباقة: ${it.qtyRequired} • السعر الأصلي: ${it.priceSnapshot.toStringAsFixed(2)} ج.م'),
            ),
          ),
        const SizedBox(height: 14),
        Text('التوفر: ${b.sellableNow} من الباقة متاح حاليًا',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Text(
            b.deliveryZones.isEmpty
                ? 'التوصيل: جميع المناطق'
                : 'التوصيل: ${b.deliveryZones.take(5).join('، ')}${b.deliveryZones.length > 5 ? '…' : ''}',
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            IconButton(
              key: const Key('bundle-qty-dec'),
              icon: const Icon(Icons.remove_circle_outline),
              onPressed: _qty > 1 ? () => setState(() => _qty--) : null,
            ),
            Text('$_qty',
                key: const Key('bundle-qty'),
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 18)),
            IconButton(
              key: const Key('bundle-qty-inc'),
              icon: const Icon(Icons.add_circle_outline),
              onPressed: _qty < maxQty ? () => setState(() => _qty++) : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                key: const Key('bundle-add-to-cart'),
                onPressed: _adding || b.sellableNow <= 0
                    ? null
                    : () => _addToCart(b),
                child: Text(_adding
                    ? 'جارٍ الإضافة…'
                    : 'أضف إلى السلة (${(b.totalPrice * _qty).toStringAsFixed(0)} ج.م)'),
              ),
            ),
          ],
        ),
        if (_message != null) ...[
          const SizedBox(height: 8),
          Text(_message!,
              style: TextStyle(
                  color: Colors.red.shade800,
                  fontWeight: FontWeight.bold)),
        ],
        const SizedBox(height: 24),
      ],
    );
  }
}
