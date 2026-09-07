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

// 🛑 تعريف دور المستخدم لهذه الشاشة (للتوافق مع CartProvider)
const String _kUserRole = 'consumer';

class CartScreen extends StatefulWidget {
  static const String routeName = '/cart';

  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  bool _hasPendingCheckout = false;

  Future<void> _checkAndShowPendingCheckout() async {
    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    // 💡 [تعديل]: تمرير الدور عند تحميل السلة لأول مرة
    await cartProvider.loadCartAndRecalculate(_kUserRole);
    final isPending = await cartProvider.hasPendingCheckout;

    if (isPending) {
        setState(() {
            _hasPendingCheckout = true;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
            _showPendingCheckoutDialog(cartProvider);
        });
    }
  }

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
                          await cartProvider.cancelPendingCheckout();
                          setState(() { _hasPendingCheckout = false; });
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('تم إلغاء عملية الدفع المعلقة.')),
                          );
                      },
                  ),
                  FilledButton(
                      child: const Text('استئناف', style: TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: () {
                          Navigator.of(ctx).pop();
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
    _checkAndShowPendingCheckout();
  }

  // 💡 [تعديل 1]: تم ضغط هذه الدالة لتقليل الـ Padding واستخدام العناصر المضغوطة
  Widget _buildCartSummaryAndActions(BuildContext context, CartProvider cartProvider) {
    return Container(
      // 💡 [تعديل]: تقليل الـ Padding الكلي للشريط
      padding: const EdgeInsets.fromLTRB(15, 10, 15, 20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface, // لون خلفية الشريط
        boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15), // زيادة وضوح الظل العلوي
              blurRadius: 10,
              offset: const Offset(0, -3), // ظل يظهر من الأسفل للأعلى
            ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min, // مهم جداً
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
            _buildTotalContainer(cartProvider.finalTotal),
            // 💡 [تعديل]: تقليل المسافة بين الإجمالي والأزرار
            const SizedBox(height: 15),
            _buildActionButtons(context, cartProvider),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('سلة التسوق', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.surface,
      ),
      // 💡 [تعديل 1]: استخدام Consumer في الـ body
      body: Consumer<CartProvider>(
        builder: (context, cartProvider, child) {
            if (cartProvider.isCartEmpty && !_hasPendingCheckout) {
              return _buildEmptyCart();
            }

            final sellerIds = cartProvider.sellersOrders.keys.toList();
            return SingleChildScrollView(
              padding: const EdgeInsets.all(15.0),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                      if (_hasPendingCheckout)
                         _buildPendingCheckoutBanner(context),

                      // 💡 بناء أقسام السلة حسب البائع
                      ...sellerIds.map((sellerId) {
                          final sellerData = cartProvider.sellersOrders[sellerId]!;
                          return _buildSellerOrderSection(context, sellerData);
                      }).toList(),

                      // 💡 ملخص رسوم التوصيل
                      if (cartProvider.totalDeliveryFees > 0)
                          _buildDeliverySummary(cartProvider.totalDeliveryFees),

                      // 💡 [تعديل 2]: تقليل المسافة السفلية لتتناسب مع الشريط المضغوط
                      const SizedBox(height: 130), // تم تقليله من 180

                  ],
              ),
            );
        },
      ),
      // 💡 [تعديل 3]: تثبيت شريط الملخص والإجراءات في الأسفل باستخدام bottomNavigationBar
      bottomNavigationBar: Consumer<CartProvider>(
        builder: (context, cartProvider, child) {
            if (cartProvider.isCartEmpty && !_hasPendingCheckout) {
              return const SizedBox.shrink(); // إخفاء الشريط إذا كانت السلة فارغة
            }
            // استخدام الودجت المجمع الجديد
            return _buildCartSummaryAndActions(context, cartProvider);
        },
      ),
    );
  }
  // ------------------------------------------
  // 💡 مكونات واجهة المستخدم (Widgets)
  // ------------------------------------------
  Widget _buildPendingCheckoutBanner(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
        margin: const EdgeInsets.only(bottom: 20),
        color: theme.colorScheme.primaryContainer,
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
                    TextButton(
                        onPressed: () => Navigator.of(context).pushNamed(CheckoutScreen.routeName),
                        child: Text('استئناف', style: TextStyle(color: theme.colorScheme.primary)),
                    )
                ],
            )
        )
    );
  }

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

  Widget _buildSellerOrderSection(BuildContext context, SellerOrderData sellerData) {
    final bool isMinOrderMet = sellerData.isMinOrderMet;
    final List<Widget> giftsWidgets = [];
    if (isMinOrderMet && sellerData.giftedItems.isNotEmpty) {
      // 💡 يتم عرض أول هدية فقط هنا كمثال
      giftsWidgets.add(
          Padding(
              padding: const EdgeInsets.only(right: 20.0, top: 10.0),
              child: CartItemCard(
                  item: sellerData.giftedItems.first,
                  isWarning: false,
              ),
          ),
      );
    }

    final List<Widget> itemWidgets = sellerData.items.asMap().entries.map((entry) {
        final item = entry.value;
        // يجب أن يأتي الخطأ الفعلي من CartProvider بناءً على التحقق من المخزون/الحد الأقصى
        final String? itemError = sellerData.hasProductErrors ? "يوجد خطأ في الكمية المطلوبة/المخزون." : null;

        return CartItemCard(
            item: item,
            isWarning: !isMinOrderMet,
            itemError: itemError,
        );
    }).toList();

    return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
            _buildMinOrderWarning(
                context,
                isMinOrderMet: isMinOrderMet,
                sellerName: sellerData.sellerName,
                message: sellerData.minOrderAlert ?? '',
            ),
            ...giftsWidgets,
            ...itemWidgets,
            const Divider(thickness: 1, height: 30),
        ],
    );
  }

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
                GestureDetector(
                    onTap: () {
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

  // 💡 [تعديل 4]: تم تعديل هذه الدالة لعرض الإجمالي في صف واحد وبحجم أصغر
  Widget _buildTotalContainer(double total) {
    return Container(
      // 💡 [تعديل]: تقليل الـ Padding العمودي هنا
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        // 💡 [تعديل]: تقليل الـ Radius
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05), // تخفيف الظل
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      // 💡 [تعديل]: تغيير الترتيب لصف (Row) بدل عمود (Column)
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'الإجمالي الكلي:',
            // 💡 [تعديل]: تعديل الحجم والوزن
            style: TextStyle(fontSize: 18, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
          ),
          Text(
            '${total.toStringAsFixed(2)} جنيه',
            style: const TextStyle(
              // 💡 [تعديل]: تقليل حجم الخط
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: kPrimaryColor,
            ),
          ),
        ],
      ),
    );
  }

  // 💡 [تعديل 5]: تم تعديل هذه الدالة لعرض الأزرار في صف واحد (Row)
  Widget _buildActionButtons(BuildContext context, CartProvider cartProvider) {
    final bool isCheckoutEnabled = !cartProvider.hasCheckoutErrors;

    // 💡 [تعديل]: تحويل الأزرار من Column إلى Row
    return Row(
      children: [
        // زر إفراغ السلة (Expanded 1)
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => cartProvider.clearCart(),
            // 💡 [تعديل]: تقليل حجم الأيقونة والخط والـ Padding
            icon: const Icon(Icons.delete, color: Colors.white, size: 18),
            label: const Text('إفراغ السلة', style: TextStyle(fontSize: 15, color: Colors.white, fontWeight: FontWeight.w600)),
            style: ElevatedButton.styleFrom(
              backgroundColor: kClearButtonColor,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 3,
            ),
          ),
        ),

        const SizedBox(width: 15), // مسافة بين الزرين

        // زر إتمام الطلب (Expanded 2)
        Expanded(
          child: ElevatedButton.icon(
            onPressed: isCheckoutEnabled
                ? () {
                    // 🛑 [التصحيح الرئيسي]: تم تمرير وسيطة userRole ('consumer')
                    cartProvider.proceedToCheckout(context, _kUserRole);
                }
                : null,
            // 💡 [تعديل]: تقليل حجم الأيقونة والخط والـ Padding
            icon: const Icon(Icons.check_circle, color: Colors.white, size: 18),
            label: const Text('إتمام الطلب', style: TextStyle(fontSize: 15, color: Colors.white, fontWeight: FontWeight.w600)),
            style: ElevatedButton.styleFrom(
              backgroundColor: kPrimaryColor,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 3,
            ),
          ),
        ),
      ],
    );
  }
}

