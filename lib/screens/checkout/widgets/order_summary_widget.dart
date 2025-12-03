// المسار: lib/screens/checkout/widgets/order_summary_widget.dart
import 'package:flutter/material.dart';         
import 'dart:math'; // لإضافة منطق طي المحتوى   
// 🎨 تعريف الألوان بناءً على CSS (نحتفظ بها للاستخدام الداخلي ولون الخطوط)
const Color kCardBg = Colors.white; 
const Color kSectionTitleColor = Color(0xFF4CAF50); // Primary Green
const Color kTotalAmountColor = Color(0xFFE74C3C); // Primary Red/Error                         
const Color kProductItemBorder = Color(0xFFEEEEEE);
const Color kGiftBgColor = Color(0xFFE6FFE6); // خلفية خفيفة للهدية
const Color kDeliveryColor = Color(0xFF007bff); // Primary Blue
const Color kHeaderColor = Color(0xFF2C3E50); // لون غامق للعناوين                                                                              

// تم تحويلها إلى StatefulWidget لتطبيق منطق "طي المحتوى"                                       
class OrderSummaryWidget extends StatefulWidget {                                                 
  // 🟢 Modification 1: تغيير الاسم ليعكس الهيكل الجديد 🟢
  final List<Map<String, dynamic>> sellerOrders; // الآن هي قائمة الطلبات المجمعة
  final double originalOrderTotal;
                                                  
  const OrderSummaryWidget({                        
    super.key,
    required this.sellerOrders, // 🟢 تم تغيير الاسم هنا 🟢
    required this.originalOrderTotal,             
  });                                           
  @override
  State<OrderSummaryWidget> createState() => _OrderSummaryWidgetState();                        
}
                                                
class _OrderSummaryWidgetState extends State<OrderSummaryWidget> {                                
  // حالة التحكم في طي/فرد محتوى كل بائع          
  final Map<String, bool> _isExpanded = {};
                                                  
  @override                                       
  void initState() {                                
    super.initState();                              
    // تهيئة _isExpanded في بداية التشغيل           
    _initializeExpandedState();                   
  }                                                                                               
  
  void _initializeExpandedState() {
    // 🟢 Modification 2: استخدام الهيكل الجديد لتهيئة حالة الطي 🟢
    // نستخدم الـ sellerOrders لتحديد الـ keys اللازمة لـ _isExpanded                                     
    widget.sellerOrders.forEach((order) {
        final sellerId = order['sellerId'] ?? 'unknown';
        if (!_isExpanded.containsKey(sellerId)) {
            _isExpanded[sellerId] = false;
        }                                           
    });
  }
                                                  
  // دالة مساعدة لعرض الصنف الواحد (منتج/هدية/رسوم توصيل)                                         
  Widget _buildProductItem(Map<String, dynamic> item) {                                             
    final bool isGift = item['isGift'] ?? false;    
    final bool isDeliveryFee = item['isDeliveryFee'] ?? false;
                                                    
    // استخدام الـ Theme في حالات الألوان العامة ليتكيف مع الوضع الداكن
    final Color itemPriceColor = isGift
        ? kSectionTitleColor
        : (isDeliveryFee ? kDeliveryColor : kTotalAmountColor);                                                                                     
    final String itemName = isDeliveryFee               
        ? 'رسوم التوصيل'
        : (isGift ? '${item['name']} (هدية مجانية)' : item['name']);                                                                                
    // 🟢 Modification 3: استخدام حقل quantity مباشرة في item 🟢
    final double itemQuantity = (item['quantity'] as num?)?.toDouble() ?? 1.0;

    final String priceText = isGift                     
        ? 'مجاني'                                       
        : '${((item['price'] as num?)?.toDouble() ?? 0.0 * itemQuantity).toStringAsFixed(2)} جنيه';                                                                          
    final Widget itemImage;                         
    if (isDeliveryFee) {
        itemImage = const Icon(Icons.delivery_dining, size: 30, color: kDeliveryColor);
    } else if (isGift) {
        itemImage = const Icon(Icons.card_giftcard, size: 30, color: kSectionTitleColor);
    } else {                                            
        // 🟢 Modification 4: محاولة عرض الصورة المخزنة 🟢
        final String imageUrl = item['imageUrl'] as String? ?? '';
        if (imageUrl.isNotEmpty) {
            itemImage = ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    width: 50,
                    height: 50,
                    errorBuilder: (_, __, ___) => const Icon(Icons.shopping_bag, size: 30, color: Colors.grey),
                ),
            );
        } else {
            itemImage = const Icon(Icons.shopping_bag, size: 30, color: Colors.grey);
        }
    }
                                                    
    // الحدود بين الأصناف (نحتفظ بها للتفريق البصري)
    final BorderSide itemBorder = BorderSide(
      color: isGift ? kSectionTitleColor : kProductItemBorder,                                        
      width: 1,
      style: BorderStyle.solid                      
    );
                                                    
    return Container(                                 
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(                        
        // دمج تعريف الحدود
        border: isGift                                      
            ? Border.fromBorderSide(itemBorder)             
            : Border(bottom: itemBorder),               
        color: isGift ? kGiftBgColor : Theme.of(context).cardColor, // استخدام لون البطاقة من الثيم                                                     
        borderRadius: isGift ? BorderRadius.circular(8) : null,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,                                                   
          textDirection: TextDirection.rtl,               
          children: [
            // محاكاة للصورة/الأيقونة                       
            Container(                                        
              width: 50,
              height: 50,
              margin: const EdgeInsets.only(left: 10),                                                        
              decoration: BoxDecoration(                        
                borderRadius: BorderRadius.circular(8),                                                         
                color: Theme.of(context).colorScheme.surfaceVariant, // لون M3 خفيف                             
                border: Border.all(color: kProductItemBorder),                                                
              ),
              child: Center(child: itemImage),              
            ),

            Expanded(
              child: Column(                                    
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [                                       
                  Text(
                    itemName,
                    style: TextStyle(                                 
                      fontWeight: FontWeight.bold,                                                                    
                      fontSize: 14,                                   
                      color: isGift ? kSectionTitleColor : Theme.of(context).textTheme.bodyLarge?.color,
                    ),                                              
                    textAlign: TextAlign.right,
                  ),                                              
                  const SizedBox(height: 4),
                  Row(                                              
                    mainAxisAlignment: MainAxisAlignment.end,                                                       
                    children: [                                       
                      Text(
                        priceText,                                      
                        style: TextStyle(                                 
                          fontWeight: FontWeight.bold,
                          color: itemPriceColor,                          
                          fontSize: 14,
                        ),
                        textDirection: TextDirection.ltr,
                      ),
                      if (!isGift) const Text(' | ', style: TextStyle(color: Colors.grey)),
                      Text(
                        // 🟢 Modification 5: استخدام itemQuantity 🟢
                        'الكمية: ${itemQuantity.toStringAsFixed(0)}', 
                        style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurface),
                        textDirection: TextDirection.rtl,                                                             
                      ),                                            
                    ],
                  ),                                            
                ],
              ),
            ),
          ],                                            
        ),
      ),                                            
    );                                            
  }

  // 💡 دالة بناء قسم الطلب الواحد (وتطبيق منطق الطي عليه)                                        
  // 🟢 Modification 6: أصبحت الدالة تستقبل Order object بدلاً من items list 🟢
  Widget _buildSellerSection(Map<String, dynamic> sellerOrder) {
    final sellerId = sellerOrder['sellerId'] as String? ?? 'unknown';
    final sellerName = sellerOrder['sellerName'] as String? ?? 'بائع غير معروف';
    final List<Map<String, dynamic>> sellerItems = (sellerOrder['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final double deliveryFee = (sellerOrder['deliveryFee'] as num?)?.toDouble() ?? 0.0;
    final double orderTotal = (sellerOrder['orderTotal'] as num?)?.toDouble() ?? 0.0;


    // 🛑 يتم الآن إضافة رسوم التوصيل كعنصر مرئي في القائمة 🛑
    final List<Map<String, dynamic>> itemsAndFee = [...sellerItems];
    if (deliveryFee > 0) {
        itemsAndFee.add({
            'name': 'رسوم التوصيل',
            'quantity': 1,
            'price': deliveryFee,
            'isDeliveryFee': true,
        });
    }

    final bool isExpanded = _isExpanded[sellerId] ?? false;
    const int initialItemsCount = 3;
    final bool isCollapsible = itemsAndFee.length > initialItemsCount;

    final List<Map<String, dynamic>> itemsToShow = isExpanded || !isCollapsible
        ? itemsAndFee                                   
        : itemsAndFee.take(initialItemsCount).toList();                                         
    
    // فرز وعرض الأصناف المدفوعة أولاً ثم الهدايا ثم رسوم التوصيل
    itemsToShow.sort((a, b) {
        if (a['isDeliveryFee'] == true) return 1; // التوصيل دائماً في الأسفل
        if (b['isDeliveryFee'] == true) return -1;
        return (a['isGift'] == b['isGift']) ? 0 : (a['isGift'] ? 1 : -1);
    });
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 15.0),                                                   
      child: Column(                                    
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [                                       
          Text(
            sellerName,                                     
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.primary),                                      
            textAlign: TextAlign.right,
          ),                                              
          const Divider(height: 10, thickness: 0.5),                                                                                                      
          // عرض عناصر الطلب                              
          ...itemsToShow.map((item) => _buildProductItem(item)).toList(),
          
          // 💡 إجمالي الطلب لهذا البائع (جديد)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              textDirection: TextDirection.rtl,
              children: [
                Text(
                  'إجمالي طلب ${sellerName}:',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: kHeaderColor),
                ),
                Text(
                  '${orderTotal.toStringAsFixed(2)} جنيه',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: kTotalAmountColor),
                  textDirection: TextDirection.ltr,
                ),
              ],
            ),
          ),


          // زر عرض المزيد/إخفاء إذا كان عدد العناصر كبيراً                                                
          if (isCollapsible)
            GestureDetector(
              onTap: () {
                setState(() {
                  _isExpanded[sellerId] = !isExpanded;                                                          
                });
              },
              child: Padding(                                   
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,                                                    
                  children: [                                       
                    Text(                                             
                      isExpanded
                          ? 'إخفاء ${itemsAndFee.length - initialItemsCount} أصناف'                                       
                          : 'عرض المزيد (${itemsAndFee.length - initialItemsCount} أصناف)',                           
                      style: TextStyle(                                 
                        color: Theme.of(context).colorScheme.secondary, // استخدام لون ثانوي من M3                                                                      
                        fontWeight: FontWeight.bold,                                                                    
                        fontSize: 14,                                 
                      ),
                    ),
                    Icon(                                             
                      isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,                               
                      color: Theme.of(context).colorScheme.secondary,
                      size: 20,                                     
                    ),
                  ],
                ),                                            
              ),                                            
            ),
        ],                                            
      ),
    );                                            
  }
                                                  
  @override                                       
  Widget build(BuildContext context) {              
    // 🟢 Modification 7: استخدام widget.sellerOrders مباشرة 🟢
    final List<Map<String, dynamic>> sellerOrders = widget.sellerOrders;

    if (sellerOrders.isEmpty) {              
      return Container(
        padding: const EdgeInsets.all(30),              
        child: Text(
          'لا توجد منتجات لتأكيدها.',                     
          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 16),          
          textAlign: TextAlign.center,
        ),
      );                                            
    }                                                                                               
    // 🛑 حذف منطق التجميع المكرر 🛑
    
    return Card(
      elevation: 2, // قيمة افتراضية لـ M3
      margin: EdgeInsets.zero, // لا يوجد هامش، يتم التحكم فيه من الأب                                
      shape: RoundedRectangleBorder(                    
        borderRadius: BorderRadius.circular(12), // استخدام زوايا مستديرة من M3
      ),                                              
      child: Padding(
        padding: const EdgeInsets.all(15),              
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,                                                 
          children: [
            Text(
              'ملخص الطلب',
              style: TextStyle(
                fontSize: 18,                                   
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary, // استخدام لون M3 الأساسي
              ),
              textAlign: TextAlign.right,                   
            ),                                              
            const Divider(height: 25, thickness: 1),                                                                                                        
            // 2. عرض المجموعات حسب البائع
            // 🟢 Modification 8: التكرار مباشرة على القائمة المُنظمة 🟢
            ...sellerOrders.map((order) {                                                          
              // لا نحتاج إلى فرز هنا، الفرز سيتم داخل _buildSellerSection لضمان التوصيل في الأسفل
              return _buildSellerSection(order);                                
            }).toList(),
                                                            
            // 3. الإجمالي المبدئي (قبل خصم الكاش باك)
            const Divider(height: 10, thickness: 1),                                                        
            Padding(                                          
              padding: const EdgeInsets.only(top: 10.0),                                                      
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,                                              
                textDirection: TextDirection.rtl,                                                               
                children: [                                       
                  Text(                                             
                    'الإجمالي قبل الخصم:', // تغيير النص ليكون أكثر وضوحاً
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface),                                  
                  ),
                  Text(                                             
                    '${widget.originalOrderTotal.toStringAsFixed(2)} جنيه',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: kTotalAmountColor),                                                    
                    textDirection: TextDirection.ltr,                                                             
                  ),                                            
                ],                                            
              ),
            ),
          ],                                            
        ),                                            
      ),
    );                                            
  }
}
