import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sizer/sizer.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async'; // ضروري للـ Timer
import '../../models/category_model.dart';
import '../../services/marketplace_data_service.dart';
import '../../theme/app_theme.dart';
import '../../providers/cart_provider.dart';
import 'package:my_test_app/screens/consumer/ConsumerProductListScreen.dart';

class ConsumerSubCategoryScreen extends StatefulWidget {
  final String mainCategoryId;
  final String ownerId;
  final String mainCategoryName;
  static const routeName = '/subcategories';

  const ConsumerSubCategoryScreen({
    super.key,
    required this.mainCategoryId,
    required this.ownerId,
    required this.mainCategoryName,
  });

  @override
  State<ConsumerSubCategoryScreen> createState() => _ConsumerSubCategoryScreenState();
}

class _ConsumerSubCategoryScreenState extends State<ConsumerSubCategoryScreen> {
  late Future<List<CategoryModel>> _subCategoriesFuture;
  final MarketplaceDataService _dataService = MarketplaceDataService();
  
  // متغيرات السلايدر اليدوي
  final PageController _pageController = PageController();
  int _currentPage = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _subCategoriesFuture = _dataService.fetchSubCategoriesByOffers(
      widget.mainCategoryId,
      widget.ownerId,
    );
    
    // إعداد المؤقت للتحريك التلقائي
    _timer = Timer.periodic(const Duration(seconds: 4), (Timer timer) {
      if (_pageController.hasClients) {
        _currentPage++;
        _pageController.animateToPage(
          _currentPage,
          duration: const Duration(milliseconds: 800),
          curve: Curves.fastOutSlowIn,
        );
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cartProvider = Provider.of<CartProvider>(context);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF2D3142),
          centerTitle: true,
          toolbarHeight: 8.h,
          title: Text(
            widget.mainCategoryName,
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 22),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // 1. شريط الترحيب (مرحبا بك فقط بمقاس 19)
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(4.w, 4.w, 4.w, 0),
                child: const Text(
                  "مرحباً بك",
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2D3142),
                  ),
                ),
              ),
            ),

            // 2. البانر المتحرك التلقائي (PageView)
            SliverToBoxAdapter(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('consumerBanners')
                    .where('status', isEqualTo: 'active')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const SizedBox.shrink();

                  // فلترة البانرات بناءً على الـ ownerId أو العامة
                  final filteredDocs = snapshot.data!.docs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    return data['ownerId'] == widget.ownerId || data['targetAudience'] == 'general';
                  }).toList();

                  if (filteredDocs.isEmpty) return const SizedBox.shrink();

                  return Container(
                    height: 22.h,
                    margin: EdgeInsets.symmetric(vertical: 2.h),
                    child: PageView.builder(
                      controller: _pageController,
                      itemBuilder: (context, index) {
                        // استخدام modulo لجعل السلايدر لا ينتهي (Infinite loop)
                        final data = filteredDocs[index % filteredDocs.length].data() as Map<String, dynamic>;
                        return Container(
                          margin: EdgeInsets.symmetric(horizontal: 4.w),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10)],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                Image.network(data['imageUrl'], fit: BoxFit.cover),
                                Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [Colors.black.withOpacity(0.5), Colors.transparent],
                                      begin: Alignment.bottomCenter,
                                    ),
                                  ),
                                  alignment: Alignment.bottomRight,
                                  padding: EdgeInsets.all(4.w),
                                  child: Text(
                                    data['name'] ?? "",
                                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),

            // 3. شبكة الأقسام الفرعية (الكروت)
            FutureBuilder<List<CategoryModel>>(
              future: _subCategoriesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SliverFillRemaining(child: Center(child: CircularProgressIndicator()));
                }
                final subCategories = snapshot.data ?? [];

                return SliverPadding(
                  padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
                  sliver: SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.8,
                      crossAxisSpacing: 4.w,
                      mainAxisSpacing: 4.w,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => _buildPremiumCategoryCard(context, subCategories[index]),
                      childCount: subCategories.length,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
        bottomNavigationBar: _buildModernBottomNav(context, cartProvider),
      ),
    );
  }

  // الكارت المعدل (الصورة تملاه بالكامل وحذف أي "عرض الكل")
  Widget _buildPremiumCategoryCard(BuildContext context, CategoryModel category) {
    return GestureDetector(
      onTap: () => Navigator.of(context).pushNamed(
        ConsumerProductListScreen.routeName,
        arguments: {
          'mainId': widget.mainCategoryId,
          'subId': category.id,
          'ownerId': widget.ownerId,
          'subCategoryName': category.name,
        },
      ),
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
                  category.imageUrl,
                  width: double.infinity,
                  fit: BoxFit.cover, // تم الضبط لملء المساحة
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(vertical: 1.5.h, horizontal: 2.w),
              child: Text(
                category.name,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 19, // المقاس المطلوب
                  color: Color(0xFF2D3142),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernBottomNav(BuildContext context, CartProvider cart) {
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
          const BottomNavigationBarItem(icon: Icon(Icons.account_balance_wallet_rounded, size: 28), label: 'محفظتي'),
          const BottomNavigationBarItem(icon: Icon(Icons.receipt_long_rounded, size: 28), label: 'طلباتي'),
        ],
        onTap: (index) {
          if (index == 0) Navigator.popUntil(context, (route) => route.isFirst);
          if (index == 1) Navigator.pushNamed(context, '/cart');
          if (index == 2) Navigator.pushNamed(context, '/points-loyalty');
          if (index == 3) Navigator.pushNamed(context, '/orders');
        },
      ),
    );
  }
}

