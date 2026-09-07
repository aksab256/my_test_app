// المسار: lib/widgets/buyer_category_ads_banner.dart

import 'package:flutter/material.dart';

class BuyerCategoryAdsBanner extends StatelessWidget {
  const BuyerCategoryAdsBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 100, // ارتفاع مناسب لبانر إعلاني صغير
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7F7),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        children: [
          // يمكن استبدال هذا برابط Image.network حقيقي لبانر إعلاني
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.network(
              'https://via.placeholder.com/800x100/4CAF50/FFFFFF?text=إعلان+مميز+في+صفحة+الأقسام',
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              errorBuilder: (context, error, stackTrace) => Container(
                color: Colors.grey[200],
                child: const Center(
                  child: Text(
                    'مساحة إعلانية',
                    style: TextStyle(color: Color(0xFF4CAF50), fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ),
          const Positioned(
            bottom: 5,
            right: 5,
            child: Icon(Icons.star, color: Colors.amber, size: 18),
          ),
        ],
      ),
    );
  }
}

