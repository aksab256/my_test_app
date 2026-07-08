// المسار: lib/screens/consumer/consumer_general_sub_category_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sizer/sizer.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import '../../models/category_model.dart';
import '../../services/marketplace_data_service.dart';
import '../../theme/app_theme.dart';
import '../../providers/cart_provider.dart';
import 'package:my_test_app/screens/consumer/ConsumerProductListScreen.dart';

class ConsumerGeneralSubCategoryScreen extends StatefulWidget {
  final String mainCategoryId;
  final String mainCategoryName;
  static const routeName = '/general-subcategories'; 

  const ConsumerGeneralSubCategoryScreen({
    super.key,
    required this.mainCategoryId,
    required this.mainCategoryName,
  });

  @override
  State<ConsumerGeneralSubCategoryScreen> createState() => _ConsumerGeneralSubCategoryScreenState();
}

class _ConsumerGeneralSubCategoryScreenState extends State<ConsumerGeneralSubCategoryScreen> {
  late Future<List<CategoryModel>> _subCategoriesFuture;
  late Future<QuerySnapshot> _bannersFuture; 
  final MarketplaceDataService _dataService = MarketplaceDataService();

  final PageController _pageController = PageController();
  int _currentPage = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // جلب كل الأقسام الفرعية التابعة للقسم الرئيسي بناءً على التعديل الجديد للـ mainId
    _subCategoriesFuture = _fetchGeneralSubCategories(widget.mainCategoryId);
    
    _bannersFuture = FirebaseFirestore.instance
        .collection('consumerBanners')
        .where('status', isEqualTo: 'active')
        .where('targetAudience', isEqualTo: 'general')
        .get();

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

  // الدالة بعد تعديل اسم الحقل ليتطابق مع الفايربيز الفعلي (mainId)
  Future<List<CategoryModel>> _fetchGeneralSubCategories(String mainCategoryId) async {
    final querySnapshot = await FirebaseFirestore.instance
        .collection('subCategory')
        .where('mainId', isEqualTo: mainCategoryId) // التعديل هنا: mainId بدلاً من mainCategoryId
        .where('status', isEqualTo: 'active')
        .orderBy('order', descending: false)
        .get();

    return querySnapshot.docs.map((doc) {
      final data = doc.data();
      return CategoryModel(
        id: doc.id,
        name: data['name'] ?? 'قسم فرعي غير مسمى',
        imageUrl: data['imageUrl'] ?? '',
        order: (data['order'] as num?)?.toInt() ?? 0,
        status: true,
      );
    }).toList();
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
        appBar: _buildAppBar(),
        body: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
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
            SliverToBoxAdapter(child: _buildBannerSlider()),
            _buildSubCategoriesGrid(),
          ],
        ),
        bottomNavigationBar: _buildModernBottomNav(context, cartProvider),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
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
    );
  }

  Widget _buildBannerSlider() {
    return FutureBuilder<QuerySnapshot>(
      future: _bannersFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return SizedBox(height: 22.h);

        final filteredDocs = snapshot.data!.docs;

        if (filteredDocs.isEmpty) return const SizedBox.shrink();

        return Container(
          height: 22.h,
          margin: EdgeInsets.symmetric(vertical: 2.h),
          child: PageView.builder(
            controller: _pageController,
            itemBuilder: (context, index) {
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
                      Image.network(
                        data['imageUrl'], 
                        fit: BoxFit.cover,
                        cacheWidth: 800,
                      ),
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
    );
  }

  Widget _buildSubCategoriesGrid() {
    return FutureBuilder<List<CategoryModel>>(
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
              (context, index) => _GeneralSubCategoryCard(
                category: subCategories[index],
                mainCategoryId: widget.mainCategoryId,
              ),
              childCount: subCategories.length,
            ),
          ),
        );
      },
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

class _GeneralSubCategoryCard extends StatelessWidget {
  final CategoryModel category;
  final String mainCategoryId;

  const _GeneralSubCategoryCard({
    required this.category,
    required this.mainCategoryId,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).pushNamed(
        ConsumerProductListScreen.routeName,
        arguments: {
          'mainId': mainCategoryId,
          'subId': category.id,
          'ownerId': null, 
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
                  fit: BoxFit.cover,
                  cacheWidth: 400,
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(vertical: 1.5.h, horizontal: 2.w),
              child: Text(
                category.name,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                  color: Color(0xFF2D3142),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}