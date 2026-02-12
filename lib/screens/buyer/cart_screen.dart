// lib/screens/buyer/cart_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:my_test_app/providers/cart_provider.dart';
import 'package:my_test_app/widgets/cart/cart_item_card.dart';
import 'package:my_test_app/screens/checkout/checkout_screen.dart';
import 'package:my_test_app/screens/buyer/trader_offers_screen.dart';

const Color kPrimaryColor = Color(0xFF3bb77e);
const Color kErrorColor = Color(0xFFDC3545);
const Color kClearButtonColor = Color(0xFFff7675);
const Color kDeliverySummaryBg = Color(0xFFE0F7FA);
const Color kDeliverySummaryText = Color(0xFF00838f);
const Color kWarningMessageBg = Color(0xFFfff3cd);
const Color kWarningMessageBorder = Color(0xFFffc107);
const Color kWarningMessageText = Color(0xFF856404);
const Color kGiftBorderColor = Color(0xFF00838f);

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
    await cartProvider.loadCartAndRecalculate(_kUserRole);
    final isPending = await cartProvider.hasPendingCheckout;

    if (isPending) {
      setState(() { _hasPendingCheckout = true; });
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
            },
          ),
          FilledButton(
            child: const Text('استئناف'),
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pushNamed(CheckoutScreen.routeName);
            },
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _checkAndShowPendingCheckout();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('سلة التسوق', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
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
                if (_hasPendingCheckout) _buildPendingCheckoutBanner(context),
                ...sellerIds.map((sellerId) {
                  final sellerData = cartProvider.sellersOrders[sellerId]!;
                  return _buildSellerOrderSection(context, sellerData);
                }).toList(),
                if (cartProvider.totalDeliveryFees > 0)
                  _buildDeliverySummary(cartProvider.totalDeliveryFees),
                const SizedBox(height: 130),
              ],
            ),
          );
        },
      ),
      // تم إضافة SafeArea هنا لتأمين أزرار التحكم السفلى
      bottomNavigationBar: Consumer<CartProvider>(
        builder: (context, cartProvider, child) {
          if (cartProvider.isCartEmpty && !_hasPendingCheckout) return const SizedBox.shrink();
          return SafeArea(
            bottom: true,
            child: _buildCartSummaryAndActions(context, cartProvider),
          );
        },
      ),
    );
  }

  Widget _buildSellerOrderSection(BuildContext context, SellerOrderData sellerData) {
    final bool isMinOrderMet = sellerData.isMinOrderMet;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildMinOrderWarning(
          context,
          isMinOrderMet: isMinOrderMet,
          sellerName: sellerData.sellerName,
          message: sellerData.minOrderAlert ?? '',
          sellerId: sellerData.sellerId,
          minOrderAmount: sellerData.minOrderTotal, 
        ),
        ...sellerData.items.map((item) => CartItemCard(
          item: item,
          isWarning: !isMinOrderMet,
          itemError: sellerData.hasProductErrors ? "خطأ في الكمية/المخزون" : null,
        )).toList(),
        const Divider(thickness: 1, height: 30),
      ],
    );
  }

  Widget _buildMinOrderWarning(BuildContext context, {
    required bool isMinOrderMet,
    required String sellerName,
    required String message,
    required String sellerId,
    required double minOrderAmount,
  }) {
    Color borderColor = isMinOrderMet ? kPrimaryColor : kWarningMessageBorder;
    Color linkColor = isMinOrderMet ? kPrimaryColor : kErrorColor;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isMinOrderMet ? Colors.green.shade50 : kWarningMessageBg,
        borderRadius: BorderRadius.circular(8),
        border: Border(right: BorderSide(color: borderColor, width: 5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(isMinOrderMet ? Icons.check_circle : Icons.warning, color: borderColor, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(message, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    Text('حد الطلب الأدنى لـ $sellerName: ${minOrderAmount.toStringAsFixed(0)} ج', 
                         style: const TextStyle(color: Colors.black54, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () {
              Navigator.of(context).pushNamed(
                TraderOffersScreen.routeName, 
                arguments: sellerId
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.6),
                border: Border.all(color: linkColor),
                borderRadius: BorderRadius.circular(5),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(isMinOrderMet ? Icons.store : Icons.add_shopping_cart, color: linkColor, size: 16),
                  const SizedBox(width: 5),
                  Text(isMinOrderMet ? 'زيارة متجر $sellerName' : 'أكمل طلبك من هنا', 
                       style: TextStyle(color: linkColor, fontWeight: FontWeight.bold, fontSize: 13)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCartSummaryAndActions(BuildContext context, CartProvider cartProvider) {
    return Container(
      // تم تعديل الـ padding السفلي ليكون متناسقاً مع الـ SafeArea
      padding: const EdgeInsets.fromLTRB(15, 10, 15, 10), 
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: const Offset(0, -3))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('الإجمالي الكلي:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
              Text('${cartProvider.finalTotal.toStringAsFixed(2)} جنيه',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: kPrimaryColor)),
            ],
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => cartProvider.clearCart(),
                  icon: const Icon(Icons.delete, color: Colors.white, size: 18),
                  label: const Text('إفراغ', style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(backgroundColor: kClearButtonColor),
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: !cartProvider.hasCheckoutErrors ? () => cartProvider.proceedToCheckout(context, _kUserRole) : null,
                  icon: const Icon(Icons.check_circle, color: Colors.white, size: 18),
                  label: const Text('إتمام الطلب', style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(backgroundColor: kPrimaryColor),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyCart() {
    return const Center(child: Text('سلة التسوق فارغة', style: TextStyle(fontSize: 18, color: Colors.grey)));
  }

  Widget _buildPendingCheckoutBanner(BuildContext context) {
    return Card(
      color: Colors.blue.shade50,
      child: ListTile(
        leading: const Icon(Icons.payment, color: Colors.blue),
        title: const Text('لديك طلب دفع معلق', style: TextStyle(fontWeight: FontWeight.bold)),
        trailing: TextButton(
          onPressed: () => Navigator.of(context).pushNamed(CheckoutScreen.routeName),
          child: const Text('استئناف'),
        ),
      ),
    );
  }

  Widget _buildDeliverySummary(double fee) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: kDeliverySummaryBg, borderRadius: BorderRadius.circular(8)),
      child: Center(child: Text('رسوم التوصيل الإجمالية: ${fee.toStringAsFixed(2)} ج', 
                   style: const TextStyle(color: kDeliverySummaryText, fontWeight: FontWeight.bold))),
    );
  }
}
