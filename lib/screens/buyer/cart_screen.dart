// المسار: lib/screens/buyer/cart_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';        
import 'package:my_test_app/providers/cart_provider.dart';
import 'package:my_test_app/widgets/cart/cart_item_card.dart';

// 🟢 سطر مضاف: استيراد شاشة الدفع
import 'package:my_test_app/screens/checkout/checkout_screen.dart';

// 🎨 تعريف الألوان بناءً على CSS                
const Color kPrimaryColor = Color(0xFF3bb77e);
const Color kErrorColor = Color(0xFFDC3545);    
const Color kClearButtonColor = Color(0xFFff7675);
const Color kDeliverySummaryBg = Color(0xFFE0F7FA);                                             
const Color kDeliverySummaryText = Color(0xFF00838f);
const Color kWarningMessageBg = Color(0xFFfff3cd);
const Color kWarningMessageBorder = Color(0xFFffc107);
const Color kWarningMessageText = Color(0xFF856404);
const Color kGiftBorderColor = Color(0xFF00838f); 

class CartScreen extends StatefulWidget {         
  static const String routeName = '/cart';                                                        
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}                                               
class _CartScreenState extends State<CartScreen> {
  // 🟢🟢 New State: تخزين حالة الطلب المعلق 🟢🟢
  bool _hasPendingCheckout = false;
  
  // 🟢 دالة التحقق والعرض 
  Future<void> _checkAndShowPendingCheckout() async {
    final cartProvider = Provider.of<CartProvider>(context, listen: false);

    // 1. تحميل السلة وحساب الإجماليات (أولاً)
    await cartProvider.loadCartAndRecalculate('consumer');

    // 2. التحقق من وجود طلب دفع معلق
    final isPending = await cartProvider.hasPendingCheckout;
    
    if (isPending) {
        setState(() {
            _hasPendingCheckout = true; // نستخدم هذا لربما نغير الـ UI لاحقًا
        });
        
        // 3. عرض مربع حوار الاستئناف
        WidgetsBinding.instance.addPostFrameCallback((_) {
            _showPendingCheckoutDialog(cartProvider);
        });
    }
  }

  // 🟢 دالة عرض مربع الحوار 
  void _showPendingCheckoutDialog(CartProvider cartProvider) {
      showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
              title: const Text('استئناف عملية الدفع'),
              content: const Text('لديك عملية دفع سابقة لم تكتمل. هل تود العودة إليها الآن؟'),
              actions: <Widget>[
                  TextButton(
                      child: const Text('إلغاء الطلب', style: TextStyle(color: kErrorColor)),
                      onPressed: () async {
                          Navigator.of(ctx).pop();
                          // إلغاء الطلب المعلق
                          await cartProvider.cancelPendingCheckout();
                          setState(() { _hasPendingCheckout = false; }); // تحديث الحالة
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('تم إلغاء عملية الدفع المعلقة.')),
                          );
                      },
                  ),
                  FilledButton( // استخدام FilledButton لتمييز الإجراء الأساسي
                      child: const Text('استئناف', style: TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: () {
                          Navigator.of(ctx).pop();
                          // التوجيه مباشرة إلى شاشة الدفع (حيث أنها تقرأ البيانات من 'checkoutOrders')
                          Navigator.of(context).pushNamed(CheckoutScreen.routeName); 
                      },
                  ),
              ],
          )
      );
  }

  @override                                       
  void initState() {                                
    super.initState();                              
    // 💡 بدلاً من استدعاء loadCartAndRecalculate مباشرة، نستخدم دالتنا الجديدة
    // التي تتضمن التحميل والتحقق من الطلب المعلق
    _checkAndShowPendingCheckout();
  }                                             
  
  @override                                       
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('سلة التسوق', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.surface, // استخدام لون الثيم
      ),
      // 💡 استخدام Consumer للاستماع لتغيرات الـ Provider                                            
      body: Consumer<CartProvider>(
        builder: (context, cartProvider, child) {
          if (cartProvider.isCartEmpty && !_hasPendingCheckout) { // إذا كانت السلة فارغة ولا يوجد طلب معلق
            return _buildEmptyCart();                     
          }
                                                          
          final sellerIds = cartProvider.sellersOrders.keys.toList();                           
          
          return SingleChildScrollView(                     
            padding: const EdgeInsets.all(15.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 💡 قسم خاص لتنبيه وجود طلب معلق (اختياري)
                if (_hasPendingCheckout)
                   _buildPendingCheckoutBanner(context), // 🟢🟢 تم إضافة هذا المكون 🟢🟢

                // 💡 بناء أقسام السلة حسب البائع (محاكاة دقيقة)                                                
                ...sellerIds.map((sellerId) {
                  final sellerData = cartProvider.sellersOrders[sellerId]!;                                       
                  return _buildSellerOrderSection(context, sellerData);                                         
                }).toList(),                                    
                const SizedBox(height: 25),
                
                // 💡 ملخص رسوم التوصيل                         
                if (cartProvider.totalDeliveryFees > 0)
                  _buildDeliverySummary(cartProvider.totalDeliveryFees),
                                                                
                const SizedBox(height: 15),
                
                // 💡 الإجمالي الكلي                            
                _buildTotalContainer(cartProvider.finalTotal),                                  
                
                const SizedBox(height: 20),
                
                // 💡 أزرار التحكم                              
                _buildActionButtons(context, cartProvider),                                                   
              ],                                            
            ),
          );                                            
        },                                            
      ),
    );
  }                                                                                               
  // ------------------------------------------   
  // 💡 مكونات واجهة المستخدم (Widgets)
  // ------------------------------------------
  
  // 🟢 مكون جديد: شريط تنبيه الطلب المعلق (يظهر إذا كان هناك طلب معلق ولم يختار المستخدم الإلغاء)
  Widget _buildPendingCheckoutBanner(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
        margin: const EdgeInsets.only(bottom: 20),
        color: theme.colorScheme.primaryContainer, // لون مميز من M3
        child: Padding(
            padding: const EdgeInsets.all(15),
            child: Row(
                children: [
                    Icon(Icons.payment, color: theme.colorScheme.onPrimaryContainer),
                    const SizedBox(width: 10),
                    Expanded(
                        child: Text(
                            'لديك طلب دفع قيد الانتظار. اضغط "استئناف الطلب" بالأسفل لإكماله.',
                            style: TextStyle(color: theme.colorScheme.onPrimaryContainer, fontWeight: FontWeight.bold),
                            textAlign: TextAlign.right,
                        ),
                    ),
                    const SizedBox(width: 10),
                    // زر "الاستئناف" في البانر (يمكن الاستغناء عنه والاكتفاء بالـ Dialog)
                    TextButton(
                        onPressed: () => Navigator.of(context).pushNamed(CheckoutScreen.routeName),
                        child: Text('استئناف', style: TextStyle(color: theme.colorScheme.primary)),
                    )
                ],
            )
        )
    );
  }
  
  // محاكاة لـ .empty-cart                        
  Widget _buildEmptyCart() {
    return Center(                                    
      child: Container(
        margin: const EdgeInsets.all(20),               
        padding: const EdgeInsets.all(40),              
        decoration: BoxDecoration(                        
          color: Colors.white,                            
          borderRadius: BorderRadius.circular(15),
          boxShadow: [                                      
            BoxShadow(                                        
              color: Colors.black.withOpacity(0.08),
              blurRadius: 10,                                 
              offset: const Offset(0, 3),
            ),
          ],                                            
        ),
        child: Column(                                    
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.shopping_cart, size: 60, color: Colors.grey.shade400),
            const SizedBox(height: 20),                     
            Text(
              'سلة التسوق فارغة',                             
              style: TextStyle(fontSize: 18, color: Colors.grey.shade600),                                  
            ),
          ],                                            
        ),
      ),                                            
    );
  }                                             
  
  // محاكاة لمنطق عرض الطلب المجمع حسب البائع (يشمل التحذيرات وعناصر الهدايا)                     
  Widget _buildSellerOrderSection(BuildContext context, SellerOrderData sellerData) {
    // 1. رسالة تحذير الحد الأدنى (Min Order Status)
    final bool isMinOrderMet = sellerData.isMinOrderMet;
                                                    
    // 2. الهدايا المستحقة (Gifts) - إذا تحقق الحد الأدنى                                           
    final List<Widget> giftsWidgets = [];
    if (isMinOrderMet && sellerData.giftedItems.isNotEmpty) {
      giftsWidgets.add(
        Padding(                                          
          padding: const EdgeInsets.only(right: 20.0, top: 10.0),
          child: CartItemCard(
            item: sellerData.giftedItems.first, // عرض الهدية الأولى كنموذج                                 
            isWarning: false,
          ),
        ),
      );                                            
    }
                                                    
    // 3. قائمة المنتجات
    final List<Widget> itemWidgets = sellerData.items.asMap().entries.map((entry) {                   
      final index = entry.key;
      final item = entry.value;                 
      // 💡 [ملاحظة]: نحتاج طريقة لتحديد خطأ المخزون الفعلي، هنا نستخدم قيمة وهمية الآن
      final String? itemError = sellerData.hasProductErrors && index == 0 ? "الحد الأقصى هو 5 وحدات." : null;                                                                                         
      return CartItemCard(
        item: item,
        isWarning: !isMinOrderMet,                      
        itemError: itemError,
      );                                            
    }).toList();                                
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,                                                 
      children: [
        // 1. رسالة الحد الأدنى (Min Order Link/Success)                                                
        _buildMinOrderWarning(                            
          context,
          isMinOrderMet: isMinOrderMet,
          sellerName: sellerData.sellerName,
          message: sellerData.minOrderAlert ?? '',
        ),
        // 2. الهدايا
        ...giftsWidgets,                        
        // 3. المنتجات الفعلية
        ...itemWidgets,                         
        const Divider(thickness: 1, height: 30),      
      ],                                            
    );                                            
  }                                             
  
  // محاكاة لـ .warning-message
  Widget _buildMinOrderWarning(BuildContext context, {
    required bool isMinOrderMet,
    required String sellerName,
    required String message,
  }) {
    Color bgColor = isMinOrderMet ? Colors.green.shade50 : kWarningMessageBg;                       
    Color borderColor = isMinOrderMet ? kPrimaryColor : kWarningMessageBorder;
    Color textColor = isMinOrderMet ? Colors.green.shade800 : kWarningMessageText;                  
    Color linkColor = isMinOrderMet ? kPrimaryColor : kErrorColor;                                  
    String linkText = isMinOrderMet ? 'عروض $sellerName المميزة' : 'أكمل طلبك من $sellerName';      
    IconData icon = isMinOrderMet ? Icons.check_circle : Icons.warning;                                                                             
    return Container(
      margin: const EdgeInsets.only(bottom: 10),      
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: bgColor,                                 
        borderRadius: BorderRadius.circular(8),
        border: Border(left: BorderSide(color: borderColor, width: 5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,                                                   
        children: [
          Row(
            children: [                                       
              Icon(icon, color: borderColor, size: 20),
              const SizedBox(width: 10),                      
              Expanded(
                child: Text(message, style: TextStyle(color: textColor, fontSize: 15)),                       
              ),
            ],                                            
          ),
          const SizedBox(height: 8),                      
          // 💡 محاكاة لـ .min-order-link
          GestureDetector(                                  
            onTap: () {                                       
              // توجيه لصفحة عروض التاجر                      
              ScaffoldMessenger.of(context).showSnackBar(                                                       
                SnackBar(content: Text('الانتقال إلى عروض $sellerName...')),                                  
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                border: Border.all(color: linkColor, width: 1),                                                 
                borderRadius: BorderRadius.circular(5),
              ),                                              
              child: Row(                                       
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(isMinOrderMet ? Icons.tag : Icons.add_circle, color: linkColor, size: 16),                                                                 
                  const SizedBox(width: 5),
                  Text(linkText, style: TextStyle(color: linkColor, fontWeight: FontWeight.bold, fontSize: 14)),                                                
                ],
              ),                                            
            ),
          ),                                            
        ],
      ),
    );
  }                                                                                               
  // محاكاة لـ .delivery-summary
  Widget _buildDeliverySummary(double fee) {        
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(                        
        color: kDeliverySummaryBg,
        borderRadius: BorderRadius.circular(8),         
        border: const Border(left: BorderSide(color: kGiftBorderColor, width: 5)),
      ),                                              
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [                                       
          const Icon(Icons.delivery_dining, color: kDeliverySummaryText, size: 20),                       
          const SizedBox(width: 10),                      
          Text(
            'رسوم التوصيل: ${fee.toStringAsFixed(2)} جنيه',                                                 
            style: const TextStyle(                           
              fontSize: 16,
              fontWeight: FontWeight.w500,                    
              color: kDeliverySummaryText,
            ),
          ),                                            
        ],
      ),
    );
  }

  // محاكاة لـ .total-container
  Widget _buildTotalContainer(double total) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface, // استخدام لون الثيم
        borderRadius: BorderRadius.circular(15),        
        boxShadow: [                                      
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),                                            
        ],
      ),                                              
      child: Column(                                    
        children: [
          Text(
            'الإجمالي الكلي',                               
            style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 10),
          Text(
            '${total.toStringAsFixed(2)} جنيه',
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: kPrimaryColor,
            ),                                            
          ),
        ],                                            
      ),
    );                                            
  }

  // محاكاة لـ .action-buttons
  Widget _buildActionButtons(BuildContext context, CartProvider cartProvider) {                     
    final bool isCheckoutEnabled = !cartProvider.hasCheckoutErrors;
                                                    
    return Column(
      children: [                                       
        // زر إفراغ السلة
        ElevatedButton.icon(
          onPressed: () => cartProvider.clearCart(),
          icon: const Icon(Icons.delete, color: Colors.white),
          label: const Text('إفراغ السلة', style: TextStyle(fontSize: 17, color: Colors.white, fontWeight: FontWeight.w600)),                             
          style: ElevatedButton.styleFrom(                  
            backgroundColor: kClearButtonColor,
            padding: const EdgeInsets.symmetric(vertical: 15),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 4,
          ),
        ),
        const SizedBox(height: 15),
                                                        
        // زر إتمام الطلب
        ElevatedButton.icon(
          // 🛑🛑 تم التعديل هنا: استخدام دالة proceedToCheckout (لا حاجة للتوجيه هنا إذا كانت الدالة هي من يتولى التوجيه) 🛑🛑
          onPressed: isCheckoutEnabled
              ? () {
                  // الدالة proceedToCheckout تتولى:
                  // 1. نقل البيانات إلى 'checkoutOrders'
                  // 2. التوجيه إلى CheckoutScreen.routeName
                  cartProvider.proceedToCheckout(context);
              }
              : null,                                     
          icon: const Icon(Icons.check_circle, color: Colors.white),                                      
          label: const Text('إتمام الطلب', style: TextStyle(fontSize: 17, color: Colors.white, fontWeight: FontWeight.w600)),
          style: ElevatedButton.styleFrom(
            backgroundColor: kPrimaryColor,                 
            padding: const EdgeInsets.symmetric(vertical: 15),                                              
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 4,                                 
          ),
        ),
      ],                                            
    );                                            
  }
}
