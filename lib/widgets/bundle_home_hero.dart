import 'package:flutter/material.dart';
import 'package:my_test_app/models/bundle_model.dart';

/// Wide hero carousel for bundles on the home screen.
///
/// One bundle fills ~88% of the viewport width so a slice of the next card
/// peeks in. Presentational only: the parent loads [bundles] (already
/// zone-filtered + sellable) and handles navigation.
class BundleHomeHero extends StatefulWidget {
  final List<SellerBundleModel> bundles;
  final ValueChanged<SellerBundleModel>? onOpen;
  final VoidCallback? onViewAll;

  const BundleHomeHero({
    super.key,
    required this.bundles,
    this.onOpen,
    this.onViewAll,
  });

  @override
  State<BundleHomeHero> createState() => _BundleHomeHeroState();
}

class _BundleHomeHeroState extends State<BundleHomeHero> {
  final PageController _controller = PageController(viewportFraction: 0.88);
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.bundles.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              const Expanded(
                child: Text('باقات مميزة',
                    style:
                        TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
              ),
              TextButton(
                key: const Key('bundles-view-all'),
                onPressed: widget.onViewAll,
                child: const Text('عرض المزيد ←'),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 300,
          child: PageView.builder(
            controller: _controller,
            itemCount: widget.bundles.length,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (context, i) =>
                _heroCard(context, widget.bundles[i]),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            widget.bundles.length,
            (i) => Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i == _page
                    ? Theme.of(context).colorScheme.primary
                    : Colors.grey.shade300,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _heroCard(BuildContext context, SellerBundleModel b) {
    final cover = b.coverImageUrl ??
        (b.items.isNotEmpty ? b.items.first.imageUrl : null);
    final names = b.items.map((e) => e.productName).where((e) => e.isNotEmpty).toList();
    final shown = names.take(3).join('، ');
    final extra = names.length > 3 ? ' +${names.length - 3}' : '';
    return Card(
      key: Key('bundle-hero-${b.id}'),
      margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      clipBehavior: Clip.antiAlias,
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: InkWell(
        onTap: widget.onOpen == null ? null : () => widget.onOpen!(b),
        child: Row(
          children: [
            Expanded(
              flex: 11,
              child: cover != null && cover.isNotEmpty
                  ? Image.network(cover,
                      fit: BoxFit.cover,
                      height: double.infinity,
                      errorBuilder: (_, __, ___) =>
                          _coverFallback(b.bundleName))
                  : _coverFallback(b.bundleName),
            ),
            Expanded(
              flex: 9,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(b.bundleName,
                        style: const TextStyle(
                            fontWeight: FontWeight.w900, fontSize: 16),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(b.sellerName,
                        style: const TextStyle(
                            color: Colors.black54, fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                              '${b.totalPrice.toStringAsFixed(0)} ج.م',
                              style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 17,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .primary),
                              overflow: TextOverflow.ellipsis),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                              '${b.originalTotal.toStringAsFixed(0)} ج.م',
                              style: const TextStyle(
                                  decoration:
                                      TextDecoration.lineThrough,
                                  color: Colors.grey,
                                  fontSize: 12),
                              overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.green.shade700,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text('وفّر ${b.saving.toStringAsFixed(0)} ج.م',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 12)),
                    ),
                    const SizedBox(height: 8),
                    Text(
                        'المكونات (${b.items.length}): $shown$extra',
                        style: const TextStyle(fontSize: 12),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Text('المتاح: ${b.sellableNow} من الباقة',
                        style: const TextStyle(
                            color: Colors.black54, fontSize: 11)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _coverFallback(String label) => Container(
        color: const Color(0xFF1B5E20),
        alignment: Alignment.center,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text(label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold),
              maxLines: 3,
              overflow: TextOverflow.ellipsis),
        ),
      );
}
