// lib/widgets/gift_promo_card.dart
//
// بطاقة عرض هدية موحدة: تبويب الهدايا + قسم «اكسب هدايا».
// تعرض كل السطور (AND) + الهدية + القيود، بزرين:
// إضافة العرض للسلة (بكامل الشروط) وزيارة صفحة التاجر.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:sizer/sizer.dart';
import 'package:my_test_app/providers/buyer_data_provider.dart';
import 'package:my_test_app/providers/cart_provider.dart';
import 'package:my_test_app/screens/buyer/trader_offers_screen.dart';
import 'package:my_test_app/utils/seller_geo.dart';
import 'package:my_test_app/services/gift_eligibility_service.dart';

class GiftPromoCard extends StatefulWidget {
  final EnrichedGift gift;
  final bool compact;

  const GiftPromoCard({super.key, required this.gift, this.compact = false});

  @override
  State<GiftPromoCard> createState() => _GiftPromoCardState();
}

class _GiftPromoCardState extends State<GiftPromoCard> {
  bool _adding = false;

  EnrichedGift get g => widget.gift;

  void _visitMerchant() {
    Navigator.pushNamed(
      context,
      TraderOffersScreen.routeName,
      arguments: g.sellerId,
    );
  }

  Future<void> _addOfferToCart() async {
    if (_adding) return;
    if (g.isMinOrder) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'هذا العرض يُطبق تلقائياً في السلة عند بلوغ ${g.minOrderValue.toStringAsFixed(0)} ج من ${g.sellerName}',
            style: GoogleFonts.cairo(),
          ),
        ),
      );
      return;
    }
    setState(() => _adding = true);
    try {
      final cart = Provider.of<CartProvider>(context, listen: false);
      final buyer = Provider.of<BuyerDataProvider>(context, listen: false);
      final buyerPoint = SellerGeo.buyerPoint(
        lat: buyer.effectiveLat,
        lng: buyer.effectiveLng,
      );
      for (final t in g.triggers) {
        await cart.addItemToCart(
          offerId: t.offerId,
          productId: t.productId,
          sellerId: g.sellerId,
          sellerName: g.sellerName,
          name: t.productName,
          price: t.price,
          unit: t.unitName,
          unitIndex: t.unitIndex,
          quantityToAdd: t.quantityBase,
          imageUrl: t.imageUrl,
          userRole: 'buyer',
          buyerLat: buyerPoint.lat,
          buyerLng: buyerPoint.lng,
        );
      }
      await cart.loadCartAndRecalculate('buyer');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تمت إضافة شروط العرض للسلة — الهدية تُحسب تلقائياً عند الاستيفاء',
            style: GoogleFonts.cairo(),
          ),
          backgroundColor: Colors.green[700],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().replaceFirst('Exception: ', ''),
            style: GoogleFonts.cairo(),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  Widget _thumb(String url, {double size = 40}) {
    if (url.isEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.orange[50],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(Icons.redeem, size: size * 0.55, color: Colors.orange[700]),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(
        url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.image_not_supported, color: Colors.grey),
        ),
      ),
    );
  }

  String get _expiryLabel {
    if (g.expiry == null) return 'بدون تاريخ انتهاء معلن';
    final d = g.expiry!;
    final s =
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    return 'ينتهي في $s';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 12.sp),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(12.sp),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _thumb(g.giftImage, size: 52),
                SizedBox(width: 10.sp),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        g.promoName,
                        style: GoogleFonts.cairo(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'من ${g.sellerName}',
                        style: GoogleFonts.cairo(
                          fontSize: 12.sp,
                          color: Colors.blueGrey,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      EdgeInsets.symmetric(horizontal: 8.sp, vertical: 4.sp),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'المتبقي ${g.remaining}',
                    style: GoogleFonts.cairo(
                      fontSize: 11.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.green[800],
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8.sp),
            if (g.isMinOrder)
              Row(
                children: [
                  _thumb('', size: 34),
                  SizedBox(width: 8.sp),
                  Expanded(
                    child: Text(
                      'اشترِ بقيمة ${g.minOrderValue.toStringAsFixed(0)} ج أو أكثر من ${g.sellerName}',
                      style: GoogleFonts.cairo(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              )
            else
              ...g.triggers.map(
                (t) => Padding(
                  padding: EdgeInsets.only(bottom: 6.sp),
                  child: Row(
                    children: [
                      _thumb(t.imageUrl, size: 34),
                      SizedBox(width: 8.sp),
                      Expanded(
                        child: Text(
                          'اشترِ ${t.quantityBase} ${t.unitName} من ${t.productName}',
                          style: GoogleFonts.cairo(
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const Divider(),
            Row(
              children: [
                _thumb(g.giftImage, size: 34),
                SizedBox(width: 8.sp),
                Expanded(
                  child: Text(
                    'الهدية: ${g.giftQty} ${g.giftUnit} ${g.giftName}',
                    style: GoogleFonts.cairo(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange[900],
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 6.sp),
            Row(
              children: [
                Icon(Icons.timer_outlined, size: 14.sp, color: Colors.red[400]),
                SizedBox(width: 4.sp),
                Expanded(
                  child: Text(
                    _expiryLabel,
                    style: GoogleFonts.cairo(
                      fontSize: 11.5.sp,
                      color: Colors.red[700],
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 10.sp),
            Wrap(
              spacing: 8.sp,
              runSpacing: 8.sp,
              children: [
                ElevatedButton.icon(
                  onPressed: _adding ? null : _addOfferToCart,
                  icon: _adding
                      ? SizedBox(
                          width: 14.sp,
                          height: 14.sp,
                          child: const CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.add_shopping_cart, color: Colors.white),
                  label: Text(
                    _adding ? 'جارٍ الإضافة...' : 'إضافة العرض للسلة',
                    style: GoogleFonts.cairo(
                      fontSize: 12.5.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4CAF50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _visitMerchant,
                  icon: const Icon(Icons.storefront_outlined),
                  label: Text(
                    'زيارة صفحة التاجر',
                    style: GoogleFonts.cairo(
                      fontSize: 12.5.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
