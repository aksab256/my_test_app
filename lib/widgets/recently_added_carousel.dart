// المسار: lib/widgets/recently_added_carousel.dart
import 'package:flutter/material.dart';
import 'package:my_test_app/utils/price_display.dart';

/// «أضيف حديثًا» على الرئيسية: شريط أفقي لأحدث عروض المنتجات.
///
/// Presentational only: the parent passes [items] (already newest-first,
/// priced, and zone-filtered) and handles navigation via [onOpen].
/// Each item is a raw `productOffers` doc map plus its `offerId`.
class RecentlyAddedCarousel extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  final ValueChanged<Map<String, dynamic>>? onOpen;

  const RecentlyAddedCarousel({
    super.key,
    required this.items,
    this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 15),
          child: Text('أضيف حديثًا',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Tajawal',
                  color: Color(0xFF2c3d4a))),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 232,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemBuilder: (context, index) {
              final m = items[index];
              return Padding(
                padding: EdgeInsets.only(
                  left: index == items.length - 1 ? 4 : 8,
                  right: 4,
                ),
                child: _ProductCard(
                  key: Key('recent-item-${m['offerId'] ?? index}'),
                  item: m,
                  onTap: onOpen == null ? null : () => onOpen!(m),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ProductCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback? onTap;

  const _ProductCard({super.key, required this.item, this.onTap});

  @override
  Widget build(BuildContext context) {
    final name = (item['productName'] ?? 'منتج').toString();
    final imageUrl = (item['imageUrl'] ?? '').toString();
    final seller = (item['sellerName'] ?? '').toString();
    final amount = firstPricedAmount(item);
    return SizedBox(
      width: 150,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.15),
                spreadRadius: 2,
                blurRadius: 5,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(12)),
                child: imageUrl.isNotEmpty
                    ? Image.network(
                        imageUrl,
                        height: 120,
                        width: 150,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const SizedBox(
                          height: 120,
                          width: 150,
                          child: Icon(Icons.image_not_supported,
                              color: Colors.grey),
                        ),
                      )
                    : const SizedBox(
                        height: 120,
                        width: 150,
                        child: Icon(Icons.image_not_supported,
                            color: Colors.grey),
                      ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                child: Text(
                  name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Text(
                  '${amount.toStringAsFixed(0)} ج.م',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold),
                ),
              ),
              const Spacer(),
              if (seller.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                  child: Text(
                    seller,
                    style:
                        const TextStyle(fontSize: 10, color: Colors.grey),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
