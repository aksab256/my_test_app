// المسار: lib/widgets/home_content.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
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
  }

  @override
  void dispose() {
    _bannerTimer?.cancel();
    _bannerController.dispose();
    super.dispose();
  }

  // --- جلب البيانات (تظل كما هي لضمان استقرار الباك إند) ---
  Future<void> _loadAllData() async {
    try {
      await Future.wait([_loadCategories(), _loadRetailerBanners(), _loadRecentlyAddedProducts()]);
      if (mounted) {
        setState(() => _isLoading = false);
        _startBannerAutoSlide();
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadCategories() async {
    final q = await _db.collection('mainCategory').where('status', isEqualTo: 'active').orderBy('order').get();
    if (mounted) {
      setState(() => _categories = q.docs.map((doc) => {'id': doc.id, 'name': doc['name'] ?? '', 'imageUrl': doc['imageUrl'] ?? ''}).toList());
    }
  }

  Future<void> _loadRetailerBanners() async {
    final q = await _db.collection('retailerBanners').where('status', isEqualTo: 'active').orderBy('order').get();
    if (mounted) {
      setState(() => _banners = q.docs.map((doc) => {...doc.data(), 'id': doc.id}).toList());
    }
  }

  Future<void> _loadRecentlyAddedProducts() async {
    final q = await _db.collection('products').where('status', isEqualTo: 'active').orderBy('createdAt', descending: true).limit(10).get();
    if (mounted) {
      setState(() => _recentProducts = q.docs.map((doc) {
        final data = doc.data();
        final List<dynamic>? urls = data['imageUrls'] as List<dynamic>?;
        return {'id': doc.id, 'name': data['name'] ?? '', 'imageUrl': (urls != null && urls.isNotEmpty) ? urls.first : '', 'subId': data['subId'] ?? '', 'mainId': data['mainId'] ?? ''};
      }).toList());
    }
  }

  void _startBannerAutoSlide() {
    _bannerTimer?.cancel();
    if (_banners.length > 1) {
      _bannerTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
        if (!mounted || _banners.isEmpty) return;
        int nextPage = (_currentBannerIndex + 1) % _banners.length;
        _bannerController.animateToPage(nextPage, duration: const Duration(milliseconds: 700), curve: Curves.easeOut);
      });
    }
  }

  // 🎯 التعديل الجوهري: إدارة التنقل بذكاء
  void _handleBannerClick(String? linkType, String? targetId) {
    if (targetId == null || targetId.isEmpty || linkType == null) return;
    final type = linkType.toUpperCase();

    switch (type) {
      case 'PRODUCT':
        Navigator.of(context).pushNamed('/productDetails', arguments: {'productId': targetId});
        break;
      case 'CATEGORY':
        // يفتح صفحة الأقسام الفرعية بالمعرف الصحيح
        Navigator.of(context).pushNamed('/category', arguments: targetId);
        break;
      case 'RETAILER':
        // يفتح صفحة عروض تاجر محدد
        Navigator.of(context).pushNamed(TraderOffersScreen.routeName, arguments: targetId);
        break;
      case 'TRADERS_LIST':
        // 🚀 إذا أردت فتح "قائمة التجار" بالكامل وليس تاجراً واحداً
        Navigator.of(context).pushNamed('/traders');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator(color: Color(0xFF4CAF50)));

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 15),
          
          // 1. البانرات المتحركة
          _buildBannerSlider(),
          
          const SizedBox(height: 25),
          
          // 2. عنوان الأقسام
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 15),
            child: Text('الأقسام الرئيسية', 
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Tajawal', color: Color(0xFF2c3e50))),
          ),
          
          const SizedBox(height: 15),
          
          // 3. شبكة الأقسام (تم تحسين childAspectRatio للظهور بشكل سليم)
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            itemCount: _categories.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3, 
              childAspectRatio: 0.85, // تعديل بسيط لضمان عدم قص النص
              mainAxisSpacing: 10,
              crossAxisSpacing: 10
            ),
            itemBuilder: (context, index) => _buildCategoryCard(_categories[index]),
          ),

          // 4. المنتجات المضافة حديثاً
          if (_recentProducts.isNotEmpty) ...[
             const Padding(
               padding: EdgeInsets.only(right: 15, top: 20),
               child: Text('أضيف حديثاً', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Tajawal')),
             ),
             const SizedBox(height: 10),
             _buildRecentProductsList(),
          ],
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildCategoryCard(Map<String, dynamic> data) {
    return InkWell(
      onTap: () => Navigator.of(context).pushNamed('/category', arguments: data['id']),
      child: Column(
        children: [
          Container(
            width: 70, height: 70,
            decoration: BoxDecoration(
              color: Colors.white, shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 8, offset: const Offset(0, 4))],
            ),
            child: ClipOval(
              child: data['imageUrl'].isNotEmpty 
                ? Image.network(data['imageUrl'], fit: BoxFit.cover)
                : const Icon(Icons.category, size: 35, color: Color(0xFF4CAF50)),
            ),
          ),
          const SizedBox(height: 10),
          Text(data['name'], 
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, fontFamily: 'Tajawal'), 
            maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _buildBannerSlider() {
    if (_banners.isEmpty) return const SizedBox.shrink();
    return Column(
      children: [
        SizedBox(
          height: 160,
          child: PageView.builder(
            controller: _bannerController,
            onPageChanged: (v) => setState(() => _currentBannerIndex = v),
            itemCount: _banners.length,
            itemBuilder: (context, index) => InkWell(
              onTap: () => _handleBannerClick(_banners[index]['linkType'], _banners[index]['targetId']),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 5))],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: Image.network(_banners[index]['imageUrl'], fit: BoxFit.cover),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        // نقاط المؤشر للبانر
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: _banners.asMap().entries.map((entry) {
            return Container(
              width: 8.0, height: 8.0,
              margin: const EdgeInsets.symmetric(horizontal: 4.0),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _currentBannerIndex == entry.key ? const Color(0xFF4CAF50) : Colors.grey.shade300,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildRecentProductsList() {
    return SizedBox(
      height: 200,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        reverse: true,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        itemCount: _recentProducts.length,
        itemBuilder: (context, index) {
          final p = _recentProducts[index];
          return InkWell(
            onTap: () => Navigator.of(context).pushNamed('/products', arguments: {'subId': p['subId'], 'mainId': p['mainId']}),
            child: Container(
              width: 140,
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5, spreadRadius: 1)],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                      child: Image.network(p['imageUrl'], fit: BoxFit.cover),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                    child: Text(p['name'], 
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontFamily: 'Tajawal', fontSize: 12, fontWeight: FontWeight.w600),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  )
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
