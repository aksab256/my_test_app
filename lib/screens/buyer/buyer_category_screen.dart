// المسار: lib/widgets/home_content.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
// تأكد من استيراد الشاشة للوصول لـ routeName
import 'package:my_test_app/screens/buyer/trader_offers_screen.dart'; 

final FirebaseFirestore _db = FirebaseFirestore.instance;

class HomeContent extends StatefulWidget {
  const HomeContent({super.key});

  @override
  State<HomeContent> createState() => _HomeContentState();
}

class _HomeContentState extends State<HomeContent> {
  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _banners = [];
  List<Map<String, dynamic>> _recentProducts = [];

  bool _isLoading = true;
  int _currentBannerIndex = 0;
  late PageController _bannerController;
  Timer? _bannerTimer;

  @override
  void initState() {
    super.initState();
    _bannerController = PageController(initialPage: 0);
    _loadAllData();
    _bannerController.addListener(() {
      if (_bannerController.page != null) {
        setState(() {
          _currentBannerIndex = _bannerController.page!.round();
        });
      }
    });
  }

  @override
  void dispose() {
    _bannerTimer?.cancel();
    _bannerController.dispose();
    super.dispose();
  }

  // --- جلب البيانات من Firebase ---
  Future<void> _loadCategories() async {
    try {
      final q = _db.collection('mainCategory')
          .where('status', isEqualTo: 'active')
          .orderBy('order', descending: false)
          .get();

      final querySnapshot = await q;
      final List<Map<String, dynamic>> loadedCategories = [];

      for (var doc in querySnapshot.docs) {
        if (doc.data().containsKey('name') && doc.data().containsKey('imageUrl')) {
          loadedCategories.add({
            'id': doc.id,
            'name': doc['name'],
            'imageUrl': doc['imageUrl'],
          });
        }
      }

      if (mounted) {
        setState(() {
          _categories = loadedCategories;
        });
      }
    } catch (e) {
      debugPrint('Firebase Error loading Categories: $e');
    }
  }

  Future<void> _loadRetailerBanners() async {
    try {
      final q = _db.collection('retailerBanners')
          .where('status', isEqualTo: 'active')
          .orderBy('order', descending: false)
          .get();

      final querySnapshot = await q;
      final List<Map<String, dynamic>> loadedBanners = [];

      for (var doc in querySnapshot.docs) {
        final data = doc.data();
        if (data.containsKey('name') && data.containsKey('imageUrl')) {
          loadedBanners.add({
            'id': doc.id,
            'name': data['name'],
            'imageUrl': data['imageUrl'],
            'linkType': data['linkType'] as String? ?? 'NONE',
            'targetId': data['targetId'] as String? ?? '',
          });
        }
      }

      if (mounted) {
        setState(() {
          _banners = loadedBanners;
        });
      }
    } catch (e) {
      debugPrint('Firebase Error loading Banners: $e');
    }
  }

  Future<void> _loadRecentlyAddedProducts() async {
    try {
      final q = _db.collection('products')
          .where('status', isEqualTo: 'active')
          .orderBy('createdAt', descending: true)
          .limit(10)
          .get();

      final querySnapshot = await q;
      final List<Map<String, dynamic>> loadedProducts = [];

      for (var doc in querySnapshot.docs) {
        final data = doc.data();
        final List<dynamic>? urls = data['imageUrls'] as List<dynamic>?;
        final String firstImageUrl = (urls != null && urls.isNotEmpty)
            ? urls.first as String : '';

        loadedProducts.add({
          'id': doc.id,
          'name': data['name'] as String? ?? 'منتج',
          'imageUrl': firstImageUrl,
          'subId': data['subId'] as String? ?? '',
        });
      }

      if (mounted) {
        setState(() {
          _recentProducts = loadedProducts;
        });
      }
    } catch (e) {
      debugPrint('Firebase Error loading recent products: $e');
    }
  }

  Future<void> _loadAllData() async {
    await Future.wait([
      _loadCategories(),
      _loadRetailerBanners(),
      _loadRecentlyAddedProducts(),
    ]);

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
      _startBannerAutoSlide();
    }
  }

  void _startBannerAutoSlide() {
    _bannerTimer?.cancel();
    if (_banners.length > 1) {
      _bannerTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
        if (!mounted || _banners.isEmpty) {
          timer.cancel();
          return;
        }
        int nextPage = (_currentBannerIndex + 1) % _banners.length;
        _bannerController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 700),
          curve: Curves.easeOut,
        );
      });
    }
  }

  // 🎯 الدالة المحدثة كلياً للتحكم في توجيه البانرات (الرئيسي والفرعي والتاجر)
  void _handleBannerClick(String? linkType, String? targetId) {
    if (targetId == null || targetId.isEmpty || linkType == null) {
      return;
    }

    final type = linkType.toUpperCase();

    // حالة 1: رابط خارجي (موقع ويب)
    if (type == 'EXTERNAL' && targetId.startsWith('http')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('يتم فتح الرابط الخارجي: $targetId', textDirection: TextDirection.rtl)),
      );
    } 
    // حالة 2: منتج محدد
    else if (type == 'PRODUCT') {
      Navigator.of(context).pushNamed(
        '/productDetails',
        arguments: {'productId': targetId},
      );
    } 
    // حالة 3: قسم رئيسي (يفتح صفحة الأقسام الفرعية لتمكين الاختيار)
    else if (type == 'CATEGORY') {
      Navigator.of(context).pushNamed(
        '/category', // يوجه إلى BuyerCategoryScreen
        arguments: targetId, 
      );
    } 
    // حالة 4: قسم فرعي (يوجه مباشرة لصفحة المنتجات المرتبطة بهذا المعرف)
    else if (type == 'SUB_CATEGORY') {
      Navigator.of(context).pushNamed(
        '/products',
        arguments: {
          'subId': targetId,
          'mainId': '',
        },
      );
    } 
    // حالة 5: تاجر معين (يفتح صفحة عروض التاجر)
    else if (type == 'RETAILER') {
      Navigator.of(context).pushNamed(
        TraderOffersScreen.routeName, 
        arguments: targetId,
      );
    } 
    else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('نوع الوجهة غير معروف: $linkType', textDirection: TextDirection.rtl)),
      );
    }
  }

  // --- واجهة المستخدم (Widgets) ---

  Widget _buildCategoryCard(Map<String, dynamic> data) {
    final name = data['name'] as String? ?? 'قسم';
    final imageUrl = data['imageUrl'] as String? ?? '';
    const double size = 70.0;
    const double totalDiameter = size + 8.0;

    return InkWell(
      onTap: () {
        Navigator.of(context).pushNamed(
          '/category',
          arguments: data['id'],
        );
      },
      child: Column(
        children: [
          Container(
            width: totalDiameter,
            height: totalDiameter,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 4))],
            ),
            child: ClipOval(
              child: imageUrl.isNotEmpty 
                ? Image.network(imageUrl, fit: BoxFit.cover)
                : const Icon(Icons.category, size: 35),
            ),
          ),
          const SizedBox(height: 8),
          Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, fontFamily: 'Tajawal'), overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _buildBannerSlider() {
    if (_banners.isEmpty) return const SizedBox.shrink();
    return Column(
      children: [
        SizedBox(
          height: 140,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: PageView.builder(
              controller: _bannerController,
              itemCount: _banners.length,
              itemBuilder: (context, index) {
                final banner = _banners[index];
                return InkWell(
                  onTap: () => _handleBannerClick(banner['linkType'], banner['targetId']),
                  child: Image.network(banner['imageUrl'], fit: BoxFit.cover),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: _banners.asMap().entries.map((entry) {
            return Container(
              width: 8.0, height: 8.0,
              margin: const EdgeInsets.symmetric(horizontal: 4.0),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _currentBannerIndex == entry.key ? const Color(0xFF4CAF50) : Colors.grey.shade400,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildProductCard(Map<String, dynamic> productData) {
    final name = productData['name'] as String? ?? 'منتج';
    final imageUrl = productData['imageUrl'] as String? ?? '';
    final subId = productData['subId'] as String? ?? '';

    return InkWell(
      onTap: () {
        if (subId.isNotEmpty) {
          Navigator.of(context).pushNamed('/products', arguments: {'subId': subId, 'mainId': ''});
        }
      },
      child: Container(
        width: 150,
        margin: const EdgeInsets.symmetric(horizontal: 5),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 4))],
        ),
        child: Column(
          children: [
            SizedBox(
              height: 120,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                child: imageUrl.isNotEmpty ? Image.network(imageUrl, fit: BoxFit.cover) : const Icon(Icons.shopping_bag),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Tajawal'), overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator(color: Color(0xFF4CAF50)));

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15.0),
            child: _buildBannerSlider(),
          ),
          const SizedBox(height: 30),
          const Center(child: Text('الأقسام الرئيسية', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, fontFamily: 'Tajawal'))),
          const SizedBox(height: 15),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15.0),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _categories.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3, crossAxisSpacing: 10, mainAxisSpacing: 15, childAspectRatio: 0.85,
              ),
              itemBuilder: (context, index) => _buildCategoryCard(_categories[index]),
            ),
          ),
          const SizedBox(height: 30),
          if (_recentProducts.isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 15.0),
                  child: Text('أضيف حديثاً', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Tajawal')),
                ),
                SizedBox(
                  height: 200,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    reverse: true,
                    itemCount: _recentProducts.length,
                    itemBuilder: (context, index) => _buildProductCard(_recentProducts[index]),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }
}
