// المسار: lib/widgets/buyer_product_card.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';        
import 'package:my_test_app/widgets/quantity_control.dart';                                     
import 'package:google_fonts/google_fonts.dart';
import 'package:my_test_app/utils/offer_data_model.dart';
import 'package:my_test_app/providers/product_offers_provider.dart';
// 🆕 [التعديل 1]: استيراد CartProvider         
import 'package:my_test_app/providers/cart_provider.dart';

class BuyerProductCard extends StatefulWidget {
  final String productId;
  final Map<String, dynamic> productData;       
  const BuyerProductCard({                          
    super.key,
    required this.productId,
    required this.productData,                    
  });                                           
  @override                                       
  State<BuyerProductCard> createState() => _BuyerProductCardState();
}
                                                
class _BuyerProductCardState extends State<BuyerProductCard> {                                  
  @override
  void initState() {                                
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ProductOffersProvider>(context, listen: false)
          .fetchOffers(widget.productId);           
    });
  }                                                                                               
  // 💡 دالة تغيير الكمية لتستدعي الـ Provider    
  void _onQuantityChanged(int newQty) {
    Provider.of<ProductOffersProvider>(context, listen: false)
        .updateQuantity(newQty);
  }                                                                                               
  
  // 💡 [التعديل 2]: دالة الإضافة للسلة لاستخدام بيانات الـ CartProvider
  void _addToCart() async { 
    final offersProvider = Provider.of<ProductOffersProvider>(context, listen: false);              
    final selectedOffer = offersProvider.selectedOffer;                                             
    final currentQuantity = offersProvider.currentQuantity;                                     
    
    if (selectedOffer == null || currentQuantity == 0) return;
    
    // 🟢🟢 New: جلب رابط الصورة كمتغير تاسع (تم نقله من دالة build) 🟢🟢
    final String imageUrl = widget.productData['imageUrls']?.isNotEmpty == true
        ? widget.productData['imageUrls'][0]
        : ''; // قيمة افتراضية فارغة إذا لم تتوفر
    
    // استدعاء دالة addItemToCart من CartProvider
    try {                                             
      final cartProvider = Provider.of<CartProvider>(context, listen: false);
                                                      
      await cartProvider.addItemToCart(
        selectedOffer.offerId,                          // 1
        selectedOffer.sellerId,                         // 2
        selectedOffer.sellerName,                       // 3
        widget.productData['name'] ?? 'منتج غير معروف', // 4
        selectedOffer.price,                            // 5
        selectedOffer.unitName,                         // 6
        selectedOffer.unitIndex ?? 0,                   // 7
        currentQuantity,                                // 8
        imageUrl,                                       // 9 🟢 المتغير التاسع الذي كان مفقوداً 🟢
      );                                        
      // رسالة نجاح بعد الإضافة وإعادة الحساب
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ تم إضافة ${currentQuantity} من ${widget.productData['name']} إلى السلة.'),
          duration: const Duration(seconds: 2),
          backgroundColor: Colors.green, // لون مختلف للنجاح                                            
        ),
      );                                                                                              
      // 💡 [اختياري]: إعادة تعيين الكمية في واجهة بطاقة المنتج إلى 1 بعد الإضافة
      offersProvider.updateQuantity(selectedOffer.minQty ?? 1);                                 
    } catch (e) {                                     
      // رسالة خطأ في حال فشل الإضافة
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
                                                    
    // 💡 ملاحظة: يتم جلب imageUrl هنا للعرض فقط، وتم نقل جلبها لـ _addToCart لاستخدامها هناك
    final displayImageUrl = widget.productData['imageUrls']?.isNotEmpty == true
        ? widget.productData['imageUrls'][0]
        : 'https://via.placeholder.com/300/0f3460/f0f0f0?text=لا توجد صورة';                                                                        
    final bool isAddToCartDisabled = selectedOffer == null || currentQuantity < (selectedOffer.minQty ?? 1);                                                                                        
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),                         
      margin: EdgeInsets.zero,
      color: Colors.white,
      child: Padding(                                   
        // 💡 [معالجة الـ Overflow 1]: تقليل الـ Padding العام للبطاقة من 10 إلى 8
        padding: const EdgeInsets.all(8.0),
        child: Column(                                    
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,                                              
          children: [
            // 1. الصورة: تغيير من دائري إلى مستطيل/مربع بزوايا مستديرة                                     
            InkWell(
              onTap: () {                                       
                // يجب تعريف مسار /productDetails                                                             
              },
              child: Container(                                 
                width: double.infinity,
                // 💡 [معالجة الـ Overflow 2]: تقليل ارتفاع الصورة قليلاً من 120 إلى 110                         
                height: 110,
                decoration: BoxDecoration(                        
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200, width: 1),
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
            // 💡 [معالجة الـ Overflow 3]: تقليل المسافة بعد الصورة من 10 إلى 8                             
            const SizedBox(height: 8),                                                                      
            // 2. اسم المنتج
            Text(                                             
              widget.productData['name'] ?? 'منتج غير معروف',
              textAlign: TextAlign.center,                    
              maxLines: 2,                                    
              overflow: TextOverflow.ellipsis,                
              style: GoogleFonts.cairo(
                fontWeight: FontWeight.w700,
                fontSize: 16,
                color: Colors.black87,                        
              ),
            ),                                  
            // 3. اختيار العرض
            // 💡 [معالجة الـ Overflow 4]: تقليل المسافة قبل العرض من 8 إلى 6
            const SizedBox(height: 6),
            isLoadingOffers                                     
                ? const LinearProgressIndicator()
                : InkWell(                                          
                    onTap: () {
                      _showOfferSelectionModal(context, availableOffers, selectedOffer, offersProvider);
                    },
                    child: Container(                                 
                      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8), // تقليل الـ padding الداخلي
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300, width: 1.0),
                        borderRadius: BorderRadius.circular(10),                                                        
                        color: Colors.grey.shade100,
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
                                color: selectedOffer == null ? Colors.red : Theme.of(context).primaryColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 13, // تقليل حجم الخط قليلاً
                              ),
                            ),
                          ),
                          const Icon(Icons.arrow_drop_down, color: Colors.grey, size: 20), // تقليل حجم الأيقونة
                        ],                                            
                      ),
                    ),                                            
                  ),
                                                            
            // 💡 [معالجة الـ Overflow 5]: تقليل المسافة قبل التحكم في الكمية من 12 إلى 8
            const SizedBox(height: 8),                                                                      
            // 4. التحكم في الكمية
            QuantityControl(
              initialQuantity: currentQuantity,
              minQuantity: selectedOffer?.minQty ?? 1,
              maxStock: selectedOffer?.stock ?? 0,                                                            
              onQuantityChanged: _onQuantityChanged,
              isDisabled: selectedOffer == null || selectedOffer.stock == 0,
            ),

            // 5. زر الإضافة إلى السلة
            // 💡 [معالجة الـ Overflow 6]: تقليل المسافة قبل الزر من 12 إلى 8                               
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,                         
              child: ElevatedButton.icon(
                onPressed: isAddToCartDisabled ? null : _addToCart,                                             
                icon: const Icon(Icons.add_shopping_cart, size: 16), // تقليل حجم أيقونة السلة                  
                label: Text(                                      
                  'أضف إلى السلة',
                  style: GoogleFonts.cairo(                         
                    fontSize: 14, // تقليل حجم الخط قليلاً                                                           
                    fontWeight: FontWeight.bold,
                  ),
                ),                                              
                style: ElevatedButton.styleFrom(                  
                  backgroundColor: isAddToCartDisabled ? Colors.grey.shade400 : Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 10), // تقليل الـ padding العمودي للزر من 12 إلى 10                                               
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),                         
                  elevation: 4,
                ),                                            
              ),                                            
            ),
          ],
        ),                                            
      ),
    );
  }

  // ... (دالة _showOfferSelectionModal تبقى كما هي دون تغيير)
  void _showOfferSelectionModal(BuildContext context, List<OfferModel> availableOffers, OfferModel? selectedOffer, ProductOffersProvider provider) {
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
