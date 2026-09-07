// المسار: lib/widgets/cart/cart_item_card.dart
import 'package:flutter/material.dart';

import 'package:my_test_app/providers/cart_provider.dart';
import 'package:provider/provider.dart';

// 🎨 تعريف الألوان بناءً على CSS
const Color kPrimaryColor = Color(0xFF3bb77e);
const Color kWarningColor = Color(0xFFFFAB00);
const Color kErrorColor = Color(0xFFDC3545);
const Color kGiftBorderColor = Color(0xFF00bcd4);
const Color kGiftBgColor = Color(0xFFE0F7FA);
const Color kGiftTextColor = Color(0xFF00838f);
const Color kClearButtonColor = Color(0xFFff7675);
const Color kItemTotalBg = Color(0xFFfff6f4); // خلفية الإجمالي (لون فاتح)

class CartItemCard extends StatelessWidget {
  final CartItem item;
  final String? itemError; // رسالة خطأ المخزون/الكمية
  final bool isWarning; // تحذير الحد الأدنى للطلب

  const CartItemCard({
    super.key,
    required this.item,
    this.itemError,
    this.isWarning = false,
  });

  // 🟢🟢 New: مكون عرض الصورة 🟢🟢
  Widget _buildImageSection(BuildContext context) {
    final String image = item.imageUrl.isNotEmpty
        ? item.imageUrl
        : 'https://via.placeholder.com/100/CCCCCC/FFFFFF?text=${item.isGift ? 'هدية' : 'منتج'}';
    return Container(
      width: 60,
      height: 60,
      margin: const EdgeInsets.only(left: 15),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: item.isGift ? kGiftBorderColor : Colors.grey.shade300,
          width: 1
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.network(
          image,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Center(
              child: Icon(
                item.isGift ? Icons.card_giftcard : Icons.shopping_bag,
                size: 30,
                color: item.isGift ? kGiftTextColor : Colors.grey,
              ),
            );
          },
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return const Center(child: CircularProgressIndicator(strokeWidth: 2));
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Color borderColor = kPrimaryColor;
    Color cardBgColor = Colors.white;
    Color textColor = Colors.grey.shade700;
    if (item.isGift) {
      borderColor = kGiftBorderColor;
      cardBgColor = kGiftBgColor;
      textColor = kGiftTextColor;
    } else if (itemError != null) {
      borderColor = kErrorColor;
      cardBgColor = kErrorColor.withOpacity(0.1);
    } else if (isWarning) {
      borderColor = kWarningColor;
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(15), // 💡 [تعديل 1]: تقليل الـ Padding الكلي من 20 إلى 15 لضغط المساحة
      decoration: BoxDecoration(
        color: cardBgColor,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border(
          left: BorderSide(color: borderColor, width: 4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildImageSection(context),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(item.isGift ? Icons.card_giftcard : Icons.inventory_2,
                            color: item.isGift ? kGiftTextColor : Theme.of(context).textTheme.titleLarge?.color,
                            size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            item.name,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: item.isGift ? kGiftTextColor : Colors.black,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(
                        '${item.quantity} ${item.unit} | ${item.sellerName}',
                        style: TextStyle(fontSize: 14, color: textColor),
                        ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 15),

          _buildDetailRow(
            icon: Icons.money,
            label: 'السعر:',
            value: item.isGift ? 'مجاني' : '${item.price.toStringAsFixed(2)} جنيه',
            color: textColor,
          ),

          const SizedBox(height: 10),
          // 💡 الإجمالي (Total) - تم تغيير لون الخط
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: kItemTotalBg,
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text(
              'الإجمالي: ${item.isGift ? '0.00' : (item.price * item.quantity).toStringAsFixed(2)} جنيه',
              style: const TextStyle( // 💡 [تعديل 2]: تغيير لون الإجمالي إلى اللون الأساسي (الأخضر)
                fontWeight: FontWeight.bold,
                color: kPrimaryColor,
              ),
            ),
          ),
          // 💡 رسالة خطأ المخزون/الكمية
          if (itemError != null)
            Container(
              margin: const EdgeInsets.only(top: 10),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: kErrorColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border(
                  left: BorderSide(color: kErrorColor, width: 5),
                          ),
                        ),
              child: Row(
                children: [
                  const Icon(Icons.error, color: kErrorColor, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'تنبيه: $itemError',
                      style: const TextStyle(color: kErrorColor, fontSize: 14, fontWeight: FontWeight.w500),
                                         ),
                                       ),
                                     ],
              ),
            ),
          // 💡 أزرار التحكم (فقط للمنتجات غير الهدايا)
          if (!item.isGift) _buildControls(context),
        ],
      ),
    );
  }

  Widget _buildDetailRow({required IconData icon, required String label, required String value, required Color color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(icon, color: kPrimaryColor, size: 16),
          const SizedBox(width: 8),
          Text(
            '$label ',
            style: TextStyle(color: color, fontSize: 15),
          ),
          Text(
            value,
            style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildControls(BuildContext context) {
    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    
    // 🛑 الدور الثابت لهذه البطاقة هو 'consumer'
    const String userRole = 'consumer';

    return Padding(
        padding: const EdgeInsets.only(top: 10.0), //  💡 [تعديل 3]: تقليل الـ Padding العلوي قبل الأزرار
        child: Wrap(
        spacing: 8, // 💡 [تعديل 4]: تقليل الـ Spacing الأفقي
        runSpacing: 8, // 💡 [تعديل 5]: تقليل الـ RunSpacing العمودي
        children: [
          _controlButton(
            icon: Icons.add,
            text: 'زيادة',
            bgColor: Theme.of(context).cardColor,
            // 🟢 [التصحيح]: إضافة وسيطة userRole
            onTap: () => cartProvider.changeQty(item, 1, userRole),
          ),
          _controlButton(
            icon: Icons.remove,
            text: 'نقصان',
            bgColor: Theme.of(context).cardColor,
            // 🟢 [التصحيح]: إضافة وسيطة userRole
            onTap: () => cartProvider.changeQty(item, -1, userRole),
          ),
          _controlButton(
            icon: Icons.delete,
            text: 'حذف',
            bgColor: kClearButtonColor,
            textColor: Colors.white,
            // 🟢 [التصحيح]: إضافة وسيطة userRole
            onTap: () => cartProvider.removeItem(item, userRole),
          ),
        ],
      ),
    );
  }

  Widget _controlButton({
    required IconData icon,
    required String text,
    required Color bgColor,
    Color textColor = Colors.black,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), // 💡 [تعديل 6]: تقليل Padding الأزرار
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: textColor), // 💡 [تعديل 7]: تقليل حجم الأيقونة
            const SizedBox(width: 4), // 💡 [تعديل 8]: تقليل المسافة
            Text(text, style: TextStyle(fontSize: 14, color: textColor)), // 💡 [تعديل 9]: تقليل حجم الخط
          ],
        ),
      ),
    );
  }
}

