 
// المسار: lib/providers/cart_provider.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';
import 'package:my_test_app/services/marketplace_data_service.dart'; // تأكد من وجود هذا الملف

// =========================================================================
// 💡 هياكل البيانات المساعدة (Models)
// =========================================================================
class CartItem {
  final String offerId;
  final String productId;
  final String sellerId;
  final String sellerName;
  final String name;
  double price;
  final String unit;
  final int unitIndex;
  int quantity;
  final bool isGift;
  final String imageUrl;

  CartItem({
    required this.offerId,
    required this.productId,
    required this.sellerId,
    required this.sellerName,
    required this.name,
    required this.price,
    required this.unit,
    required this.unitIndex,
    this.quantity = 1,
    this.isGift = false,
    required this.imageUrl,
  });

  Map<String, dynamic> toJson() => {
    'offerId': offerId,
    'productId': productId,
    'sellerId': sellerId,
    'sellerName': sellerName,
    'name': name,
    'price': price,
    'unit': unit,
    'unitIndex': unitIndex,
    'quantity': quantity,
    'isGift': isGift,
    'imageUrl': imageUrl,
  };

  factory CartItem.fromJson(Map<String, dynamic> json) {
    return CartItem(
      offerId: json['offerId'] as String,
      productId: json['productId'] as String? ?? json['offerId'] as String,
      sellerId: json['sellerId'] as String,
      sellerName: json['sellerName'] as String,
      name: json['name'] as String,
      price: (json['price'] as num).toDouble(),
      unit: json['unit'] as String,
      unitIndex: json['unitIndex'] as int,
      quantity: json['quantity'] as int? ?? 1,
      isGift: json['isGift'] as bool? ?? false,
      imageUrl: json['imageUrl'] as String? ?? '',
    );
  }
}

class SellerOrderData {
  final String sellerId;
  final String sellerName;
  final List<CartItem> items;
  List<CartItem> giftedItems = [];
  double total = 0.0;
  double minOrderTotal = 0.0;
  double deliveryFee = 0.0;
  bool isMinOrderMet = true;
  bool hasProductErrors = false;
  String? minOrderAlert;

  SellerOrderData({
    required this.sellerId,
    required this.sellerName,
    required this.items,
  });
}

// =========================================================================
// 🛒 Cart Provider
// =========================================================================
class CartProvider with ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final MarketplaceDataService _dataService = MarketplaceDataService(); // مثيل الخدمة

  // الحالة الداخلية
  List<CartItem> _cartItems = [];
  Map<String, SellerOrderData> _sellersOrders = {};

  // Caching
  final Map<String, Map<String, dynamic>> _sellerRulesCache = {};
  final Map<String, List<Map<String, dynamic>>> _giftPromosCache = {};

  // الإجماليات
  double _totalProductsAmount = 0.0;
  double _totalDeliveryFees = 0.0;
  bool _hasCheckoutErrors = false;

  // ------------------------------------------
  // ✅ Getter Properties (للوصول من الـ UI)
  // ------------------------------------------
  Map<String, SellerOrderData> get sellersOrders => _sellersOrders;
  double get totalProductsAmount => _totalProductsAmount;
  double get totalDeliveryFees => _totalDeliveryFees;
  double get finalTotal => _totalProductsAmount + _totalDeliveryFees;
  bool get hasCheckoutErrors => _hasCheckoutErrors;
  int get cartTotalItems => _cartItems.where((item) => !item.isGift).length;
  int get itemCount => cartTotalItems; // اسم مستعار بسيط
  int get cartTotalQuantity {
    return _cartItems.where((item) => !item.isGift).fold(0, (sum, item) => sum + item.quantity);
  }
  bool get isCartEmpty => _cartItems.where((item) => !item.isGift).isEmpty;

  Future<bool> get hasPendingCheckout async {
    final prefs = await SharedPreferences.getInstance();
    final checkoutJson = prefs.getString('checkoutOrders');
    if (checkoutJson != null && checkoutJson.isNotEmpty) {
      try {
        return json.decode(checkoutJson).isNotEmpty;
      } catch (e) {
        return false;
      }
    }
    return false;
  }

  // ------------------------------------------
  // 1. دوال جلب القواعد (الاتصال بـ Firestore)
  // ------------------------------------------
  Future<Map<String, dynamic>> _getSellerBusinessRules(String sellerId, String buyerRole) async {
    if (_sellerRulesCache.containsKey(sellerId)) return _sellerRulesCache[sellerId]!;

    double finalMinTotal = 0.0;
    double finalDeliveryFee = 0.0;

    // 1. البحث دائمًا في مجموعة 'sellers'
    try {
      final docSnap = await _db.collection('sellers').doc(sellerId).get();
      if (docSnap.exists) {
        final data = docSnap.data()!;
        finalMinTotal = (data['minOrderTotal'] as num?)?.toDouble() ?? 0.0;
        finalDeliveryFee = (data['deliveryFee'] as num?)?.toDouble() ?? 0.0;

        // 🛑 القاعدة 1: إذا كان الدور 'buyer'، نعتمد على نتيجة 'sellers' فقط وننتهي.
        if (buyerRole == 'buyer') {
          final rules = { 'minTotal': finalMinTotal, 'deliveryFee': finalDeliveryFee };
          _sellerRulesCache[sellerId] = rules;
          return rules;
        }
      }
    } catch (e) {
      print('Firestore Error fetching from sellers: $e');
    }

    // 2. البحث الإضافي في 'deliverySupermarkets' (القاعدة 3: خاص بالمستهلكين)
    // استخدام اسم المجموعة الصحيح بناءً على معلوماتك المحفوظة: deliverySupermarkets
    if (buyerRole == 'consumer' && finalMinTotal == 0.0 && finalDeliveryFee == 0.0) {
      try {
        final docSnap = await _db.collection('deliverySupermarkets').doc(sellerId).get();
        if (docSnap.exists) {
          final data = docSnap.data()!;
          finalMinTotal = (data['minimumOrderValue'] as num?)?.toDouble() ?? 0.0;
          finalDeliveryFee = (data['deliveryFee'] as num?)?.toDouble() ?? 0.0;
          print('DEBUG RULE: Fetched minOrderValue $finalMinTotal and deliveryFee $finalDeliveryFee for seller $sellerId from deliverySupermarkets');
        } else {
          print('DEBUG RULE: Document NOT found in deliverySupermarkets for seller $sellerId');
        }
      } catch (e) {
        print('Firestore Error fetching from deliverySupermarkets: $e');
      }
    }

    // 3. القاعدة 4: إرجاع النتائج (قد تكون 0/0) وتخزينها مؤقتاً
    final rules = {
      'minTotal': finalMinTotal,
      'deliveryFee': finalDeliveryFee,
      'buyerRole': buyerRole,
    };

    _sellerRulesCache[sellerId] = rules;
    return rules;
  }

  Future<List<Map<String, dynamic>>> _getGiftPromosBySellerId(String sellerId) async {
    if (_giftPromosCache.containsKey(sellerId)) return _giftPromosCache[sellerId]!;
    // ... (بقية الكود يبقى كما هو) ...
    try {
      final querySnapshot = await _db
          .collection('giftPromos')
          .where('sellerId', isEqualTo: sellerId)
          .where('status', isEqualTo: 'active')
          .get();

      final promos = querySnapshot.docs.map((doc) => doc.data()).toList();
      _giftPromosCache[sellerId] = promos;
      return promos;
    } catch (e) {
      print('Firestore Error fetching giftPromos: $e');
      return [];
    }
  }

  // ------------------------------------------
  // دالة حساب الهدايا
  // ------------------------------------------
  List<CartItem> _calculateGifts(SellerOrderData sellerData, List<Map<String, dynamic>> promos) {
    // ... (بقية الكود يبقى كما هو) ...
    final giftedItems = <CartItem>[];
    for (var promo in promos) {
      final trigger = promo['trigger'] as Map<String, dynamic>?;
      if (trigger == null) continue;

      int giftedQuantity = 0;
      if (trigger['type'] == "min_order") {
        final requiredValue = (trigger['value'] as num? ?? 0.0).toDouble();
        if (sellerData.total >= requiredValue) {
          giftedQuantity = promo['giftQuantityPerBase'] as int? ?? 1;
        }
      }
      else if (trigger['type'] == "specific_item") {
        final triggerOfferId = trigger['offerId'] as String?;
        final requiredQtyBase = trigger['triggerQuantityBase'] as int? ?? 1;
        final giftPerBase = promo['giftQuantityPerBase'] as int? ?? 1;
        final triggerUnitName = trigger['unitName'] as String?;

        final itemMatch = sellerData.items.firstWhere(
            (item) => item.offerId == triggerOfferId && item.unit == triggerUnitName,
            orElse: () => CartItem(offerId: '', productId: '', sellerId: '', sellerName: '', name: '', price: 0, unit: '', unitIndex: -1, quantity: 0, imageUrl: '')
        );
        if (itemMatch.offerId.isNotEmpty) {
          final timesTriggered = (itemMatch.quantity / requiredQtyBase).floor();
          final totalGiftedQty = timesTriggered * giftPerBase;
          final maxAllowedGifts = promo['maxQuantity'] as int? ?? 9999;
          giftedQuantity = min(totalGiftedQty, maxAllowedGifts);
        }
      }

      if (giftedQuantity > 0) {
        final giftOfferId = promo['giftOfferId'] as String? ?? 'N/A';
        final giftProductId = promo['giftProductId'] as String? ?? giftOfferId;

        giftedItems.add(CartItem(
          isGift: true,
          name: promo['giftProductName'] as String? ?? 'هدية',
          quantity: giftedQuantity,
          unit: promo['giftUnitName'] as String? ?? 'وحدة',
          price: 0.00,
          offerId: giftOfferId,
          productId: giftProductId,
          sellerId: sellerData.sellerId,
          sellerName: sellerData.sellerName,
          unitIndex: -1,
          imageUrl: promo['giftProductImage'] as String? ?? '',
        ));
      }
    }
    return giftedItems;
  }

  // ------------------------------------------
  // دالة جلب تفاصيل العرض (تستخدم لتحديث الأسعار والتحقق من القيود)
  // ------------------------------------------
  Future<Map<String, dynamic>> _getProductOfferDetails(String offerId, int unitIndex) async {
    int productMinQty = 1;
    int productMaxQty = 9999;
    int actualAvailableStock = 9999;
    double currentPrice = 0.0;
    final collectionName = 'productOffers';

    try {
      // 1. محاولة جلب البيانات من مجموعة productOffers (البائع)
      final offerRef = _db.collection(collectionName).doc(offerId);
      final offerDoc = await offerRef.get();

      if (offerDoc.exists) {
        final data = offerDoc.data()!;

        // منطق البائع (B2B)
        productMinQty = (data['minOrder'] as num?)?.toInt() ?? 1;
        productMaxQty = (data['maxOrder'] as num?)?.toInt() ?? 9999;

        if (unitIndex != -1 && data['units'] is List && unitIndex < (data['units'] as List).length) {
          final unitData = data['units'][unitIndex] as Map<String, dynamic>?;
          if (unitData != null) {
            actualAvailableStock = (unitData['availableStock'] as num?)?.toInt() ?? 0;
            currentPrice = (unitData['price'] as num?)?.toDouble() ?? 0.0;
          }
        } else if (data['availableQuantity'] != null) {
          actualAvailableStock = (data['availableQuantity'] as num?)?.toInt() ?? 0;
          currentPrice = (data['price'] as num?)?.toDouble() ?? 0.0;
        }

        // 2. محاولة جلب البيانات من مجموعة marketOffer (المستهلك)
      } else {
        final marketOfferDoc = await _db.collection('marketOffer').doc(offerId).get();

        if (marketOfferDoc.exists) {
          final data = marketOfferDoc.data()!;
          // منطق المستهلك (Consumer) - قيود الطلب عادةً مرنة ما لم يُحدد مخزون
          productMinQty = 1;
          productMaxQty = 9999;
          actualAvailableStock = 9999; // الافتراضي هو مخزون غير محدود إذا لم يتم التحديد

          // 🟢 [تصحيح السعر]: جلب السعر من مصفوفة units باستخدام unitIndex
          final units = data['units'] as List<dynamic>?;
          if (units != null && unitIndex >= 0 && unitIndex < units.length) {
            final unitData = units[unitIndex] as Map<String, dynamic>?;
            currentPrice = (unitData?['price'] as num?)?.toDouble() ?? 0.0;
          }
        } else {
          actualAvailableStock = 0; // المنتج غير موجود
        }
      }
    } catch (error) {
      print('Firestore Error fetching product offer details: $error');
      actualAvailableStock = 0;
    }

    return {
      'minQty': productMinQty,
      'maxQty': productMaxQty,
      'stock': actualAvailableStock,
      'currentPrice': currentPrice,
    };
  }

  // ------------------------------------------
  // 2. دوال الحفظ والتحميل (تبقى كما هي)
  // ------------------------------------------
  Future<void> _saveCartToLocal(Map<String, SellerOrderData> currentOrders) async {
    final List<CartItem> itemsToSave = [];
    // حفظ العناصر الأصلية
    itemsToSave.addAll(_cartItems.where((item) => !item.isGift));

    // إضافة الهدايا المحسوبة حديثاً إلى قائمة الحفظ
    if (currentOrders.isNotEmpty) {
      for(var order in currentOrders.values) {
        itemsToSave.addAll(order.giftedItems);
      }
    }
    final prefs = await SharedPreferences.getInstance();
    final cartJson = jsonEncode(itemsToSave.map((e) => e.toJson()).toList());
    await prefs.setString('cartItems', cartJson);
  }

  // ------------------------------------------
  // دالة المحرك الرئيسي (loadCartAndRecalculate)
  // ------------------------------------------
  Future<void> loadCartAndRecalculate(String userRole) async {
    final prefs = await SharedPreferences.getInstance();
    final cartJson = prefs.getString('cartItems');

    if (cartJson != null) {
      final List<dynamic> rawList = jsonDecode(cartJson);
      _cartItems = rawList.map((e) => CartItem.fromJson(e as Map<String, dynamic>))
          .toList();
    } else {
      _cartItems = [];
    }

    if (_cartItems.isEmpty) {
      _sellersOrders = {};
      _totalProductsAmount = 0.0;
      _totalDeliveryFees = 0.0;
      _hasCheckoutErrors = false;
      notifyListeners();
      return;
    }

    // 2. تجميع الطلبات الأصلية
    final tempSellersOrders = <String, SellerOrderData>{};
    for (var item in _cartItems.where((item) => !item.isGift)) { // نركز على العناصر غير الهدية
      final sellerId = item.sellerId;
      if (!tempSellersOrders.containsKey(sellerId)) {
        tempSellersOrders[sellerId] = SellerOrderData(
          sellerId: sellerId,
          sellerName: item.sellerName,
          items: [],
        );
      }
      tempSellersOrders[sellerId]!.items.add(item);
    }

    // 3. جلب القواعد والحد الأدنى
    _totalProductsAmount = 0.0;
    _totalDeliveryFees = 0.0;
    _hasCheckoutErrors = false;

    for (var sellerId in tempSellersOrders.keys) {
      final sellerData = tempSellersOrders[sellerId]!;

      print('DEBUG RECALC: Processing seller ${sellerData.sellerName} (ID: $sellerId)');

      // جلب القواعد بناءً على الدور
      final rules = await _getSellerBusinessRules(sellerId, userRole);
      sellerData.minOrderTotal = (rules['minTotal'] as num? ?? 0.0).toDouble();
      sellerData.deliveryFee = (rules['deliveryFee'] as num? ?? 0.0).toDouble();
      print('DEBUG RECALC: Seller Min Order Total is ${sellerData.minOrderTotal} for ${sellerData.sellerName}');

      // 4. التحقق من قيود المخزون والحدود وتحديث الأسعار
      sellerData.total = 0.0;
      sellerData.hasProductErrors = false; // إعادة ضبط الخطأ الخاص بالمنتجات

      for (var item in sellerData.items) {
        final details = await _getProductOfferDetails(item.offerId, item.unitIndex);

        // تحديث السعر
        final newPrice = details['currentPrice'] as double;
        if (newPrice > 0.0) {
          item.price = newPrice;
        } else {
          sellerData.hasProductErrors = true;
          _hasCheckoutErrors = true;
        }

        sellerData.total += (item.price * item.quantity);

        // التحقق من الحد الأدنى/الأقصى والمخزون
        final finalMax = min((details['stock'] as int), (details['maxQty'] as int));
        final finalMin = details['minQty'] as int;

        if (item.quantity > finalMax || item.quantity < finalMin) {
          sellerData.hasProductErrors = true;
          _hasCheckoutErrors = true;
          print('ERROR: Product ${item.name} quantity (${item.quantity}) outside limits (Min: $finalMin, Max: $finalMax)');
        }
      }

      // 5. إعادة تقييم الحد الأدنى والهدايا (بعد تحديث الأسعار)
      if (sellerData.minOrderTotal > 0 && sellerData.total < sellerData.minOrderTotal) {
        final remaining = (sellerData.minOrderTotal - sellerData.total).toStringAsFixed(2);
        sellerData.isMinOrderMet = false;
        // إزالة رسوم التوصيل في حال عدم تحقيق الحد الأدنى
        sellerData.deliveryFee = 0.0;
        sellerData.minOrderAlert = 'ينقصك $remaining جنيه لإتمام طلبك من ${sellerData.sellerName}.';
      } else {
        sellerData.isMinOrderMet = true;
        sellerData.minOrderAlert = 'تم تجاوز الحد الأدنى للطلب من ${sellerData.sellerName}.';
        _totalDeliveryFees += sellerData.deliveryFee;

        // حساب الهدايا المستحقة
        final promos = await _getGiftPromosBySellerId(sellerId);
        sellerData.giftedItems = _calculateGifts(sellerData, promos);
      }

      // تجميع الإجمالي الكلي للمنتجات
      _totalProductsAmount += sellerData.total;
    }

    _sellersOrders = tempSellersOrders;
    // 6. حفظ السلة النهائية (بما في ذلك الهدايا المستحقة)
    await _saveCartToLocal(tempSellersOrders);

    notifyListeners();
  }

  // ------------------------------------------
  // 4. دوال التحكم في السلة والتفاعل
  // ------------------------------------------
  // 🟢 [الدالة المصححة لإضافة وسيطة الدور (userRole)]
  // 🛑 تم تغيير توقيع الدالة ليتوافق مع buyer_product_card
  Future<void> addItemToCart({
    required String offerId,
    required String productId,
    required String sellerId,
    required String sellerName,
    required String name,
    required double price,
    required String unit,
    required int unitIndex,
    int quantityToAdd = 1,
    required String imageUrl,
    // 🛑 [الوسيطة المضافة]: لا يمكن تركها اختيارية بعد تعديل توقيع الدالة في buyer_product_card
    required String userRole,
    // قيود الكمية (اختيارية بقيم افتراضية مرنة)
    int minOrderQuantity = 1,
    int availableStock = 9999,
    int maxOrderQuantity = 9999,
  }) async {
    print('DEBUG ADD: Adding item $name. Seller Name provided: $sellerName (ID: $sellerId). Quantity: $quantityToAdd. Role: $userRole');

    // 🛑 [منطق التحقق من الاسم الحالي - خاص بالـ consumer]
    // **ملاحظة: هذا المنطق سيؤدي إلى خطأ في مسار buyer (المشتري) كما ناقشنا**
    String verifiedSellerName = sellerName;
    if (userRole == 'consumer') {
      try {
        verifiedSellerName = await _dataService.fetchSupermarketNameById(sellerId);
        print('DEBUG ADD: Verified Name SUCCESS: $verifiedSellerName');
      } catch (e) {
        throw 'ERROR: Failed to fetch verified seller name for $sellerId. Error: $e';
      }
    } else {
      // نعتمد على الاسم المرسل من الواجهة في حالة buyer
      verifiedSellerName = sellerName;
    }

    // ==========================================================
    // 🛑 [منطق التحقق من الكمية]
    // ==========================================================
    final int finalMaxQuantity = min(availableStock, maxOrderQuantity);

    if (quantityToAdd < minOrderQuantity) {
      throw Exception('لا يمكن إضافة أقل من الحد الأدنى للطلب لهذا الصنف: $minOrderQuantity $unit');
    }

    final index = _cartItems.indexWhere(
          (item) => item.offerId == offerId && item.unitIndex == unitIndex,
    );

    int existingQuantity = 0;
    if (index != -1) {
      existingQuantity = _cartItems[index].quantity;
    }

    final newTotalQuantity = existingQuantity + quantityToAdd;

    if (newTotalQuantity > finalMaxQuantity) {
      throw Exception('لا يمكن إضافة ${quantityToAdd} $unit. الكمية المطلوبة ستتجاوز الحد المتاح ($finalMaxQuantity $unit).');
    }

    // ==========================================================

    _cartItems.removeWhere((item) => item.isGift); // إزالة الهدايا القديمة

    if (index != -1) {
      _cartItems[index].quantity = newTotalQuantity;
    } else {
      final newItem = CartItem(
        offerId: offerId,
        productId: productId,
        sellerId: sellerId,
        sellerName: verifiedSellerName,
        name: name,
        price: price,
        unit: unit,
        unitIndex: unitIndex,
        quantity: quantityToAdd,
        isGift: false,
        imageUrl: imageUrl,
      );
      _cartItems.add(newItem);
    }

    await _saveCartToLocal(_sellersOrders);
    // 🛑 تمرير الدور الفعلي للمستخدم
    await loadCartAndRecalculate(userRole);
  }

  // 💡 تغيير الكمية وإعادة الحساب
  // 🛑 تم إضافة وسيطة الدور
  Future<void> changeQty(CartItem item, int delta, String userRole) async {
    final index = _cartItems.indexWhere((i) => i.offerId == item.offerId && !i.isGift);
    if (index == -1) return;

    final newQty = _cartItems[index].quantity + delta;

    if (newQty <= 0) {
      // 🛑 تمرير الدور عند حذف المنتج
      await removeItem(_cartItems[index], userRole);
      return;
    }

    // التحقق من الحد الأقصى والمخزون عند التعديل
    final details = await _getProductOfferDetails(item.offerId, item.unitIndex);
    final finalMax = min((details['stock'] as int), (details['maxQty'] as int));

    if (finalMax < 9999 && newQty > finalMax) {
      print('ALERT: الحد الأقصى المتاح للطلب هو $finalMax وحدة.');
      return;
    }

    _cartItems[index].quantity = newQty;
    await _saveCartToLocal(_sellersOrders);
    // 🛑 تمرير الدور
    await loadCartAndRecalculate(userRole);
  }

  // 💡 حذف عنصر وإعادة الحساب
  // 🛑 تم إضافة وسيطة الدور
  Future<void> removeItem(CartItem itemToRemove, String userRole) async {
    _cartItems.removeWhere((i) => i.offerId == itemToRemove.offerId && !i.isGift);

    await _saveCartToLocal(_sellersOrders);
    // 🛑 تمرير الدور
    await loadCartAndRecalculate(userRole);
  }

  // 💡 إفراغ السلة
  Future<void> clearCart() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('cartItems');

    _cartItems = [];
    _sellersOrders = {};
    _totalProductsAmount = 0.0;
    _totalDeliveryFees = 0.0;
    _hasCheckoutErrors = false;

    notifyListeners();
  }

  // 💡 منطق إتمام الطلب (Checkout)
  // 🟢 [التعديل الرئيسي]: إضافة async
  Future<void> proceedToCheckout(BuildContext context, String userRole) async {
    await loadCartAndRecalculate(userRole); // إعادة حساب أخيرة قبل المتابعة

    if (_hasCheckoutErrors) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى تصحيح أخطاء الكمية والمخزون قبل إتمام الطلب.')),
      );
      return;
    }

    final ordersToProceed = <CartItem>[];
    final itemsToKeep = <CartItem>[];
    bool allOrdersValidForCheckout = true;
    final ordersToAlert = <Map<String, dynamic>>[];

    for (final sellerData in _sellersOrders.values) {
      if (sellerData.minOrderTotal > 0 && !sellerData.isMinOrderMet) {
        allOrdersValidForCheckout = false;
        ordersToAlert.add({
          'sellerName': sellerData.sellerName,
          'currentTotal': sellerData.total,
          'minTotal': sellerData.minOrderTotal,
        });
        // إبقاء العناصر غير المؤهلة في السلة
        itemsToKeep.addAll(sellerData.items);
      } else {
        // إضافة رسوم التوصيل كمنتج وهمي
        if (sellerData.deliveryFee > 0) {
          ordersToProceed.add(CartItem(
            offerId: 'DELIVERY_FEE_${sellerData.sellerId}',
            productId: 'DELIVERY_FEE',
            sellerId: sellerData.sellerId,
            sellerName: sellerData.sellerName,
            name: "رسوم التوصيل",
            price: sellerData.deliveryFee,
            unit: 'شحنة',
            unitIndex: -1,
            quantity: 1,
            isGift: false,
            imageUrl: '',
          ));
        }
        // إضافة المنتجات الأصلية والهدايا المؤهلة
        ordersToProceed.addAll(sellerData.items);
        ordersToProceed.addAll(sellerData.giftedItems);
      }
    }

    if (!allOrdersValidForCheckout) {
      String alertMessage = "تنبيه: سيتم إتمام الطلبات التي تحقق الحد الأدنى فقط.\nالطلبات غير المؤهلة:\n";

      for (var order in ordersToAlert) {
        alertMessage += "  - التاجر \"${order['sellerName']}\": الإجمالي ${order['currentTotal'].toStringAsFixed(2)} جنيه (الحد الأدنى: ${order['minTotal'].toStringAsFixed(2)} جنيه)\n";
      }

      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('تنبيه بخصوص الطلب'),
          content: Text(alertMessage),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('متابعة')),
          ],
        )
      );
    }

    if (ordersToProceed.isNotEmpty) {
      final prefs = await SharedPreferences.getInstance();

      // حفظ العناصر التي لم تحقق الحد الأدنى مرة أخرى في السلة
      final remainingCartJson = jsonEncode(itemsToKeep.map((e) => e.toJson()).toList());
      await prefs.setString('cartItems', remainingCartJson);

      // حفظ العناصر المؤهلة في قائمة إتمام الطلب
      final checkoutOrdersJson = jsonEncode(ordersToProceed.map((e) => e.toJson()).toList());
      await prefs.setString('checkoutOrders', checkoutOrdersJson);

      // تحديث السلة المحلية
      await loadCartAndRecalculate(userRole);
      // توجيه المستخدم لصفحة إتمام الطلب (Checkout)
      // ملاحظة: يجب تعديل هذا الجزء ليناسب نظام التوجيه الخاص بتطبيقك (Navigator/GoRouter)
      Navigator.of(context).pushNamed('/checkout');
    } else if (!allOrdersValidForCheckout) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا يمكن إتمام أي طلب. جميع الطلبات أقل من الحد الأدنى المطلوب.')),
      );
    }
  }

  // 🟢🟢 دالة جديدة: إلغاء وحذف طلب الدفع المعلق 🟢 🟢
  Future<void> cancelPendingCheckout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('checkoutOrders');
    notifyListeners();
  }
}
