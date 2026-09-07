// المسار: lib/screens/checkout/checkout_screen.dart

import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
// استيراد الـ Controller الجديد
import 'package:my_test_app/controllers/checkout_controller.dart';

// استيراد الأجزاء الأخرى
import 'widgets/customer_info_widget.dart';
import 'widgets/order_summary_widget.dart';
import 'widgets/payment_and_final_widget.dart';


// 🎨 تعريف الألوان بناءً على CSS
const Color kPrimaryColor = Color(0xFF4CAF50);
const Color kErrorColor = Color(0xFFE74C3C);

class CheckoutScreen extends StatefulWidget {

  static const String routeName = '/checkout';

  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {

  List<Map<String, dynamic>> _checkoutOrders = []; // قائمة الأصناف المسطحة من SharedPreferences
  // 🟢🟢 New: هيكل بيانات لتخزين الطلبات المجمعة حسب البائع 🟢🟢
  List<Map<String, dynamic>> _groupedSellerOrders = [];

  Map<String, dynamic> _loggedUser = {};
  double _currentCashback = 0.0;
  double _originalOrderTotal = 0.0;
  String _selectedPaymentMethod = 'cash_on_delivery';
  bool _isConsumer = false;
  bool _useCashback = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  // 🟢🟢 دالة مساعدة جديدة: تجميع الأصناف حسب البائعين 🟢🟢
  List<Map<String, dynamic>> _groupOrdersBySeller(List<Map<String, dynamic>> orders) {
    // 💡 هذا المنطق يفترض أن كل CartItem يحمل sellerId و sellerName
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    final Map<String, String> sellerNames = {};

    for (var item in orders) {
      final sellerId = item['sellerId'] as String?;
      if (sellerId != null && sellerId.isNotEmpty) {
        if (!grouped.containsKey(sellerId)) {
          grouped[sellerId] = [];
          sellerNames[sellerId] = item['sellerName'] ?? 'بائع غير معروف';
        }
        grouped[sellerId]!.add(item);
      }
    }

    // تحويل الخريطة إلى قائمة مهيكلة (List of Orders)
    return grouped.entries.map((entry) {
      // نفترض أن رسوم التوصيل (deliveryFee) مخزنة في أول عنصر بالبائع (افتراض غير مثالي، لكن للتبسيط)
      final double deliveryFee = entry.value.first['deliveryFee'] as double? ?? 0.0;

      // حساب إجمالي الطلب لهذا البائع
      double sellerTotal = 0.0;
      for (var item in entry.value) {
        if (!(item['isGift'] ?? false)) {
          final price = (item['price'] as num?)?.toDouble() ?? 0.0;
          final quantity = (item['quantity'] as num?)?.toDouble() ?? 0.0;
          sellerTotal += (price * quantity);
        }
      }

      return {
        'sellerId': entry.key,
        'sellerName': sellerNames[entry.key],
        'items': entry.value,
        'subTotal': sellerTotal,
        'deliveryFee': deliveryFee,
        'orderTotal': sellerTotal + deliveryFee,
      };
    }).toList();
  }

  // دالة لحساب الإجمالي المبدئي (الأصناف المدفوعة ورسوم التوصيل المدفوعة)
  double _calculateOriginalTotal(List<Map<String, dynamic>> items) {
    double total = 0.0;
    for (var item in items) {
      if (!(item['isGift'] ?? false)) {
        final price = (item['price'] as num?)?.toDouble() ?? 0.0;
        final quantity = (item['quantity'] as num?)?.toDouble() ?? 0.0;
        total += (price * quantity);
      }
    }
    return total;
  }

  double get _finalTotalAmount {
    double finalAmount = _originalOrderTotal;
    final double discountAmount = _useCashback
        ? min(_originalOrderTotal, _currentCashback)
        : 0.0;
    return max(0.0, _originalOrderTotal - discountAmount);
  }

  Future<void> _loadInitialData() async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString('loggedUser');

    if (userJson != null) {
      _loggedUser = json.decode(userJson);
      _isConsumer = (_loggedUser['role'] == 'consumer');
    }

    final ordersJson = prefs.getString('checkoutOrders');

    if (ordersJson != null) {
      _checkoutOrders = List<Map<String, dynamic>>.from(json.decode(ordersJson));
    }

    // 🟢🟢 New: تجميع الطلبات وحساب الإجمالي بعد التحميل 🟢🟢
    _groupedSellerOrders = _groupOrdersBySeller(_checkoutOrders);
    _originalOrderTotal = _calculateOriginalTotal(_checkoutOrders);

    if (_checkoutOrders.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('لا توجد منتجات في سلة الدفع.'), backgroundColor: kErrorColor)
        );
      });
      return;
    }

    await _fetchCashback(_loggedUser['id'] ?? '');


    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // ----------------------------------------------------
  // 🔥🔥 الدالة المعدلة: جلب الكاش باك من Controller 🔥🔥
  // ----------------------------------------------------
  Future<void> _fetchCashback(String userId) async {
    if (userId.isEmpty) return;

    // 🎯 الاستدعاء من CheckoutController لجلب الرصيد الحقيقي
    final fetchedAmount = await CheckoutController.fetchCashback(
        userId,
        _loggedUser['role'] ?? 'user' // تمرير الدور لتحديد اسم المجموعة
    );

    if (mounted) {
      setState(() {
        _currentCashback = fetchedAmount; // ✅ تعيين القيمة الحقيقية
      });
    }
  }
  // ----------------------------------------------------


  // ----------------------------------------------------
  // 🎯 دالة _placeOrder المعدلة: تمرير _groupedSellerOrders 🎯
  // ----------------------------------------------------
  Future<void> _placeOrder(BuildContext context) async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    // 🟢🟢 Modification: تمرير _groupedSellerOrders بدلاً من _checkoutOrders 🟢🟢
    final success = await CheckoutController.placeOrder(
        context: context,
        // _checkoutOrders كانت قائمة مسطحة، الآن نمرر الهيكل المجمع
        checkoutOrders: _groupedSellerOrders, // 🟢 تم التعديل هنا 🟢
        loggedUser: _loggedUser,
        originalOrderTotal: _originalOrderTotal,
        currentCashback: _currentCashback,
        finalTotalAmount: _finalTotalAmount,
        useCashback: _useCashback,
        selectedPaymentMethod: _selectedPaymentMethod,
    );

    if (mounted) {
        if (success) {
            final prefs = await SharedPreferences.getInstance();
            await prefs.remove('checkoutOrders'); // إفراغ سلة الدفع بعد النجاح

            ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('✅ تم تأكيد الطلبات بنجاح! شكراً لك.'), backgroundColor: kPrimaryColor)
            );
            // توجيه المستخدم إلى الصفحة الرئيسية
            Navigator.of(context).popUntil((route) => route.isFirst);
        } else {
            // ملاحظة: الـ SnackBar الخاص بالخطأ يتم إظهاره داخل الـ Controller
        }
        setState(() {
            _isLoading = false;
        });
    }
  }
  // ----------------------------------------------------


  @override
  Widget build(BuildContext context) {

    if (_isLoading || _checkoutOrders.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('إتمام الطلب', style: TextStyle(fontWeight: FontWeight.bold))),

        body: Center(child: _checkoutOrders.isEmpty
            ? const Text('لا يوجد طلب لعرضه.', style: TextStyle(color: Colors.grey))
            : const CircularProgressIndicator(color: kPrimaryColor)),

      );
    }


    return Scaffold(
      appBar: AppBar(
        title: const Text('إتمام الطلب', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: kPrimaryColor,
        iconTheme: const IconThemeData(color: Colors.white),

      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(15.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,

          children: <Widget>[
            CustomerInfoWidget(loggedUser: _loggedUser),

            const SizedBox(height: 20),
            OrderSummaryWidget(
              // 🟢🟢 التعديل الذي يحل المشكلة: تغيير اسم المعلمة إلى sellerOrders 🟢🟢
              sellerOrders: _groupedSellerOrders, // ✅ تم تصحيح اسم المعلمة هنا
              originalOrderTotal: _originalOrderTotal,
            ),

            const SizedBox(height: 20),
            PaymentAndFinalWidget(
              originalOrderTotal: _originalOrderTotal,

              currentCashback: _currentCashback,
              finalTotalAmount: _finalTotalAmount,
              useCashback: _useCashback,
              selectedPaymentMethod: _selectedPaymentMethod,

              onPaymentMethodChanged: (method) {
                setState(() => _selectedPaymentMethod = method);
              },
              onCashbackToggle: (use) {
                setState(() => _useCashback = use);
              },
              onPlaceOrder: () => _placeOrder(context),
            ),
            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }
}

