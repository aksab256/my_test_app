import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sizer/sizer.dart';
import 'package:my_test_app/theme/app_theme.dart';
import 'package:my_test_app/providers/cart_provider.dart';
import 'package:my_test_app/providers/buyer_data_provider.dart'; // ✅ مهم للفلترة الجغرافية
import 'package:my_test_app/utils/offer_data_model.dart'; // ✅ لتوحيد قراءة العرض

final FirebaseFirestore _db = FirebaseFirestore.instance;

class ProductDetailsScreen extends StatefulWidget {
  static const routeName = '/productDetails';
  final String? productId;
  final String? offerId; 

  const ProductDetailsScreen({super.key, this.productId, this.offerId});

  @override
  State<ProductDetailsScreen> createState() => _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends State<ProductDetailsScreen> {
  Map<String, dynamic>? _productData;
  List<OfferModel> _filteredOffers = []; // ✅ نستخدم الموديل الموحد
  bool _isLoading = true;
  String? _currentProductId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _extractArgs();
    if (_isLoading) _initializeData();
  }

  void _extractArgs() {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map<String, dynamic>) {
      _currentProductId = args['productId']?.toString();
    } else {
      _currentProductId = widget.productId;
    }
  }

  Future<void> _initializeData() async {
    try {
      if (_currentProductId == null || _currentProductId!.isEmpty) return;
      
      // 1. جلب بيانات المشتري الحالية (منطقته الجغرافية)
      final buyerProvider = Provider.of<BuyerDataProvider>(context, listen: false);
      final String? userArea = buyerProvider.userAddress;

      // 2. جلب المنتج وكل عروضه النشطة
      final results = await Future.wait([
        _db.collection('products').doc(_currentProductId).get(),
        _db.collection('productOffers')
            .where('productId', isEqualTo: _currentProductId)
            .where('status', isEqualTo: 'active') // ✅ العروض النشطة فقط
            .get(),
      ]);

      final productDoc = results[0] as DocumentSnapshot<Map<String, dynamic>>;
      final offersSnap = results[1] as QuerySnapshot<Map<String, dynamic>>;

      if (productDoc.exists) {
        _productData = productDoc.data();
      }

      // 3. تحويل العروض وفلترتها جغرافياً
      List<OfferModel> allOffers = [];
      for (var doc in offersSnap.docs) {
        allOffers.addAll(OfferModel.fromFirestore(doc));
      }

      // تطبيق نفس منطق الـ Grid: يظهر العرض إذا كان عاماً أو يغطي منطقة المشتري
      setState(() {
        _filteredOffers = allOffers.where((offer) {
          bool isGlobal = offer.deliveryAreas == null || offer.deliveryAreas!.isEmpty;
          bool isMatch = userArea != null && (offer.deliveryAreas?.contains(userArea) ?? false);
          return isGlobal || isMatch;
        }).toList();
      });

    } catch (e) {
      debugPrint("Error initializing details: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _addToCart(OfferModel offer) async {
    try {
      final cartProvider = Provider.of<CartProvider>(context, listen: false);
      final String imageUrl = (_productData?['imageUrls'] as List?)?.isNotEmpty == true
          ? _productData!['imageUrls'][0] : '';

      // ملاحظة: نستخدم البيانات من أول وحدة (unit) في العرض كما فعلت أنت
      final firstUnit = offer.units.isNotEmpty ? offer.units[0] : null;

      await cartProvider.addItemToCart(
        offerId: offer.offerId ?? '',
        productId: _currentProductId!,
        sellerId: offer.sellerId,
        sellerName: offer.sellerName,
        name: _productData?['name'] ?? 'منتج',
        price: firstUnit?.price ?? 0.0,
        unit: firstUnit?.unitName ?? 'وحدة',
        unitIndex: 0,
        imageUrl: imageUrl,
        userRole: 'buyer',
        quantityToAdd: offer.minQty ?? 1,
        mainId: _productData?['mainId'],
        subId: _productData?['subId'],
        availableStock: offer.stock,
        minOrderQuantity: offer.minQty ?? 1,
        maxOrderQuantity: 9999,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ تمت الإضافة للسلة'), backgroundColor: Colors.green)
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('⚠️ $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(
        title: Text(_productData?['name'] ?? 'التفاصيل', style: GoogleFonts.cairo()),
        backgroundColor: AppTheme.primaryGreen,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildImageGallery(),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end, // للتنسيق العربي
                children: [
                  Text(_productData?['name'] ?? '', 
                    style: GoogleFonts.cairo(fontSize: 18.sp, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(_productData?['description'] ?? '', 
                    style: GoogleFonts.cairo(color: Colors.grey),
                  ),
                  const Divider(height: 40),
                  Text('العروض المتاحة في منطقتك', 
                    style: GoogleFonts.cairo(fontSize: 14.sp, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  if (_filteredOffers.isEmpty)
                    const Center(child: Padding(
                      padding: EdgeInsets.all(20.0),
                      child: Text('عذراً، لا توجد عروض لهذا المنتج تغطي منطقتك حالياً'),
                    ))
                  else
                    ..._filteredOffers.map((offer) => _buildOfferItem(offer)).toList(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOfferItem(OfferModel offer) {
    final firstUnit = offer.units.isNotEmpty ? offer.units[0] : null;
    
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        title: Text(offer.sellerName, style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
        subtitle: Text('${firstUnit?.price ?? 0} ج.م / ${firstUnit?.unitName ?? ''}', 
          style: GoogleFonts.cairo(color: AppTheme.primaryGreen, fontWeight: FontWeight.w600)),
        trailing: ElevatedButton(
          onPressed: () => _addToCart(offer),
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryGreen),
          child: const Text('إضافة', style: TextStyle(color: Colors.white)),
        ),
      ),
    );
  }

  Widget _buildImageGallery() {
    final images = (_productData?['imageUrls'] as List?) ?? [];
    if (images.isEmpty) return Container(height: 200, color: Colors.grey[200], child: const Icon(Icons.image));
    return SizedBox(
      height: 250,
      child: PageView.builder(
        itemCount: images.length,
        itemBuilder: (context, index) => Image.network(images[index], fit: BoxFit.contain),
      ),
    );
  }
}
