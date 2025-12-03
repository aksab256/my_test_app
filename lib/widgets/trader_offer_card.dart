import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:my_test_app/theme/app_theme.dart';
import 'package:my_test_app/providers/cart_provider.dart';
import 'package:collection/collection.dart'; // لاستخدام firstOrNull

class TraderOfferCard extends StatelessWidget {
  final Map<String, dynamic> offerData;
  final String offerDocId;
  final VoidCallback onTap;

  const TraderOfferCard({
    super.key,
    required this.offerData,
    required this.offerDocId,
    required this.onTap,
  });

  // 💡 استخلاص رابط الصورة مرة واحدة هنا لضمان الاتساق
  String get _imageUrl {
    // يبحث عن حقل imageUrls كقائمة، ويأخذ العنصر الأول، وإلا يعرض Placeholder
    return (offerData['imageUrls'] as List<dynamic>?)?.firstOrNull?.toString() ?? 
           'https://via.placeholder.com/140x90/E0E0E0/757575?text=لا+توجد+صورة';
  }

  Widget _buildUnitItem(BuildContext context, Map<String, dynamic> unit, int unitIndex) {
    // 💡 الآن نستخدم listen: false لأننا لا نريد إعادة بناء الواجهة عند تغير السلة
    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    final unitName = unit['unitName']?.toString() ?? 'الكمية الأساسية';
    final price = (unit['price'] as num?)?.toDouble() ?? (offerData['price'] as num?)?.toDouble() ?? 0.0;
    final availableStock = unit['availableStock'] as num? ?? offerData['availableQuantity'] as num? ?? 0;

    final isDisabled = availableStock <= 0;
    final buttonText = isDisabled ? 'نفذت الكمية' : 'أضف للسلة';

    // ⭐️ تجميع بيانات العنصر لإرسالها لـ Provider ⭐️
    final itemData = {
      'offerId': offerDocId, // معرّف العرض
      'sellerId': offerData['sellerId']?.toString() ?? '',
      'sellerName': offerData['sellerName']?.toString() ?? '',
      'title': offerData['productName']?.toString() ?? 'منتج غير معروف', // name في دالة Provider
      'price': price,
      'unit': unitName,
      'unitIndex': unitIndex,
      'quantity': 1, // الكمية المراد إضافتها (1 عند الضغط على الزر)
      'image': _imageUrl, // ✅ استخدام رابط الصورة المستخلص
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xff2a2a2a) : const Color(0xffe8f5e9),
        border: Border.all(color: isDarkMode ? const Color(0xff3a3a3a) : const Color(0xffa5d6a7), width: 1),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                unitName,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                '${price.toStringAsFixed(2)} جنيه',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primaryDarkGreen, 
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          ElevatedButton.icon(
            // 🎯 استدعاء 'addItemToCart' وتمرير الـ 9 معطيات
            onPressed: isDisabled ? null : () async {
              await cartProvider.addItemToCart(
                itemData['offerId'] as String,             // 1. offerId
                itemData['sellerId'] as String,            // 2. sellerId
                itemData['sellerName'] as String,          // 3. sellerName
                itemData['title'] as String,               // 4. name (product name)
                itemData['price'] as double,               // 5. price
                itemData['unit'] as String,                // 6. unit
                itemData['unitIndex'] as int,              // 7. unitIndex
                itemData['quantity'] as int,               // 8. quantityToAdd (1)
                itemData['image'] as String,               // 9. imageUrl 
              );
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('✅ تم إضافة المنتج إلى السلة'), duration: Duration(seconds: 1)),
              );
            },
            icon: Icon(Icons.shopping_cart_sharp, size: 12, color: isDisabled ? Colors.grey : Colors.white),
            label: Text(
              buttonText,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDisabled ? Colors.grey : Colors.white),
            ),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 30),
              backgroundColor: isDisabled ? AppTheme.scaffoldLight : AppTheme.primaryGreen,
              padding: const EdgeInsets.symmetric(vertical: 6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final units = offerData['units'] as List<dynamic>?;

    return InkWell(
      onTap: onTap,
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. الصورة
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.network(
                  _imageUrl, // ✅ استخدام المتغير المستخلص
                  height: 90,
                  fit: BoxFit.cover,
                  
                  // 🎯 التصحيح: استخدام CircularProgressIndicator بدون قيمة 'value' في حالة Flutter Web
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    
                    return SizedBox(
                      height: 90,
                      child: Center(
                        child: CircularProgressIndicator(
                          // تم إزالة قيمة 'value' لتجنب خطأ bytesLoaded
                          color: Theme.of(context).primaryColor,
                          strokeWidth: 2,
                        ),
                      ),
                    );
                  },
                  
                  // 🎯 منطق عرض الخطأ
                  errorBuilder: (context, error, stackTrace) =>
                      Container(
                        height: 90, 
                        color: const Color(0xFFE0E0E0), 
                        child: const Center(
                          child: Icon(Icons.image_not_supported_rounded, color: Color(0xFF757575), size: 40)
                        )
                      ),
                ),
              ),
              const SizedBox(height: 5),

              // 2. اسم المنتج
              Expanded(
                child: Text(
                  offerData['productName']?.toString() ?? 'منتج غير معروف',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyLarge!.color),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                ),
              ),
              const SizedBox(height: 8),

              // 3. قسم الوحدات
              const Text('الوحدات المتاحة:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textDark)), 
              const SizedBox(height: 4),

              if (units != null && units.isNotEmpty)
                ...units.map((unit) => _buildUnitItem(context, unit as Map<String, dynamic>, units.indexOf(unit))).toList(),

              if (units == null || units.isEmpty)
                // حالة الوحدة الواحدة فقط
                _buildUnitItem(context, offerData, -1),
            ],
          ),
        ),
      ),
    );
  }
}
