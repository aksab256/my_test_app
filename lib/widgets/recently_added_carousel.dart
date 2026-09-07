// المسار: lib/widgets/recently_added_carousel.dart
import 'package:flutter/material.dart';

// 💡 تعريف الكلاس RecentlyAddedCarousel بشكل صحيح.
class RecentlyAddedCarousel extends StatelessWidget {
  const RecentlyAddedCarousel({super.key});

  @override
  Widget build(BuildContext context) {
    // هذه مجرد بيانات وهمية لعرض شريط أفقي للمنتجات
    return SizedBox(
      height: 250, 
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: 8,
        itemBuilder: (context, index) {
          return Padding(
            padding: EdgeInsets.only(
              right: 16,
              left: index == 0 ? 16 : 0, 
            ),
            child: _ProductCard(index: index),
          );
        },
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final int index;
  const _ProductCard({required this.index});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150,
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
          // صورة وهمية
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: Image.network(
              'https://placehold.co/150x120/43b97f/ffffff?text=Product+${index + 1}',
              height: 120,
              width: 150,
              fit: BoxFit.cover,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              'منتج رقم ${index + 1}',
              style: const TextStyle(fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Text(
              '150.00 ر.س',
              style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold),
            ),
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'متجر المدينة',
                  style: TextStyle(fontSize: 10, color: Colors.grey),
                ),
                Icon(Icons.add_shopping_cart, size: 16, color: Theme.of(context).primaryColor),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

