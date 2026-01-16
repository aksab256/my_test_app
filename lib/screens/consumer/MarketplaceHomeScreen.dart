// lib/screens/consumer/MarketplaceHomeScreen.dart
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
  
  final PageController _bannerPageController = PageController();
  Timer? _bannerTimer;
  int _currentBannerPage = 0;

  @override
  void initState() {
    super.initState();
    _categoriesFuture = _dataService.fetchCategoriesByOffers(widget.currentStoreId);
    
    // سلايدر تلقائي احترافي
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
    final welcomeName = buyerProvider.userName ?? 'عميلنا العزيز';

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFFBFDFF), // خلفية أهدأ قليلاً
        appBar: _buildCleanAppBar(welcomeName),
        body: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // 1. السلايدر المتحرك
            SliverToBoxAdapter(child: _buildAutoBannerSlider()),

            // 2. عنوان الأقسام بتصميم مميز
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.only(right: 6.w, left: 6.w, top: 4.h, bottom: 2.h),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "الأقسام الرئيسية",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900, 
                        color: const Color(0xFF1A1D1E),
                        letterSpacing: 0.5
                      ),
                    ),
                    Icon(Icons.grid_view_rounded, color: AppTheme.primaryGreen.withOpacity(0.5), size: 22),
                  ],
                ),
              ),
            ),

            // 3. شبكة الأقسام
            _buildPremiumCategoriesGrid(),

            const SliverToBoxAdapter(child: SizedBox(height: 140)),
          ],
        ),
        // تم تحديث الـ BottomNav ليتوافق مع مسارات ملف الـ Widget الأصلي
        bottomNavigationBar: _buildModernBottomNav(cartProvider),
      ),
    );
  }

  PreferredSizeWidget _buildCleanAppBar(String name) {
    return AppBar(
      elevation: 0,
      backgroundColor: Colors.white,
      toolbarHeight: 11.h,
      automaticallyImplyLeading: false,
      title: Padding(
        padding: EdgeInsets.only(top: 1.h),
        child: Row(
          children: [
            Hero(
              tag: 'user_avatar',
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppTheme.primaryGreen.withOpacity(0.2), width: 2),
                ),
                child: CircleAvatar(
                  radius: 26,
                  backgroundColor: AppTheme.primaryGreen.withOpacity(0.1),
                  child: Icon(Icons.person_rounded, color: AppTheme.primaryGreen, size: 32),
                ),
              ),
            ),
            SizedBox(width: 4.w),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("أهلاً بك،", 
                  style: TextStyle(fontSize: 12, color: Colors.grey[500], fontWeight: FontWeight.w600)),
                Text(name,
                  style: const TextStyle(fontSize: 19, color: Color(0xFF1A1D1E), fontWeight: FontWeight.w900)),
              ],
            ),
            const Spacer(),
            // عرض اسم المتجر بتصميم يشبه الـ Chip
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppTheme.primaryGreen.withOpacity(0.15), AppTheme.primaryGreen.withOpacity(0.05)],
                ),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: AppTheme.primaryGreen.withOpacity(0.1))
              ),
              child: Text(widget.currentStoreName,
                style: TextStyle(fontSize: 12, color: AppTheme.primaryGreen, fontWeight: FontWeight.w900)),
            )
          ],
        ),
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

        final banners = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return data['ownerId'] == widget.currentStoreId || data['targetAudience'] == 'general';
        }).toList();

        if (banners.isEmpty) return const SizedBox.shrink();

        return Container(
          height: 23.h,
          margin: EdgeInsets.only(top: 2.h),
          child: PageView.builder(
            controller: _bannerPageController,
            itemBuilder: (context, index) {
              final data = banners[index % banners.length].data() as Map<String, dynamic>;
              return AnimatedBuilder(
                animation: _bannerPageController,
                builder: (context, child) {
                  return Container(
                    margin: EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.h),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(25),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryGreen.withOpacity(0.15),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        )
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(25),
                      child: Image.network(
                        data['imageUrl'], 
                        fit: BoxFit.cover,
                      ),
                    ),
                  );
                },
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
          padding: EdgeInsets.symmetric(horizontal: 5.w),
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.85,
              crossAxisSpacing: 5.w,
              mainAxisSpacing: 5.w,
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
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF1A1D1E).withOpacity(0.04), 
                          blurRadius: 20, 
                          offset: const Offset(0, 8)
                        )
                      ],
                    ),
                    child: Column(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Container(
                            margin: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(22),
                              image: DecorationImage(
                                image: NetworkImage(cat.imageUrl),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 1,
                          child: Center(
                            child: Text(cat.name,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: Color(0xFF1A1D1E))),
                          ),
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
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 30, offset: const Offset(0, -10))
        ]
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        child: BottomNavigationBar(
          currentIndex: 0,
          selectedItemColor: AppTheme.primaryGreen,
          unselectedItemColor: Colors.grey[400],
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w900, fontFamily: 'Cairo', fontSize: 12),
          unselectedLabelStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 11),
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          elevation: 0,
          items: [
            const BottomNavigationBarItem(icon: Icon(Icons.home_filled, size: 28), label: 'الرئيسية'),
            BottomNavigationBarItem(
              icon: Badge(
                label: Text(cart.itemCount.toString()),
                isLabelVisible: cart.itemCount > 0,
                backgroundColor: Colors.redAccent,
                child: const Icon(Icons.shopping_basket_rounded, size: 28),
              ),
              label: 'سلتك',
            ),
            const BottomNavigationBarItem(icon: Icon(Icons.receipt_long_rounded, size: 28), label: 'طلباتي'),
            const BottomNavigationBarItem(icon: Icon(Icons.person_rounded, size: 28), label: 'حسابي'),
          ],
          onTap: (index) {
            if (index == 0) {
              // العودة للرئيسية (رادار المحلات)
              Navigator.pushNamed(context, '/consumerhome');
              return;
            }
            
            // 🎯 تم تعديل المسارات هنا لتطابق مسارات الـ Widget الأصلي الخاص بك
            switch (index) {
              case 1:
                Navigator.pushNamed(context, '/cart');
                break;
              case 2:
                Navigator.pushNamed(context, '/consumer-purchases'); // المسار الأصلي لطلباتي
                break;
              case 3:
                Navigator.pushNamed(context, '/myDetails'); // المسار الأصلي لحسابي
                break;
            }
          },
        ),
      ),
    );
  }
}
