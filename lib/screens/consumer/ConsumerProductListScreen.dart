// lib/screens/consumer/ConsumerProductListScreen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
// استيراد الخدمات والنماذج
import 'package:my_test_app/services/marketplace_data_service.dart';
import 'package:my_test_app/models/product_model.dart';
import 'package:my_test_app/models/offer_model.dart'; // يحتوي على ProductOfferModel
import 'package:my_test_app/providers/theme_notifier.dart';
import 'package:my_test_app/providers/cart_provider.dart';
// 💡 [التصحيح 1]: استيراد شاشة التفاصيل الجديدة للمستهلكين
import 'package:my_test_app/screens/consumer/consumer_product_details_screen.dart';

class ConsumerProductListScreen extends StatefulWidget {
  static const routeName = '/consumerProducts'; // المسار الجديد

  final String ownerId;
  final String mainId;
  final String subId;
  final String subCategoryName;

  const ConsumerProductListScreen({
    super.key,
    required this.ownerId,
    required this.mainId,
    required this.subId,
    required this.subCategoryName,
  });

  @override
  State<ConsumerProductListScreen> createState() => _ConsumerProductListScreenState();
}

class _ConsumerProductListScreenState extends State<ConsumerProductListScreen> {
  final MarketplaceDataService _dataService = MarketplaceDataService();
  late Future<List<Map<String, dynamic>>> _productsFuture;

  @override
  void initState() {
    super.initState();
    _productsFuture = _fetchProductsWithOffers();
  }

  // 1. دالة جلب المنتجات مع العروض الخاصة بالمتجر المحدد
  Future<List<Map<String, dynamic>>> _fetchProductsWithOffers() async {
    return _dataService.fetchProductsAndOffersBySubCategory(
      ownerId: widget.ownerId,
      mainId: widget.mainId,
      subId: widget.subId,
    );
  }

  // 2. دالة الإضافة إلى السلة
  void _addToCart(
      BuildContext context, ProductModel product, ProductOfferModel offer) async {
    final cartProvider = Provider.of<CartProvider>(context, listen: false);

    // استخدام الوحدة الأولى فقط كما في JS
    if (offer.units.isEmpty) return;
    final firstUnit = offer.units.first;
    // 💡 الحصول على الاسم المُمرَّر الأصلي (للتشخيص)
    final passedName = offer.sellerName!;

    try {
      // 🎯 [التصحيح]: مطابقة الوسائط المسماة الجديدة وحل مشاكل String?
      await cartProvider.addItemToCart(
        productId: product.id,
        name: product.name,
        offerId: offer.id!,
        sellerId: offer.sellerId!, // الآن يجب أن يكون هذا الحقل مُعبأً من ownerId
        sellerName: passedName,
        unitIndex: 0,
        unit: firstUnit.unitName,
        price: firstUnit.price,
        quantityToAdd: 1,
        // 🟢 [التصحيح المطلوب]: إضافة وسيطة userRole للدور الثابت 'consumer'
        userRole: 'consumer',
        // 🟢 تحديث اسم الحقل من imageUrl إلى imageUrls
        imageUrl: product.imageUrls.isNotEmpty ? product.imageUrls.first : '',
      );

      // 🟢 رسالة النجاح (تم التعديل لتكون أوضح)
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم إضافة المنتج بنجاح إلى السلة.',
              textDirection: TextDirection.rtl),
          duration: Duration(seconds: 3),
          backgroundColor: Color(0xFF4CAF50), // أخضر
        ),
      );
    } catch (e) {
      // 🛑 رسالة الخطأ التشخيصية (هذا المسار سيُنفذ إذا فشل جلب الاسم الموثوق من deliverySupermarkets)
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('فشل الإضافة. الرسالة التشخيصية: $e',
              textDirection: TextDirection.rtl),
          duration: const Duration(seconds: 6),
          backgroundColor: Theme.of(context).colorScheme.error, // أحمر
        ),
      );
    }
  }

  // 3. بناء واجهة كارت المنتج (Product Card)
  Widget _buildProductCard(
      BuildContext context, Map<String, dynamic> productOfferMap) {
    final product = productOfferMap['product'] as ProductModel;
    final offer = productOfferMap['offer'] as ProductOfferModel;

    // التأكد من وجود وحدة وسعر
    if (offer.units.isEmpty || offer.units.first.price <= 0) {
      return const SizedBox.shrink();
    }
    final firstUnit = offer.units.first;
    final price = firstUnit.price;

    final themeNotifier =
        Provider.of<ThemeNotifier>(context, listen: false);
    final shadowColor =
        themeNotifier.isDarkMode ? Colors.black45 : Colors.black12;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () {
          // 🎯 [التصحيح 3]: التوجيه إلى شاشة تفاصيل المنتج للمستهلكين
          Navigator.of(context).pushNamed(
            ConsumerProductDetailsScreen.routeName,
            arguments: {
              'productId': product.id,
              'offerId': offer.id,
              // لا نحتاج ownerId هنا، لأنه موجود ضمن offer
            },
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // الصورة
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(10)),
              child: Image.network(
                // 🎯 [تصحيح]: استخدام product.imageUrls.first
                product.imageUrls.isNotEmpty
                    ? product.imageUrls.first
                    : 'https://via.placeholder.com/150',
                height: 120,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => const SizedBox(
                    height: 120,
                    child: Center(
                        child: Icon(Icons.broken_image,
                            size: 40, color: Colors.grey))),
              ),
            ),
            // المعلومات
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // اسم المنتج (يحتل سطرين كحد أقصى)
                  Text(
                    product.name,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 5),
                  // السعر
                  Text(
                    '${price.toStringAsFixed(2)} ج.م',
                    style: TextStyle(
                      fontSize: 18,
                      color: Theme.of(context).colorScheme.error, // استخدام لون خطأ للسعر (أحمر)
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  // زر الإضافة للسلة
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _addToCart(context, product, offer),
                      icon: const Icon(FontAwesomeIcons.cartPlus,
                          size: 16, color: Colors.white),
                      label: const Text('أضف إلى السلة',
                          style: TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            const Color(0xFF4CAF50), // لون الزر الأخضر
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 🛑 [خطأ 5]: itemCount (تم إضافتها في CartProvider.dart)
    final cartCount = Provider.of<CartProvider>(context).itemCount;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        // Top Header
        appBar: AppBar(
          backgroundColor:
              const Color(0xFF4a6491), // لون الخلفية مطابق لـ CSS
          foregroundColor: Colors.white,
          title: Text(
            widget.subCategoryName,
            style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white),
          ),
          centerTitle: true,
        ),
        body: FutureBuilder<List<Map<String, dynamic>>>(
          future: _productsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              // حالة التحميل
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 15),
                    Text('جاري تحميل المنتجات...',
                        style: TextStyle(fontSize: 18)),
                  ],
                ),
              );
            }
            if (snapshot.hasError) {
              // حالة الخطأ
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Text(
                    'حدث خطأ أثناء تحميل المنتجات: ${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red, fontSize: 18),
                  ),
                ),
              );
            }

            final products = snapshot.data ?? [];
            if (products.isEmpty) {
              // حالة لا توجد منتجات
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(20.0),
                  child: Text(
                    'لا توجد منتجات متاحة لهذا القسم حالياً في هذا المتجر.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                ),
              );
            }

            // عرض المنتجات في Grid
            return GridView.builder(
              padding: const EdgeInsets.all(15),
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2, // عمودين
                crossAxisSpacing: 15,
                mainAxisSpacing: 15,
                childAspectRatio: 0.7, // لكي يتسع الكارت بشكل جيد
              ),
              itemCount: products.length,
              itemBuilder: (context, index) {
                return _buildProductCard(context, products[index]);
              },
            );
          },
        ),

        // Bottom Navigation Bar (تقليد الموجود في HTML)
        bottomNavigationBar: _buildMobileNav(context, cartCount),
      ),
    );
  }

  // دالة بناء شريط التنقل السفلي
  Widget _buildMobileNav(BuildContext context, int cartCount) {
    // تقليد لـ .bottom-nav
    final inactiveColor =
        Theme.of(context).colorScheme.onSurface.withOpacity(0.7);
    final activeColor = Theme.of(context).colorScheme.primary; // استخدام Primary Color للنشط

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withOpacity(0.1),
            blurRadius: 10,
          ),
        ],
      ),
      padding: const EdgeInsets.only(top: 10, bottom: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          // الرئيسية
          _buildNavItem(context, FontAwesomeIcons.home, 'الرئيسية',
              '/marketplaceHome',
              isActive: false, targetRoute: '/marketplaceHome'),
          // السلة
          _buildNavItem(context, FontAwesomeIcons.shoppingCart, 'السلة',
              '/cart',
              isActive: false, count: cartCount, targetRoute: '/cart'),
          // التجار
          _buildNavItem(context, FontAwesomeIcons.store, 'التجار',
              '/consumerStoreSearch',
              isActive: false, targetRoute: '/consumerStoreSearch'),
        ],
      ),
    );
  }

  // دالة بناء عنصر في شريط التنقل السفلي
  Widget _buildNavItem(BuildContext context, IconData icon, String label,
      String route,
      {required bool isActive, int count = 0, String? targetRoute}) {
    final inactiveColor =
        Theme.of(context).colorScheme.onSurface.withOpacity(0.7);
    final activeColor = Theme.of(context).colorScheme.primary;

    return InkWell(
      onTap: () {
        if (targetRoute != null) {
          // التوجيه
          Navigator.of(context).pushNamed(targetRoute);
        }
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(
                icon,
                size: 22,
                color: isActive ? activeColor : inactiveColor,
              ),
              if (count > 0 && targetRoute == '/cart')
                Positioned(
                  top: -5,
                  right: -10,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      count.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: isActive ? activeColor : inactiveColor,
            ),
          ),
        ],
      ),
    );
  }
}
