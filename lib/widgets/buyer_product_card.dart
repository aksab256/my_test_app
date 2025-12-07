// المسار: lib/widgets/buyer_product_card.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:my_test_app/widgets/quantity_control.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:my_test_app/utils/offer_data_model.dart';
import 'package:my_test_app/providers/product_offers_provider.dart';
import 'package:my_test_app/providers/cart_provider.dart';
import 'package:sizer/sizer.dart';

class BuyerProductCard extends StatefulWidget {
// ... (الخصائص تبقى كما هي)
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
// ... (initState و _onQuantityChanged و _addToCart تبقى كما هي)
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ProductOffersProvider>(context, listen: false)
          .fetchOffers(widget.productId);
    });
  }

  void _onQuantityChanged(int newQty) {
    Provider.of<ProductOffersProvider>(context, listen: false)
        .updateQuantity(newQty);
  }

  void _addToCart() async {
    final offersProvider = Provider.of<ProductOffersProvider>(context, listen: false);
    final selectedOffer = offersProvider.selectedOffer;
    final currentQuantity = offersProvider.currentQuantity;

    if (selectedOffer == null || currentQuantity == 0) return;

    final String imageUrl = widget.productData['imageUrls']?.isNotEmpty == true
        ? widget.productData['imageUrls'][0]
        : '';

    try {
      final cartProvider = Provider.of<CartProvider>(context, listen: false);

      await cartProvider.addItemToCart(
        selectedOffer.offerId,
        widget.productId, // 🔥🔥 التعديل: إضافة productId كمعامل ثانٍ (المعامل العاشر في الإجمالي)
        selectedOffer.sellerId,
        selectedOffer.sellerName,
        widget.productData['name'] ?? 'منتج غير معروف',
        selectedOffer.price,
        selectedOffer.unitName,
        selectedOffer.unitIndex ?? 0,
        currentQuantity,
        imageUrl,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ تم إضافة ${currentQuantity} من ${widget.productData['name']} إلى السلة.'),
          duration: const Duration(seconds: 2),
          backgroundColor: Colors.green,
        ),
      );
      offersProvider.updateQuantity(selectedOffer.minQty ?? 1);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ حدث خطأ أثناء إضافة المنتج: $e'),
          duration: const Duration(seconds: 3),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final offersProvider = context.watch<ProductOffersProvider>();
    final selectedOffer = offersProvider.selectedOffer;
    final currentQuantity = offersProvider.currentQuantity;
    final isLoadingOffers = offersProvider.isLoading;
    final availableOffers = offersProvider.availableOffers;

    final colorScheme = Theme.of(context).colorScheme;
    final primaryColor = colorScheme.primary;
    // 💡 [التصحيح 2]: تحديد اللون الداكن للنصوص الذي كان يمثله shade700
    final darkPrimaryText = colorScheme.onPrimaryContainer; // تم الاحتفاظ به كمتغير ولكنه لن يستخدم في شريط العرض المغلق

    final displayImageUrl = widget.productData['imageUrls']?.isNotEmpty == true
        ? widget.productData['imageUrls'][0]
        : 'https://via.placeholder.com/300/0f3460/f0f0f0?text=لا توجد صورة';

    final String? bestOfferIdForDetails = selectedOffer?.offerId;
    final bool isAddToCartDisabled = selectedOffer == null || currentQuantity < (selectedOffer.minQty ?? 1);

    // [تحسين M3]: إضافة ظل بارز ولون حدود خفيف للكارت
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: BorderSide(color: Colors.grey.shade100, width: 1),
      ),

      margin: EdgeInsets.zero,
      color: Colors.white,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              spreadRadius: 0.5,
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // 1. الصورة:
            InkWell(
              onTap: () {
                if (widget.onTap != null) {
                  widget.onTap!(widget.productId, bestOfferIdForDetails);
                }
              },
              child: Container(
                width: double.infinity,
                // 🚀 [تصحيح 1]: تقليل ارتفاع الصورة من 14.h إلى 13.h
                height: 13.h, // تم التعديل
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    displayImageUrl,
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return const Center(child: CircularProgressIndicator());
                    },
                    errorBuilder: (context, error, stackTrace) => Center(
                      child: Icon(Icons.shopping_bag, size: 40, color: Colors.grey.shade400),
                    ),
                  ),
                ),
              ),
            ),
            // 🚀 [تصحيح 2]: تقليل المسافة من 8 إلى 5
            const SizedBox(height: 5), // تم التعديل
            // 2. اسم المنتج
            Text(
              widget.productData['name'] ?? 'منتج غير معروف',
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.cairo(
                fontWeight: FontWeight.w700,
                fontSize: 14.sp,
                color: Colors.black87,
              ),
            ),
            // 🚀 [تصحيح 3]: تقليل المسافة من 6 إلى 4
            const SizedBox(height: 4), // تم التعديل
            // 3. اختيار العرض
            isLoadingOffers
                ? const LinearProgressIndicator()
                : InkWell(
                    onTap: () {
                      _showOfferSelectionModal(context, availableOffers, selectedOffer, offersProvider);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                      decoration: BoxDecoration(
                        border: Border.all(color: primaryColor.withOpacity(0.5), width: 1.0),
                        borderRadius: BorderRadius.circular(10),
                        color: primaryColor.withOpacity(0.05),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                                  selectedOffer == null
                                  ? 'لا عروض متاحة'
                                  : '${selectedOffer.price} ج | ${selectedOffer.unitName}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.cairo(
                                // 🟢 [تصحيح 4]: استخدام لون أكثر وضوحاً للنص (بدلاً من darkPrimaryText)
                                color: selectedOffer == null ? Colors.red.shade700 : Colors.black87,
                                fontWeight: FontWeight.bold,

                                fontSize: 11.sp,
                              ),
                            ),
                          ),
                          // 🟢 [تصحيح 5]: استخدام لون واضح للأيقونة (بدلاً من darkPrimaryText)
                          Icon(Icons.arrow_drop_down, color: Colors.black54, size: 20),
                        ],
                      ),
                    ),
                ),
            const SizedBox(height: 8),
            // 4. التحكم في الكمية
            QuantityControl(
              initialQuantity: currentQuantity,
              minQuantity: selectedOffer?.minQty ?? 1,
              maxStock: selectedOffer?.stock ?? 0,
              onQuantityChanged: _onQuantityChanged,
              isDisabled: selectedOffer == null || selectedOffer.stock == 0,
            ),
            const SizedBox(height: 8),
            // 5. زر الإضافة إلى السلة
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: isAddToCartDisabled ? null : _addToCart,
                icon: const Icon(Icons.add_shopping_cart, size: 16),
                label: Text(
                  'أضف إلى السلة',
                  style: GoogleFonts.cairo(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isAddToCartDisabled ? Colors.grey.shade400 : primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

// ... (دالة _showOfferSelectionModal تبقى كما هي دون تغيير)
// لم يتم تعديل هذه الدالة لأن مشاكل الـ Overflow كانت في الـ build الرئيسية ولم تكن في الـ Modal.
  void _showOfferSelectionModal(BuildContext context, List<OfferModel> availableOffers, OfferModel? selectedOffer, ProductOffersProvider provider) {
// ... (الكود داخل الدالة يبقى كما هو)
    if (availableOffers.isEmpty) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (modalContext) {
        return SingleChildScrollView(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(modalContext).viewInsets.bottom,
            top: 10,
            left: 5,
            right: 5,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 15.0, vertical: 10),
                child: Text(
                  'اختيار عرض المنتج',
                  style: GoogleFonts.cairo(fontSize: 19, fontWeight: FontWeight.bold, color: Colors.black87),
                  textAlign: TextAlign.center,
                ),
              ),
              const Divider(thickness: 1.5, endIndent: 15, indent: 15),
              // قائمة العروض بتصميم البطاقات
              ...availableOffers.map((offer) {
                final isSelected = offer.offerId == selectedOffer?.offerId && offer.unitIndex == selectedOffer?.unitIndex;

                final bool isDisabled = offer.disabled;
                return Card(
                  elevation: isSelected ? 6 : 2,
                  color: isSelected ? Theme.of(context).primaryColor.withOpacity(0.1) : Colors.white,
                  margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: isSelected ? BorderSide(color: Theme.of(context).primaryColor, width: 1.5) : BorderSide.none,

                  ),
                  child: InkWell(
                    onTap: isDisabled
                        ? null
                        : () {
                            provider.selectOffer(offer);
                            Navigator.pop(modalContext);
                          },

                    child: Padding(
                      padding: const EdgeInsets.all(15.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 1. الوحدة والبائع
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                  child: Text(
                                  '${offer.unitName} - ${offer.sellerName}',
                                  style: GoogleFonts.cairo(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                    color: isDisabled ? Colors.grey : Colors.black,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (isSelected)
                                  Icon(Icons.check_circle, color: Theme.of(context).primaryColor, size: 26),
                            ],
                          ),

                          const SizedBox(height: 6),

                          // 2. السعر والمخزون
                          Text.rich(
                              TextSpan(
                                  children: [
                                    const TextSpan(text: 'السعر: ', style: TextStyle(fontWeight: FontWeight.normal, color: Colors.grey)),

                                    // تم الاحتفاظ بـ Colors.red.shade700 لكونه لون قوي وواضح في الـ Modal
                                    TextSpan(text: '${offer.price} ج', style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: Colors.red.shade700, fontSize: 18)),

                                    const TextSpan(text: ' | ', style: TextStyle(color: Colors.grey)),
                                    const TextSpan(text: 'متوفر: ', style: TextStyle(fontWeight: FontWeight.normal, color: Colors.grey)),
                                    TextSpan(
                                      text: '${offer.stock}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: offer.stock > 0 ? Colors.green.shade600 : Colors.red.shade600,
                                      ),
                                    ),
                                    const TextSpan(text: ' | الحد الأدنى: ', style: TextStyle(color: Colors.grey)),
                                    TextSpan(text: '${offer.minQty}'),
                                  ],
                              ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }
}
