import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sizer/sizer.dart';
import 'package:my_test_app/theme/app_theme.dart';
import 'package:my_test_app/providers/cart_provider.dart';

final FirebaseFirestore _db = FirebaseFirestore.instance;

class ProductDetailsScreen extends StatefulWidget {
  static const routeName = '/productDetails';
  final String? productId;

  const ProductDetailsScreen({super.key, this.productId});

  @override
  State<ProductDetailsScreen> createState() => _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends State<ProductDetailsScreen> {
  Map<String, dynamic>? _productData;
  List<Map<String, dynamic>> _offers = [];
  bool _isLoading = true;
  String? _currentProductId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map<String, dynamic>) {
      _currentProductId = args['productId']?.toString();
    } else {
      _currentProductId = widget.productId;
    }
    if (_isLoading) _initializeData();
  }

  Future<void> _initializeData() async {
    try {
      if (_currentProductId == null) return;
      
      // جلب بيانات المنتج والعروض
      final results = await Future.wait([
        _db.collection('products').doc(_currentProductId).get(),
        _db.collection('productOffers').where('productId', isEqualTo: _currentProductId).get(),
      ]);

      final productDoc = results[0] as DocumentSnapshot<Map<String, dynamic>>;
      final offersSnap = results[1] as QuerySnapshot<Map<String, dynamic>>;

      if (productDoc.exists) {
        _productData = productDoc.data();
        _productData!['id'] = productDoc.id;
      }

      _offers = offersSnap.docs.map((doc) {
        final data = doc.data();
        // منطق استخراج السعر والوحدة المتوافق مع الـ Provider
        double price = 0.0;
        String unit = "وحدة";
        int stock = 0;

        if (data['units'] != null && (data['units'] as List).isNotEmpty) {
          final first = data['units'][0];
          price = (first['price'] is num) ? first['price'].toDouble() : 0.0;
          unit = first['unitName'] ?? "وحدة";
          stock = (first['availableStock'] is num) ? first['availableStock'].toInt() : 0;
        } else {
          price = (data['price'] is num) ? data['price'].toDouble() : 0.0;
          stock = (data['availableQuantity'] is num) ? data['availableQuantity'].toInt() : 0;
        }

        return {
          ...data,
          'offerId': doc.id,
          'displayPrice': price,
          'displayUnit': unit,
          'calculatedStock': stock,
        };
      }).toList();

    } catch (e) {
      debugPrint("Error initializing: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _addToCart(Map<String, dynamic> offer) async {
    try {
      final cartProvider = Provider.of<CartProvider>(context, listen: false);
      
      // نستخدم نفس البارامترات المعرفة في addItemToCart بملف الـ Provider
      await cartProvider.addItemToCart(
        offerId: offer['offerId'],
        productId: _currentProductId!,
        sellerId: offer['sellerId'] ?? '',
        sellerName: offer['sellerName'] ?? 'تاجر',
        name: _productData?['name'] ?? 'منتج',
        price: (offer['displayPrice'] as num).toDouble(),
        unit: offer['displayUnit'],
        unitIndex: 0, // نمرر 0 لأننا نأخذ أول وحدة دائماً في هذه الصفحة
        imageUrl: (_productData?['imageUrls'] as List?)?.first ?? '',
        userRole: 'buyer', // أو اجلبه من نظام تسجيل الدخول لديك
        quantityToAdd: 1,
        // 🌟 تمرير حقول الأقسام المكتشفة في الـ Provider
        mainId: _productData?['mainId'],
        subId: _productData?['subId'],
        // 🌟 تمرير بيانات المخزن والحدود بدقة لمنع خطأ الـ Exception
        availableStock: offer['calculatedStock'] ?? 999,
        minOrderQuantity: (offer['minOrder'] as num?)?.toInt() ?? 1,
        maxOrderQuantity: (offer['maxOrder'] as num?)?.toInt() ?? 9999,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ تمت الإضافة للسلة'), backgroundColor: Colors.green)
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('⚠️ $e'), backgroundColor: Colors.red)
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(
        title: Text(_productData?['name'] ?? 'تفاصيل المنتج', style: GoogleFonts.cairo()),
        backgroundColor: AppTheme.primaryGreen,
      ),
      // السلة العائمة الموحدة
      floatingActionButton: Consumer<CartProvider>(
        builder: (context, cart, _) => Badge(
          label: Text('${cart.cartTotalItems}'),
          isLabelVisible: cart.cartTotalItems > 0,
          child: FloatingActionButton(
            onPressed: () => Navigator.pushNamed(context, '/cart'),
            backgroundColor: AppTheme.primaryGreen,
            child: const Icon(Icons.shopping_cart, color: Colors.white),
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildImageGallery(),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(_productData?['name'] ?? '', style: GoogleFonts.cairo(fontSize: 22, fontWeight: FontWeight.bold)),
                  Text(_productData?['description'] ?? '', style: GoogleFonts.cairo(color: Colors.grey)),
                  const Divider(height: 30),
                  Text('العروض المتاحة:', style: GoogleFonts.cairo(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  ..._offers.map((offer) => _buildOfferCard(offer)).toList(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageGallery() {
    final images = (_productData?['imageUrls'] as List?) ?? [];
    return SizedBox(
      height: 300,
      child: PageView.builder(
        itemCount: images.length,
        itemBuilder: (context, i) => Image.network(images[i], fit: BoxFit.contain),
      ),
    );
  }

  Widget _buildOfferCard(Map<String, dynamic> offer) {
    return Card(
      child: ListTile(
        title: Text(offer['sellerName'] ?? '', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
        subtitle: Text('${offer['displayPrice']} ج.م / ${offer['displayUnit']}'),
        leading: ElevatedButton(
          onPressed: () => _addToCart(offer),
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryGreen),
          child: const Text('إضافة', style: TextStyle(color: Colors.white)),
        ),
      ),
    );
  }
}
