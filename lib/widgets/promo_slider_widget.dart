import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../screens/consumer/consumer_data_models.dart';
// ✅ تم حذف الملف الممسوح واستبداله باللازم
import '../screens/consumer/ConsumerProductListScreen.dart';
import '../screens/consumer/MarketplaceHomeScreen.dart';

class PromoSliderWidget extends StatefulWidget {
  final List<ConsumerBanner> banners;
  final double height;
  final String? currentOwnerId;

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
            curve: Curves.easeInOut,
          );
        }
      }
    });
  }

  void _handleNavigation(ConsumerBanner banner) {
    final String type = banner.linkType ?? banner.targetType ?? banner.link ?? '';
    final String targetId = banner.targetId ?? '';
    final String name = banner.name ?? 'عرض خاص';

    if (targetId.isEmpty) {
      debugPrint("⚠️ لا يوجد ID للبانر - تم إلغاء التوجيه");
      return;
    }

    switch (type.toUpperCase()) {
      case 'CATEGORY':
        // 🎯 التوجيه لصفحة الأقسام الفرعية بنظام الـ Named Routes
        Navigator.pushNamed(
          context,
          '/subcategories',
          arguments: {
            'mainId': targetId,
            'ownerId': widget.currentOwnerId ?? '',
            'mainCategoryName': name,
          },
        );
        break;

      case 'SUB_CATEGORY':
      case 'SUBCATEGORY':
        // 🎯 التوجيه لصفحة المنتجات بالسيستم الجديد (Arguments)
        Navigator.pushNamed(
          context,
          ConsumerProductListScreen.routeName,
          arguments: {
            'mainId': '', 
            'subId': targetId,
            'ownerId': widget.currentOwnerId ?? '',
            'subCategoryName': name,
          },
        );
        break;

      case 'RETAILER':
      case 'SELLER':
      case 'STORE':
        Navigator.pushNamed(
          context,
          MarketplaceHomeScreen.routeName,
          arguments: {
            'storeId': targetId,
            'storeName': name,
          },
        );
        break;

      default:
        debugPrint("❓ نوع توجيه غير معروف: $type");
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
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(15),
                    child: CachedNetworkImage(
                      imageUrl: banner.imageUrl,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
                      errorWidget: (context, url, error) => const Icon(Icons.error),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        _buildDotsIndicator(),
      ],
    );
  }

  Widget _buildDotsIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: widget.banners.asMap().entries.map((entry) {
        return Container(
          width: _currentPage == entry.key ? 12 : 6,
          height: 6,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: _currentPage == entry.key ? Colors.green : Colors.grey,
          ),
        );
      }).toList(),
    );
  }
}

