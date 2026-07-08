// lib/screens/consumer/consumer_general_product_list_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:sizer/sizer.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:my_test_app/providers/cart_provider.dart';
import 'package:my_test_app/widgets/buyer_product_header.dart';
import 'package:my_test_app/screens/consumer/consumer_widgets.dart';
import '../../theme/app_theme.dart';

class ConsumerGeneralProductListScreen extends StatefulWidget {
  static const routeName = '/general-product-list';
  const ConsumerGeneralProductListScreen({super.key});

  @override
  State<ConsumerGeneralProductListScreen> createState() => _ConsumerGeneralProductListScreenState();
}

class _ConsumerGeneralProductListScreenState extends State<ConsumerGeneralProductListScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  String _selectedCity = "الإسكندرية"; // القيمة الافتراضية

  @override
  Widget build(BuildContext context) {
    final dynamic rawArgs = ModalRoute.of(context)?.settings.arguments;
    final Map<String, dynamic> args = (rawArgs is Map<String, dynamic>) ? rawArgs : {};

    final String subId = args['subId'] ?? '';
    final String title = args['subCategoryName'] ?? 'المنتجات العامة';
    
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        appBar: BuyerProductHeader(
          title: title,
          isLoading: false,
        ),
        body: SafeArea(
          child: _buildGeneralProductGrid(subId),
        ),
        bottomNavigationBar: Consumer<CartProvider>(
          builder: (context, cart, _) => ConsumerFooterNav(
            cartCount: cart.itemCount,
            activeIndex: -1,
          ),
        ),
        floatingActionButton: _buildFloatingCart(),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      ),
    );
  }

  Widget _buildGeneralProductGrid(String subId) {
    return StreamBuilder<QuerySnapshot>(
      stream: _db.collection('productOffers')
          .where('subCategoryId', isEqualTo: subId)
          .where('status', isEqualTo: 'active')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildUIDebugger(
            title: "🛑 خطأ في الفايربيز (احتمال كبير نقص فهرس مجمع)",
            errorDetails: snapshot.error.toString(),
            rawDocs: const [],
            subId: subId,
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildUIDebugger(
            title: "⚠️ لا توجد منتجات خام في السيرفر لهذا القسم",
            errorDetails: "تم البحث بـ subCategoryId: '$subId' و حالة active ولم نجد شيئاً في مجموعة productOffers.",
            rawDocs: const [],
            subId: subId,
          );
        }

        final List<DocumentSnapshot> rawDocs = snapshot.data!.docs;
        final allOffers = rawDocs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          data['offerId'] = doc.id;
          return data;
        }).where((offer) {
          final List<dynamic> areas = offer['deliveryAreas'] as List? ?? [];
          return areas.contains(_selectedCity);
        }).toList();

        if (allOffers.isEmpty) {
          return _buildUIDebugger(
            title: "📍 المنتجات موجودة بالسيرفر لكن اختفت بسبب فلترة المدينة!",
            errorDetails: "المدينة الحالية للتطبيق هي '$_selectedCity'. المنتجات المتاحة بالسيرفر مسجلة بمدن أخرى لا تطابق حروفها مدينتك الحالية.",
            rawDocs: rawDocs,
            subId: subId,
          );
        }

        final Map<String, List<Map<String, dynamic>>> groupedProducts = {};
        for (var offer in allOffers) {
          final String pId = offer['productId'] ?? '';
          if (pId.isNotEmpty) {
            if (!groupedProducts.containsKey(pId)) {
              groupedProducts[pId] = [];
            }
            groupedProducts[pId]!.add(offer);
          }
        }

        final productIds = groupedProducts.keys.toList();
        return GridView.builder(
          padding: EdgeInsets.fromLTRB(3.w, 2.h, 3.w, 15.h),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.58,
            crossAxisSpacing: 3.w,
            mainAxisSpacing: 3.w,
          ),
          itemCount: productIds.length,
          itemBuilder: (context, index) {
            final currentProductId = productIds[index];
            final List<Map<String, dynamic>> offersForThisProduct = groupedProducts[currentProductId]!;
            
            return _GeneralProductGroupCard(
              productId: currentProductId,
              offers: offersForThisProduct,
            );
          },
        );
      },
    );
  }

  Widget _buildUIDebugger({
    required String title,
    required String errorDetails,
    required List<DocumentSnapshot> rawDocs,
    required String subId,
  }) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bug_report, size: 60, color: Colors.orange[700]),
            const SizedBox(height: 10),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87)),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red[700], foregroundColor: Colors.white),
              icon: const Icon(Icons.error_outline),
              label: const Text("اضغط لعرض الخطأ الفعلي ورابط الفهرس مجمع"),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text("تفاصيل فحص السيرفر والخطأ"),
                    content: SingleChildScrollView(
                      child: SelectableText("رقم القسم المرسل (subId): $subId\n\nنص الخطأ والروابط:\n$errorDetails"),
                    ),
                    actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("إغلاق"))],
                  ),
                );
              },
            ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[700], foregroundColor: Colors.white),
              icon: const Icon(Icons.location_city),
              label: const Text("اضغط لفحص ومقارنة مناطق التوصيل المتاحة"),
              onPressed: () {
                String areaReport = "المدينة الحالية في التطبيق: '$_selectedCity'\n\n";
                if (rawDocs.isEmpty) {
                  areaReport += "لا توجد مستندات خام بالسيرفر لمقارنتها.";
                } else {
                  areaReport += "المدن المسجلة بالمنتجات المتاحة في السيرفر حالياً:\n";
                  for (var i = 0; i < rawDocs.length; i++) {
                    final d = rawDocs[i].data() as Map<String, dynamic>? ?? {};
                    final name = d['productName'] ?? 'بدون اسم';
                    final areas = d['deliveryAreas'] as List? ?? [];
                    areaReport += "${i + 1}. المنتج: ($name) -> مدن التوصيل: $areas\n";
                  }
                }
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text("فحص ومقارنة النطاق الجغرافي"),
                    content: SingleChildScrollView(child: SelectableText(areaReport)),
                    actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("إغلاق"))],
                  ),
                );
              },
            ),
            const SizedBox(height: 30),
            Text("إجمالي المنتجات الخام المستلمة: ${rawDocs.length}", style: TextStyle(color: Colors.grey[600], fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingCart() {
    return Consumer<CartProvider>(
      builder: (context, cart, _) {
        if (cart.itemCount == 0) return const SizedBox.shrink();
        return FloatingActionButton.extended(
          onPressed: () => Navigator.pushNamed(context, '/cart'),
          backgroundColor: AppTheme.primaryGreen,
          label: Text("سلة المشتريات (${cart.itemCount})",
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'Tajawal')),
          icon: const Icon(Icons.shopping_basket, color: Colors.white),
        );
      },
    );
  }
}

class _GeneralProductGroupCard extends StatefulWidget {
  final String productId;
  final List<Map<String, dynamic>> offers;
  const _GeneralProductGroupCard({required this.productId, required this.offers});

  @override
  State<_GeneralProductGroupCard> createState() => _GeneralProductGroupCardState();
}

class _GeneralProductGroupCardState extends State<_GeneralProductGroupCard> {
  late Map<String, dynamic> _selectedOffer;

  @override
  void initState() {
    super.initState();
    widget.offers.sort((a, b) {
      final List unitsA = a['units'] as List? ?? [];
      final List unitsB = b['units'] as List? ?? [];
      final double priceA = unitsA.isNotEmpty ? (unitsA[0]['price'] as num).toDouble() : 0.0;
      final double priceB = unitsB.isNotEmpty ? (unitsB[0]['price'] as num).toDouble() : 0.0;
      return priceA.compareTo(priceB);
    });
    _selectedOffer = widget.offers.first;
  }

  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<CartProvider>(context);
    final String pName = _selectedOffer['productName'] ?? 'منتج';
    final String? imgUrl = _selectedOffer['imageUrl'];

    final List units = _selectedOffer['units'] as List? ?? [];
    final firstUnit = units.isNotEmpty ? units[0] : {'unitName': 'وحدة', 'price': 0.0, 'availableStock': 0};
    final double price = (firstUnit['price'] as num).toDouble();

    int quantity = 0;
    var cartItem;
    try {
      cartItem = cart.sellersOrders.values
          .expand((s) => s.items)
          .firstWhere((i) => i.offerId == _selectedOffer['offerId']);
      quantity = cartItem.quantity;
    } catch (_) {}

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 4,
            child: Container(
              padding: const EdgeInsets.all(8.0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: imgUrl != null && imgUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: imgUrl,
                        fit: BoxFit.contain,
                        placeholder: (context, url) => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                        errorWidget: (context, url, error) => const Icon(Icons.image, color: Colors.grey, size: 40),
                      )
                    : const Icon(Icons.image, color: Colors.grey, size: 40),
              ),
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            child: Text(
              pName,
              maxLines: 1,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'Tajawal'),
              overflow: TextOverflow.ellipsis,
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!, width: 0.8),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<Map<String, dynamic>>(
                  value: _selectedOffer,
                  isExpanded: true,
                  icon: const Icon(Icons.arrow_drop_down, color: Colors.grey, size: 20),
                  style: const TextStyle(fontSize: 11, color: Colors.black87, fontFamily: 'Tajawal'),
                  items: widget.offers.map((Map<String, dynamic> offer) {
                    final currentUnits = offer['units'] as List? ?? [];
                    final currentFirstUnit = currentUnits.isNotEmpty ? currentUnits[0] : {'price': 0.0};
                    final double currentPrice = (currentFirstUnit['price'] as num).toDouble();
                    final String sellerName = offer['sellerName'] ?? 'تاجر غير معروف';

                    return DropdownMenuItem<Map<String, dynamic>>(
                      value: offer,
                      child: Text(
                        "$sellerName ($currentPrice ج.م)",
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    );
                  }).toList(),
                  onChanged: (Map<String, dynamic>? newValue) {
                    if (newValue != null) {
                      setState(() {
                        _selectedOffer = newValue;
                      });
                    }
                  },
                ),
              ),
            ),
          ),

          const Spacer(),
          
          Center(
            child: Text(
              "$price ج.م",
              style: TextStyle(color: AppTheme.primaryGreen, fontWeight: FontWeight.w900, fontSize: 13.sp, fontFamily: 'Tajawal'),
            ),
          ),
          Center(
            child: Text(
              "${firstUnit['unitName']} - متوفر (${firstUnit['availableStock']})",
              style: const TextStyle(color: Colors.grey, fontSize: 10, fontFamily: 'Tajawal'),
            ),
          ),
          
          const SizedBox(height: 6),
          
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: quantity == 0
                ? InkWell(
                    onTap: () => _addToCart(cart, firstUnit, pName, imgUrl ?? ''),
                    child: Container(
                      height: 35,
                      width: double.infinity,
                      decoration: BoxDecoration(color: AppTheme.primaryGreen, borderRadius: BorderRadius.circular(8)),
                      child: const Center(
                        child: Text("إضافة للسلة", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'Tajawal'))),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _qtyBtn(Icons.add, () => cart.changeQty(cartItem, 1, 'consumer'), Colors.green),
                      Text("$quantity", style: const TextStyle(fontWeight: FontWeight.bold)),
                      _qtyBtn(Icons.remove, () => cart.changeQty(cartItem, -1, 'consumer'), Colors.red),
                    ],
                  ),
          )
        ],
      ),
    );
  }

  Widget _qtyBtn(IconData icon, VoidCallback tap, Color color) {
    return InkWell(
      onTap: tap,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(border: Border.all(color: color.withOpacity(0.5)), borderRadius: BorderRadius.circular(6)),
        child: Icon(icon, size: 16, color: color),
      ),
    );
  }

  // دالة الإضافة المعدلة والمطابقة تماماً لـ CartProvider
  Future<void> _addToCart(CartProvider cart, dynamic unit, String name, String img) async {
    try {
      await cart.addItemToCart(
        offerId: _selectedOffer['offerId']?.toString() ?? '',
        productId: _selectedOffer['productId']?.toString() ?? '',
        sellerId: _selectedOffer['sellerId']?.toString() ?? '',
        sellerName: _selectedOffer['sellerName'] ?? 'التاجر',
        name: name,
        price: (unit['price'] as num).toDouble(),
        unit: unit['unitName']?.toString() ?? 'وحدة',
        unitIndex: 0, // المؤشر الافتراضي للوحدة الأولى المعروضة
        quantityToAdd: 1,
        imageUrl: img,
        userRole: 'consumer',
        mainId: _selectedOffer['mainCategoryId']?.toString(), // جلب معرف القسم الرئيسي إن وجد
        subId: _selectedOffer['subCategoryId']?.toString(),   // جلب معرف القسم الفرعي إن وجد
        minOrderQuantity: (_selectedOffer['minOrder'] as num?)?.toInt() ?? 1,
        availableStock: (unit['availableStock'] as num?)?.toInt() ?? 9999,
        maxOrderQuantity: (_selectedOffer['maxOrder'] as num?)?.toInt() ?? 9999,
      );

      // تنبيه نجاح العملية
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم إضافة المنتج إلى السلة بنجاح'),
          backgroundColor: AppTheme.primaryGreen,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (error) {
      // التعامل الذكي مع أخطاء القيود والمخزون وعرضها للمستخدم
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceAll('Exception: ', '')),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }
}