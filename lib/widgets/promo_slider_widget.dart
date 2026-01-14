// lib/widgets/promo_slider_widget.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../screens/consumer/consumer_data_models.dart';

// استيراد الصفحات اللي بعتها عشان التوجيه يشتغل
import '../screens/consumer/ConsumerSubCategoryScreen.dart'; // لتست 1
import '../screens/consumer/consumer_product_list_screen.dart'; // لتست 2
import '../screens/consumer/MarketplaceHomeScreen.dart'; // لتست 3

class PromoSliderWidget extends StatefulWidget {
  final List<ConsumerBanner> banners;
  final double height;
  final String? currentOwnerId; // نحتاجه لتوريث الـ ownerId إذا لزم الأمر

  const PromoSliderWidget({
    super.key, 
    required this.banners, 
    this.height = 160,
    this.currentOwnerId,
  });

  @override
  State<PromoSliderWidget> createState() => _PromoSliderWidgetState();
}

class _PromoSliderWidgetState extends State<PromoSliderWidget> {
  late PageController _pageController;
  int _currentPage = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.9);
    _startAutoPlay();
  }

  void _startAutoPlay() {
    _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (widget.banners.isNotEmpty && widget.banners.length > 1) {
        _currentPage = (_currentPage + 1) % widget.banners.length;
        if (_pageController.hasClients) {
          _pageController.animateToPage(
            _currentPage, 
            duration: const Duration(milliseconds: 800), 
            curve: Curves.easeInOut
          );
        }
      }
    });
  }

  // 🎯 المحرك الذكي للمسارات (تست 1، 2، 3)
  void _handleNavigation(ConsumerBanner banner) {
    // ملاحظة: تأكد أن موديل ConsumerBanner بيقرأ linkType و targetId من فايربيز
    final String type = banner.targetType; // CATEGORY, SUB_CATEGORY, RETAILER
    final String targetId = banner.targetId;
    final String name = banner.name;

    switch (type) {
      case 'CATEGORY':
        // ✅ تست 1: يفتح الأقسام الفرعية (الخياطة/الملابس)
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ConsumerSubCategoryScreen(
              mainCategoryId: targetId,
              ownerId: widget.currentOwnerId ?? '', 
              mainCategoryName: name,
            ),
          ),
        );
        break;

      case 'SUB_CATEGORY':
        // ✅ تست 2: يفتح قائمة المنتجات فوراً
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ConsumerProductListScreen(
              mainCategoryId: '', 
              subCategoryId: targetId,
            ),
          ),
        );
        break;

      case 'RETAILER':
        // ✅ تست 3: يفتح السوبر ماركت (الماركت بليس)
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MarketplaceHomeScreen(
              currentStoreId: targetId,
              currentStoreName: name,
            ),
          ),
        );
        break;

      default:
        print("بانر بدون وجهة أو نوع غير معرف: $type");
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.banners.isEmpty) return const SizedBox.shrink();
    
    return Column(
      children: [
        SizedBox(
          height: widget.height,
          child: PageView.builder(
            controller: _pageController,
            itemCount: widget.banners.length,
            onPageChanged: (i) => setState(() => _currentPage = i),
            itemBuilder: (context, index) {
              final banner = widget.banners[index];
              return GestureDetector(
                onTap: () => _handleNavigation(banner),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: CachedNetworkImage(
                      imageUrl: banner.imageUrl,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(color: Colors.grey[200]),
                      errorWidget: (context, url, error) => const Icon(Icons.error),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        _buildDotsIndicator(),
      ],
    );
  }

  Widget _buildDotsIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: widget.banners.asMap().entries.map((entry) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: _currentPage == entry.key ? 20 : 7,
          height: 7,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: _currentPage == entry.key ? Colors.green[700] : Colors.grey[300],
          ),
        );
      }).toList(),
    );
  }
}
