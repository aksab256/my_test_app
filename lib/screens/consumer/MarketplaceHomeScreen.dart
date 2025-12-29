import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sizer/sizer.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'package:my_test_app/services/marketplace_data_service.dart';
import 'package:my_test_app/models/category_model.dart';
import 'package:my_test_app/providers/buyer_data_provider.dart';
import 'package:my_test_app/providers/cart_provider.dart';
import '../../theme/app_theme.dart';

class MarketplaceHomeScreen extends StatefulWidget {
  static const routeName = '/marketplaceHome';
  final String currentStoreId;
  final String currentStoreName;

  const MarketplaceHomeScreen({
    super.key,
    required this.currentStoreId,
    required this.currentStoreName,
  });

  @override
  State<MarketplaceHomeScreen> createState() => _MarketplaceHomeScreenState();
}

class _MarketplaceHomeScreenState extends State<MarketplaceHomeScreen> {
  final MarketplaceDataService _dataService = MarketplaceDataService();
  late Future<List<CategoryModel>> _categoriesFuture;
  
  // متغيرات السلايدر المتحرك تلقائياً
  final PageController _bannerPageController = PageController();
  Timer? _bannerTimer;
  int _currentBannerPage = 0;

  @override
  void initState() {
    super.initState();
    _categoriesFuture = _dataService.fetchCategoriesByOffers(widget.currentStoreId);
    
    // إعداد التحريك التلقائي للبانر
    _bannerTimer = Timer.periodic(const Duration(seconds: 5), (Timer timer) {
      if (_bannerPageController.hasClients) {
        _currentBannerPage++;
        _bannerPageController.animateToPage(
          _currentBannerPage,
          duration: const Duration(milliseconds: 900),
          curve: Curves.easeInOutQuart,
        );
      }
    });
  }

  @override
  void dispose() {
    _bannerTimer?.cancel();
    _bannerPageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final buyerProvider = Provider.of<BuyerDataProvider>(context);
    final cartProvider = Provider.of<CartProvider>(context);
    // توحيد الترحيب: حذف "أهلاً بك" المكررة والتركيز على الاسم
    final welcomeName = buyerProvider.userName ?? 'عميلنا العزيز';

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        appBar: _buildCleanAppBar(welcomeName),
        body: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // 1. قسم البانرات المتحرك (Auto Slider) مع الفلترة
            SliverToBoxAdapter(child: _buildAutoBannerSlider()),

            // 2. عنوان "الأقسام الرئيسية" (تم حذف عرض الكل وتكبير الخط)
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 2.h),
                child: Text(
                  "الأقسام الرئيسية",
                  style: TextStyle(
                    fontSize: 19, // المقاس المطلوب
                    fontWeight: FontWeight.w900, 
                    color: const Color(0xFF2D3142)
                  ),
                ),
              ),
            ),

            // 3. شبكة الأقسام بكروت تملاها الصورة
            _buildPremiumCategoriesGrid(),

            const SliverToBoxAdapter(child: SizedBox(height: 120)),
          ],
        ),
        bottomNavigationBar: _buildModernBottomNav(cartProvider),
      ),
    );
  }

  PreferredSizeWidget _buildCleanAppBar(String name) {
    return AppBar(
      elevation: 0,
      backgroundColor: Colors.white,
      toolbarHeight: 9.h,
      automaticallyImplyLeading: false,
      title: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: AppTheme.primaryGreen.withOpacity(0.1),
            child: Icon(Icons.person, color: AppTheme.primaryGreen, size: 28),
          ),
          SizedBox(width: 4.w),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("مرحباً بك، $name",
                style: const TextStyle(fontSize: 19, color: Color(0xFF2D3142), fontWeight: FontWeight.bold)),
              Text(widget.currentStoreName,
                style: TextStyle(fontSize: 14, color: Colors.grey[600], fontWeight: FontWeight.w500)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAutoBannerSlider() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('consumerBanners')
          .where('status', isEqualTo: 'active')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();

        // فلترة البانرات بناءً على المتجر الحالي أو البانرات العامة
        final banners = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return data['ownerId'] == widget.currentStoreId || data['targetAudience'] == 'general';
        }).toList();

        if (banners.isEmpty) return const SizedBox.shrink();

        return Container(
          height: 22.h,
          margin: EdgeInsets.only(top: 2.h),
          child: PageView.builder(
            controller: _bannerPageController,
            itemBuilder: (context, index) {
              final data = banners[index % banners.length].data() as Map<String, dynamic>;
              return Container(
                margin: EdgeInsets.symmetric(horizontal: 4.w),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10)],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.network(
                    data['imageUrl'], 
                    fit: BoxFit.cover, // الصورة تملا الحاوية بالكامل
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildPremiumCategoriesGrid() {
    return FutureBuilder<List<CategoryModel>>(
      future: _categoriesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SliverToBoxAdapter(child: Center(child: CircularProgressIndicator()));
        }
        final categories = snapshot.data ?? [];
        return SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: 4.w),
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.8,
              crossAxisSpacing: 4.w,
              mainAxisSpacing: 4.w,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final cat = categories[index];
                return GestureDetector(
                  onTap: () => Navigator.of(context).pushNamed('/subcategories', arguments: {
                    'mainId': cat.id,
                    'ownerId': widget.currentStoreId,
                    'mainCategoryName': cat.name,
                  }),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10)],
                    ),
                    child: Column(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                            child: Image.network(
                              cat.imageUrl, 
                              width: double.infinity,
                              fit: BoxFit.cover, // الصورة تملا الكارت بالكامل
                            ),
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.symmetric(vertical: 1.5.h),
                          child: Text(cat.name,
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 19, color: Color(0xFF2D3142))),
                        ),
                      ],
                    ),
                  ),
                );
              },
              childCount: categories.length,
            ),
          ),
        );
      },
    );
  }

  Widget _buildModernBottomNav(CartProvider cart) {
    return Container(
      decoration: BoxDecoration(boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20)]),
      child: BottomNavigationBar(
        currentIndex: 0,
        selectedItemColor: AppTheme.primaryGreen,
        unselectedItemColor: Colors.grey[400],
        type: BottomNavigationBarType.fixed,
        items: [
          const BottomNavigationBarItem(icon: Icon(Icons.home_filled, size: 28), label: 'الرئيسية'),
          BottomNavigationBarItem(
            icon: Badge(
              label: Text(cart.itemCount.toString()),
              isLabelVisible: cart.itemCount > 0,
              child: const Icon(Icons.shopping_basket_rounded, size: 28),
            ),
            label: 'سلتك',
          ),
          const BottomNavigationBarItem(icon: Icon(Icons.receipt_long_rounded, size: 28), label: 'طلباتي'),
          const BottomNavigationBarItem(icon: Icon(Icons.person_rounded, size: 28), label: 'حسابي'),
        ],
        onTap: (index) {
          if (index == 1) Navigator.pushNamed(context, '/cart');
          if (index == 2) Navigator.pushNamed(context, '/orders');
          if (index == 3) Navigator.pushNamed(context, '/profile');
        },
      ),
    );
  }
}

