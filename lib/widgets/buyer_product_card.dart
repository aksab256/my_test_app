// lib/widgets/buyer_product_card.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:my_test_app/widgets/quantity_control.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:my_test_app/utils/offer_data_model.dart';
import 'package:my_test_app/providers/product_offers_provider.dart';
import 'package:my_test_app/providers/cart_provider.dart';
import 'package:my_test_app/providers/buyer_data_provider.dart';
import 'package:my_test_app/services/analytics_service.dart';
import 'package:sizer/sizer.dart';

class BuyerProductCard extends StatefulWidget {
  final String productId;
  final Map<String, dynamic> productData;
  final Function(String productId, String? offerId)? onTap;

  const BuyerProductCard({
    super.key,
    required this.productId,
    required this.productData,
    this.onTap,
  });

  @override
  State<BuyerProductCard> createState() => _BuyerProductCardState();
}

class _BuyerProductCardState extends State<BuyerProductCard> {
  static const String currentUserRole = 'buyer';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final buyerProvider = Provider.of<BuyerDataProvider>(context, listen: false);
      
      List<String> userAreas = [];
      if (buyerProvider.userAddress != null && buyerProvider.userAddress!.isNotEmpty) {
        userAreas.add(buyerProvider.userAddress!);
      }

      Provider.of<ProductOffersProvider>(context, listen: false)
          .fetchOffers(widget.productId, userAreas);
    });
  }

  void _addToCart(OfferModel offer, int qty) async {
    if (qty == 0) return;
    final String imageUrl = widget.productData['imageUrls']?.isNotEmpty == true
        ? widget.productData['imageUrls'][0]
        : '';

    final double finalPrice = (offer.offerPrice != null &&
            (offer.offerPrice is num) &&
            (offer.offerPrice as num) > 0)
        ? (offer.offerPrice as num).toDouble()
        : ((offer.price is num) ? (offer.price as num).toDouble() : 0.0);

    try {
      final cartProvider = Provider.of<CartProvider>(context, listen: false);
      await cartProvider.addItemToCart(
        productId: widget.productId,
        name: widget.productData['name'] ?? 'منتج غير معروف',
        offerId: offer.offerId,
        sellerId: offer.sellerId,
        sellerName: offer.sellerName,
        price: finalPrice,
        unit: offer.unitName,
        unitIndex: offer.unitIndex ?? 0,
        quantityToAdd: qty,
        imageUrl: imageUrl,
        userRole: currentUserRole,
        minOrderQuantity: offer.minQty ?? 1,
        availableStock: offer.stock,
        maxOrderQuantity: offer.maxQty ?? 9999,
        mainId: widget.productData['mainId'],
        subId: widget.productData['subId'],
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ تم الإضافة للسلة', style: GoogleFonts.cairo(fontSize: 14.sp)),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final offersProvider = context.watch<ProductOffersProvider>();
    final isLoadingOffers = offersProvider.isLoading;
    final rawOffers = offersProvider.availableOffers;
    
    // 🎯 ترتيب العروض: العروض التي تحتوي على خصم وسعر خاص تصعد للمقدمة
    final List<OfferModel> availableOffers = List.from(rawOffers)
      ..sort((a, b) {
        final bool aHasDiscount = a.offerPrice != null && (a.offerPrice is num) && (a.offerPrice as num) > 0;
        final bool bHasDiscount = b.offerPrice != null && (b.offerPrice is num) && (b.offerPrice as num) > 0;
        if (aHasDiscount && !bHasDiscount) return -1;
        if (!aHasDiscount && bHasDiscount) return 1;
        return 0;
      });

    final hasOffers = availableOffers.isNotEmpty;

    final bool hasSpecialPrice = availableOffers.any((offer) =>
        offer.offerPrice != null &&
        (offer.offerPrice is num) &&
        (offer.offerPrice as num) > 0);

    final displayImageUrl = widget.productData['imageUrls']?.isNotEmpty == true
        ? widget.productData['imageUrls'][0]
        : 'https://via.placeholder.com/300';

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      margin: EdgeInsets.all(4.sp),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: Padding(
          padding: const EdgeInsets.all(10.0),
          child: Column(
            children: [
              Expanded(
                child: Stack(
                  children: [
                    InkWell(
                      onTap: hasOffers 
                          ? () => widget.onTap?.call(widget.productId, offersProvider.selectedOffer?.offerId)
                          : null,
                      child: Image.network(displayImageUrl, fit: BoxFit.contain, width: double.infinity),
                    ),
                    
                    // 🎯 شريط خصم بروفيشنال جانبي مميز أعلى الكارت
                    if (hasSpecialPrice)
                      Positioned(
                        top: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Color(0xFFD32F2F), Color(0xFFFF5252)],
                            ),
                            borderRadius: BorderRadius.only(
                              topRight: Radius.circular(12),
                              bottomLeft: Radius.circular(12),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black12,
                                blurRadius: 4,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.local_fire_department, color: Colors.amber, size: 12),
                              const SizedBox(width: 3),
                              Text(
                                'خصم خاص',
                                style: GoogleFonts.cairo(
                                  color: Colors.white,
                                  fontSize: 8.5.sp,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.productData['name'] ?? 'منتج غير معروف',
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.cairo(fontWeight: FontWeight.w800, fontSize: 12.5.sp),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: (isLoadingOffers || !hasOffers) 
                      ? null 
                      : () {
                          // 📊 تسجيل الحدث في الخلفية فوراً بدون أية انتظار لسرعة الفرونت إند
                          AnalyticsService.logEvent(
                            eventName: 'click_view_offers',
                            eventData: {
                              'productId': widget.productId,
                              'productName': widget.productData['name'] ?? '',
                              'mainId': widget.productData['mainId'] ?? '',
                              'subId': widget.productData['subId'] ?? '',
                              'offersCount': availableOffers.length,
                            },
                          );

                          // فتح المنسدلة مباشرة دون تأخير
                          _showOfferSelectionModal(context, availableOffers, offersProvider);
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: !hasOffers ? Colors.grey : const Color(0xFFFF7000),
                    padding: EdgeInsets.symmetric(vertical: 10.sp),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: isLoadingOffers
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(hasOffers ? Icons.shopping_cart_outlined : Icons.block, color: Colors.white, size: 14.sp),
                            const SizedBox(width: 8),
                            Text(
                              hasOffers ? 'عرض الأسعار' : 'غير متوفر بمدينتك',
                              style: GoogleFonts.cairo(fontSize: 11.sp, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showOfferSelectionModal(BuildContext context, List<OfferModel> availableOffers, ProductOffersProvider provider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (modalContext) {
        return Container(
          padding: EdgeInsets.fromLTRB(15, 20, 15, 30.sp),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('اختيار العرض والطلب', style: GoogleFonts.cairo(fontSize: 16.sp, fontWeight: FontWeight.bold)),
              const Divider(),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    children: availableOffers.map((offer) {
                      final bool isOutOfStock = (offer.stock) <= 0;
                      final bool hasOfferPrice = offer.offerPrice != null &&
                          (offer.offerPrice is num) &&
                          (offer.offerPrice as num) > 0;

                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: hasOfferPrice ? Colors.orange.shade300 : Colors.grey.shade200,
                            width: hasOfferPrice ? 1.5 : 1.0,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: RichText(
                                      text: TextSpan(
                                        children: [
                                          // 🎯 تمييز لون واسم التاجر داخل المنسدلة
                                          TextSpan(
                                            text: '${offer.sellerName} ',
                                            style: GoogleFonts.cairo(
                                              fontSize: 12.5.sp,
                                              fontWeight: FontWeight.w900,
                                              color: const Color(0xFF1E3A8A), // لون أزرق داكن مميز للتاجر
                                            ),
                                          ),
                                          TextSpan(
                                            text: '(${offer.unitName})',
                                            style: GoogleFonts.cairo(
                                              fontSize: 11.sp,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.grey.shade700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  
                                  if (hasOfferPrice) ...[
                                    Row(
                                      children: [
                                        Text(
                                          '${offer.price} ج',
                                          style: GoogleFonts.cairo(
                                            fontSize: 10.5.sp,
                                            color: Colors.grey.shade600,
                                            decoration: TextDecoration.lineThrough,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          '${offer.offerPrice} ج',
                                          style: GoogleFonts.cairo(
                                            fontSize: 14.sp,
                                            fontWeight: FontWeight.w900,
                                            color: Colors.red.shade700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ] else ...[
                                    Text(
                                      '${offer.price} ج',
                                      style: GoogleFonts.cairo(
                                        fontSize: 14.sp,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.red.shade700,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  _tag("متوفر: ${offer.stock}", isOutOfStock ? Colors.red : Colors.green),
                                  const SizedBox(width: 8),
                                  _tag("أقل طلب: ${offer.minQty}", Colors.blueGrey),
                                ],
                              ),
                              const SizedBox(height: 15),
                              Row(
                                children: [
                                  Expanded(
                                    flex: 2,
                                    child: QuantityControl(
                                      initialQuantity: provider.currentQuantity < (offer.minQty ?? 1) ? (offer.minQty ?? 1) : provider.currentQuantity,
                                      minQuantity: offer.minQty ?? 1,
                                      maxStock: offer.stock,
                                      onQuantityChanged: (qty) => provider.updateQuantity(qty),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: isOutOfStock ? null : () {
                                        _addToCart(offer, provider.currentQuantity);
                                        Navigator.pop(modalContext);
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green.shade800,
                                        padding: const EdgeInsets.symmetric(vertical: 8),
                                      ),
                                      child: Text(
                                        'أضف',
                                        style: GoogleFonts.cairo(
                                          color: Colors.white,
                                          fontSize: 11.sp,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _tag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
      child: Text(text, style: GoogleFonts.cairo(fontSize: 10.sp, color: color, fontWeight: FontWeight.bold)),
    );
  }
}