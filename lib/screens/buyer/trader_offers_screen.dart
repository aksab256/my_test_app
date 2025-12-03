// lib/screens/buyer/trader_offers_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:my_test_app/theme/app_theme.dart';
import 'package:my_test_app/providers/cart_provider.dart';

// ⚠️ تم تعطيل الاستيراد مؤقتاً لحل خطأ التجميع حتى يتم إنشاء الملف
// import 'package:my_test_app/screens/buyer/product_details_screen.dart'; 
import 'package:my_test_app/widgets/trader_offer_card.dart';

class TraderOffersScreen extends StatelessWidget {
  static const String routeName = '/traderOffers';
  final String sellerId;
  const TraderOffersScreen({super.key, required this.sellerId});

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false, 
        toolbarHeight: 60,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                isDarkMode ? const Color(0xff34495e) : const Color(0xff74d19c),
                isDarkMode ? const Color(0xff1e2a3b) : AppTheme.primaryGreen,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 5),
                  Row(
                    children: [
                      const Icon(Icons.storefront_rounded, color: Colors.white, size: 22),
                      const SizedBox(width: 10),
                      Text(
                        'أسواق أكسب',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontFamily: Theme.of(context).textTheme.bodyLarge!.fontFamily,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Icon(isDarkMode ? Icons.wb_sunny_rounded : Icons.nights_stay_rounded, color: Colors.white, size: 20),
            ],
          ),
        ),
      ),
      // 2. جسم الصفحة: جلب البيانات
      body: OffersDataFetcher(sellerId: sellerId), 
      bottomNavigationBar: _buildMockBottomNav(context),
    );
  }

  // ... (دوال شريط التنقل السفلي Mock)
  Widget _buildMockBottomNav(BuildContext context) {
    // محاكاة لـ Bottom Nav من كود HTML
    return Container(
      height: 70,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withOpacity(0.1),
            spreadRadius: 2,
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(15), 
          topRight: Radius.circular(15)
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavItem(context, Icons.home_rounded, 'المتجر', '/'), 
          _buildNavItem(context, Icons.search_rounded, 'البحث', '/'), 
          _buildNavItem(context, Icons.shopping_cart_rounded, 'السلة', '/cart'), 
          _buildNavItem(context, Icons.store_rounded, 'التجار', '/traders', isActive: true), 
          _buildNavItem(context, Icons.person_rounded, 'حسابي', '/'), 
        ],
      ),
    );
  }
  
  Widget _buildNavItem(BuildContext context, IconData icon, String label, String routeName, {bool isActive = false}) {
    final color = isActive ? AppTheme.primaryGreen : (Theme.of(context).brightness == Brightness.dark ? const Color(0xffb0b0b0) : const Color(0xff888888));
    return InkWell(
      onTap: () {
        if (routeName == '/traders') {
           Navigator.of(context).pop(); 
        } else if (routeName != '/') {
           Navigator.of(context).pushNamed(routeName);
        }
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 22, color: color),
          const SizedBox(height: 5),
          Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }
}

// =========================================================================
// 🎯 الكلاس الجديد: OffersDataFetcher (جلب البيانات ودمجها)
// =========================================================================
class OffersDataFetcher extends StatefulWidget {
  final String sellerId;
  const OffersDataFetcher({super.key, required this.sellerId});

  @override
  State<OffersDataFetcher> createState() => _OffersDataFetcherState();
}

class _OffersDataFetcherState extends State<OffersDataFetcher> {
  String _sellerName = "التاجر";
  late Future<List<Map<String, dynamic>>> _offersFuture;

  @override
  void initState() {
    super.initState();
    _offersFuture = _loadOffersWithProductData();
  }

  // ⭐️ دالة دمج البيانات: تجلب العرض ثم تجلب بيانات الصورة من المنتج الأصلي
  Future<List<Map<String, dynamic>>> _loadOffersWithProductData() async {
    final db = FirebaseFirestore.instance;
    
    // 1. جلب اسم التاجر وتحديث العنوان
    try {
      final sellerDoc = await db.doc("sellers/${widget.sellerId}").get();
      if (sellerDoc.exists) {
        if (mounted) {
          setState(() {
            _sellerName = sellerDoc.data()?['fullname']?.toString() ?? "التاجر";
          });
        }
      }
    } catch (e) {
      debugPrint("Error fetching seller name: $e");
    }

    // 2. جلب العروض من مجموعة productOffers
    final offersSnapshot = await db.collection("productOffers")
              .where("sellerId", isEqualTo: widget.sellerId)
              .get();
    
    if (offersSnapshot.docs.isEmpty) {
      return [];
    }

    final offersWithProducts = <Map<String, dynamic>>[];
    
    // 3. التكرار وحقن بيانات المنتج (imageUrls)
    for (var offerDoc in offersSnapshot.docs) {
        final offerData = offerDoc.data();
        final productId = offerData['productId']?.toString();
        
        if (productId != null) {
            // جلب مستند المنتج للحصول على الصورة
            final productSnap = await db.doc("products/$productId").get();
            
            if (productSnap.exists) {
                final productData = productSnap.data()!;
                
                // ⭐️ النقطة المحورية: حقن حقل imageUrls من 'products' إلى 'offerData'
                final List<dynamic>? imageUrls = productData['imageUrls'] as List<dynamic>?;
                
                final combinedData = {
                    ...offerData, 
                    'offerDocId': offerDoc.id, // إضافة الـ ID كمعرّف
                    'productName': productData['name']?.toString() ?? 'منتج غير معروف',
                    'imageUrls': imageUrls, // ✅ حقن حقل imageUrls
                };
                
                offersWithProducts.add(combinedData);
            }
        }
    }
    
    return offersWithProducts;
  }

  // 💡 وظيفة مساعدة لفتح شاشة تفاصيل المنتج
  void _openProductDetails(String offerDocId) {
    // تم تعطيل التوجيه مؤقتاً لحل خطأ "الملف غير موجود"
    // Navigator.of(context).pushNamed(
    //   ProductDetailsScreen.routeName,
    //   arguments: {'offerDocId': offerDocId},
    // );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _offersFuture,
      builder: (context, snapshot) {
        
        // 1. العنوان الرئيسي
        final titleWidget = Padding(
          padding: const EdgeInsets.symmetric(vertical: 20.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 🎯 التصحيح: استبدال Icons.box_open بـ Icons.local_shipping
              const Icon(Icons.local_shipping, color: AppTheme.primaryGreen, size: 28), 
              const SizedBox(width: 8),
              Text(
                'عروض ${_sellerName}',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).textTheme.bodyLarge!.color,
                ),
              ),
            ],
          ),
        );

        // 2. حالة التحميل
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Column(
            children: [titleWidget, const Expanded(child: Center(child: CircularProgressIndicator()))],
          );
        }
        
        // 3. حالة الخطأ
        if (snapshot.hasError) {
           debugPrint("Offers Data Error: ${snapshot.error}");
           return Column(
            children: [titleWidget, const Expanded(child: Center(child: Text('حدث خطأ أثناء تحميل العروض.')))],
          );
        }

        final offers = snapshot.data;
        
        // 4. حالة القائمة الفارغة
        if (offers == null || offers.isEmpty) {
          return Column(
            children: [
              titleWidget, 
              // 🎯 التصحيح: إضافة 'child:' لـ Center لحل خطأ "Too many positional arguments"
              const Expanded(child: Center(child: Text('لا توجد عروض حالياً لهذا التاجر.'))), 
            ],
          );
        }
        
        // 5. حالة عرض البيانات
        return Column(
          children: [
            titleWidget,
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.only(top: 0, bottom: 20, left: 10, right: 10),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2, 
                  childAspectRatio: 0.65, 
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemCount: offers.length,
                itemBuilder: (context, index) {
                  final offer = offers[index];
                  final offerDocId = offer['offerDocId'] as String;
                  
                  return TraderOfferCard(
                    offerData: offer,
                    offerDocId: offerDocId,
                    onTap: () => _openProductDetails(offerDocId),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
