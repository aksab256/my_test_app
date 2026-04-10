// المسار: lib/providers/cart_provider.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';
import 'package:my_test_app/services/marketplace_data_service.dart';

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
  final String? mainId;
  final String? subId;

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
    this.mainId,
    this.subId,
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
    'mainId': mainId,
    'subId': subId,
  };

  factory CartItem.fromJson(Map<String, dynamic> json) {
    return CartItem(
      offerId: json['offerId']?.toString() ?? '',
      productId: json['productId']?.toString() ?? json['offerId']?.toString() ?? '',
      sellerId: json['sellerId']?.toString() ?? '',
      sellerName: json['sellerName']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      unit: json['unit']?.toString() ?? '',
      unitIndex: (json['unitIndex'] as num?)?.toInt() ?? -1,
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      isGift: json['isGift'] as bool? ?? false,
      imageUrl: json['imageUrl']?.toString() ?? '',
      mainId: json['mainId']?.toString(),
      subId: json['subId']?.toString(),
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
  final MarketplaceDataService _dataService = MarketplaceDataService();

  List<CartItem> _cartItems = [];
  Map<String, SellerOrderData> _sellersOrders = {};

  final Map<String, Map<String, dynamic>> _sellerRulesCache = {};
  final Map<String, List<Map<String, dynamic>>> _giftPromosCache = {};

  double _totalProductsAmount = 0.0;
  double _totalDeliveryFees = 0.0;
  bool _hasCheckoutErrors = false;

  Map<String, SellerOrderData> get sellersOrders => _sellersOrders;
  double get totalProductsAmount => _totalProductsAmount;
  double get totalDeliveryFees => _totalDeliveryFees;
  double get finalTotal => _totalProductsAmount + _totalDeliveryFees;
  bool get hasCheckoutErrors => _hasCheckoutErrors;
  int get cartTotalItems => _cartItems.where((item) => !item.isGift).length;
  int get itemCount => cartTotalItems;
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

  Future<Map<String, dynamic>> _getSellerBusinessRules(String sellerId, String buyerRole) async {
    if (_sellerRulesCache.containsKey(sellerId)) return _sellerRulesCache[sellerId]!;
    double finalMinTotal = 0.0;
    double finalDeliveryFee = 0.0;

    try {
      final docSnap = await _db.collection('sellers').doc(sellerId).get();
      if (docSnap.exists) {
        final data = docSnap.data()!;
        finalMinTotal = (data['minOrderTotal'] as num?)?.toDouble() ?? 0.0;
        finalDeliveryFee = (data['deliveryFee'] as num?)?.toDouble() ?? 0.0;
        if (buyerRole == 'buyer') {
          final rules = { 'minTotal': finalMinTotal, 'deliveryFee': finalDeliveryFee };
          _sellerRulesCache[sellerId] = rules;
          return rules;
        }
      }
    } catch (e) {
      print('Firestore Error fetching from sellers: $e');
    }

    if (buyerRole == 'consumer' && finalMinTotal == 0.0 && finalDeliveryFee == 0.0) {
      try {
        final docSnap = await _db.collection('deliverySupermarkets').doc(sellerId).get();
        if (docSnap.exists) {
          final data = docSnap.data()!;
          finalMinTotal = (data['minimumOrderValue'] as num?)?.toDouble() ?? 0.0;
          finalDeliveryFee = (data['deliveryFee'] as num?)?.toDouble() ?? 0.0;
        }
      } catch (e) {
        print('Firestore Error fetching from deliverySupermarkets: $e');
      }
    }

    final rules = {'minTotal': finalMinTotal, 'deliveryFee': finalDeliveryFee, 'buyerRole': buyerRole};
    _sellerRulesCache[sellerId] = rules;
    return rules;
  }

  Future<List<Map<String, dynamic>>> _getGiftPromosBySellerId(String sellerId) async {
    if (_giftPromosCache.containsKey(sellerId)) return _giftPromosCache[sellerId]!;
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

  List<CartItem> _calculateGifts(SellerOrderData sellerData, List<Map<String, dynamic>> promos) {
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
      } else if (trigger['type'] == "specific_item") {
        final triggerOfferId = trigger['offerId'] as String?;
        final requiredQtyBase = trigger['triggerQuantityBase'] as int? ?? 1;
        final giftPerBase = promo['giftQuantityPerBase'] as int? ?? 1;
        final triggerUnitName = trigger['unitName'] as String?;

        final itemMatch = sellerData.items.firstWhere(
            (item) => item.offerId == triggerOfferId && item.unit == triggerUnitName,
            orElse: () => CartItem(offerId: '', productId: '', sellerId: '', sellerName: '', name: '', price: 0, unit: '', unitIndex: -1, quantity: 0, imageUrl: ''));
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

  // 🚀 تحسين: جلب التفاصيل بذكاء حسب نوع المستخدم لتقليل الـ Try/Catch
  Future<Map<String, dynamic>> _getProductOfferDetails(String offerId, int unitIndex, {String userRole = 'buyer'}) async {
    int productMinQty = 1;
    int productMaxQty = 9999;
    int actualAvailableStock = 9999;
    double currentPrice = 0.0;

    try {
      // إذا كان مستهلك، ابحث مباشرة في marketOffer أولاً (أسرع)
      if (userRole == 'consumer') {
        final marketOfferDoc = await _db.collection('marketOffer').doc(offerId).get();
        if (marketOfferDoc.exists) {
          final data = marketOfferDoc.data()!;
          final units = data['units'] as List<dynamic>?;
          if (units != null && unitIndex >= 0 && unitIndex < units.length) {
            final unitData = units[unitIndex] as Map<String, dynamic>?;
            currentPrice = (unitData?['price'] as num?)?.toDouble() ?? 0.0;
          }
          return {'minQty': 1, 'maxQty': 9999, 'stock': 9999, 'currentPrice': currentPrice};
        }
      }

      // المسار الافتراضي (للبايير أو إذا لم يجد في ماركت أوفير)
      final offerDoc = await _db.collection('productOffers').doc(offerId).get();
      if (offerDoc.exists) {
        final data = offerDoc.data()!;
        productMinQty = (data['minOrder'] as num?)?.toInt() ?? 1;
        productMaxQty = (data['maxOrder'] as num?)?.toInt() ?? 9999;
        if (unitIndex != -1 && data['units'] is List && unitIndex < (data['units'] as List).length) {
          final unitData = data['units'][unitIndex] as Map<String, dynamic>?;
          if (unitData != null) {
            actualAvailableStock = (unitData['availableStock'] as num?)?.toInt() ?? 0;
            currentPrice = (unitData['price'] as num?)?.toDouble() ?? 0.0;
          }
        }
      }
    } catch (error) {
      actualAvailableStock = 0;
    }

    return {'minQty': productMinQty, 'maxQty': productMaxQty, 'stock': actualAvailableStock, 'currentPrice': currentPrice};
  }

  Future<void> _saveCartToLocal(Map<String, SellerOrderData> currentOrders) async {
    final List<CartItem> itemsToSave = [];
    itemsToSave.addAll(_cartItems.where((item) => !item.isGift));
    if (currentOrders.isNotEmpty) {
      for (var order in currentOrders.values) {
        itemsToSave.addAll(order.giftedItems);
      }
    }
    final prefs = await SharedPreferences.getInstance();
    final cartJson = jsonEncode(itemsToSave.map((e) => e.toJson()).toList());
    await prefs.setString('cartItems', cartJson);
  }

  Future<void> loadCartAndRecalculate(String userRole) async {
    final prefs = await SharedPreferences.getInstance();
    final cartJson = prefs.getString('cartItems');
    if (cartJson != null) {
      final List<dynamic> rawList = jsonDecode(cartJson);
      _cartItems = rawList.map((e) => CartItem.fromJson(e as Map<String, dynamic>)).toList();
    }
    if (_cartItems.isEmpty) {
      _sellersOrders = {};
      _totalProductsAmount = 0.0;
      _totalDeliveryFees = 0.0;
      _hasCheckoutErrors = false;
      notifyListeners();
      return;
    }

    final tempSellersOrders = <String, SellerOrderData>{};
    for (var item in _cartItems.where((item) => !item.isGift)) {
      final sellerId = item.sellerId;
      if (!tempSellersOrders.containsKey(sellerId)) {
        tempSellersOrders[sellerId] = SellerOrderData(sellerId: sellerId, sellerName: item.sellerName, items: []);
      }
      tempSellersOrders[sellerId]!.items.add(item);
    }

    _totalProductsAmount = 0.0;
    _totalDeliveryFees = 0.0;
    _hasCheckoutErrors = false;

    for (var sellerId in tempSellersOrders.keys) {
      final sellerData = tempSellersOrders[sellerId]!;
      final rules = await _getSellerBusinessRules(sellerId, userRole);
      sellerData.minOrderTotal = (rules['minTotal'] as num? ?? 0.0).toDouble();
      sellerData.deliveryFee = (rules['deliveryFee'] as num? ?? 0.0).toDouble();
      sellerData.total = 0.0;

      for (var item in sellerData.items) {
        final details = await _getProductOfferDetails(item.offerId, item.unitIndex, userRole: userRole);
        if (details['currentPrice'] > 0.0) item.price = details['currentPrice'];
        sellerData.total += (item.price * item.quantity);
      }

      if (sellerData.minOrderTotal > 0 && sellerData.total < sellerData.minOrderTotal) {
        sellerData.isMinOrderMet = false;
        sellerData.deliveryFee = 0.0;
      } else {
        sellerData.isMinOrderMet = true;
        _totalDeliveryFees += sellerData.deliveryFee;
        final promos = await _getGiftPromosBySellerId(sellerId);
        sellerData.giftedItems = _calculateGifts(sellerData, promos);
      }
      _totalProductsAmount += sellerData.total;
    }
    _sellersOrders = tempSellersOrders;
    await _saveCartToLocal(tempSellersOrders);
    notifyListeners();
  }

  // 🚀 تحسين: إضافة لحظية وتجاوز خبطة الاسم للمستهلك
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
    required String userRole,
    String? mainId,
    String? subId,
    int minOrderQuantity = 1,
    int availableStock = 9999,
    int maxOrderQuantity = 9999,
  }) async {
    // تحديث فوري للـ UI قبل أي عمليات Firestore 🎯
    final int finalMaxQuantity = min(availableStock, maxOrderQuantity);
    final index = _cartItems.indexWhere((item) => item.offerId == offerId && item.unitIndex == unitIndex);
    int existingQuantity = (index != -1) ? _cartItems[index].quantity : 0;
    final newTotalQuantity = existingQuantity + quantityToAdd;

    if (quantityToAdd < minOrderQuantity) throw Exception('أقل من الحد الأدنى');
    if (newTotalQuantity > finalMaxQuantity) throw Exception('تجاوز الحد المتاح');

    _cartItems.removeWhere((item) => item.isGift);

    if (index != -1) {
      _cartItems[index].quantity = newTotalQuantity;
    } else {
      _cartItems.add(CartItem(
        offerId: offerId,
        productId: productId,
        sellerId: sellerId,
        sellerName: sellerName, // نستخدم الاسم الممرر فوراً 🚀
        name: name,
        price: price,
        unit: unit,
        unitIndex: unitIndex,
        quantity: quantityToAdd,
        imageUrl: imageUrl,
        mainId: mainId,
        subId: subId,
      ));
    }

    notifyListeners(); // إشعار لحظي للواجهة ⚡

    // تنفيذ الحسابات وحفظ البيانات في الخلفية
    _saveCartToLocal(_sellersOrders);
    loadCartAndRecalculate(userRole);
  }

  Future<void> changeQty(CartItem item, int delta, String userRole) async {
    final index = _cartItems.indexWhere((i) => i.offerId == item.offerId && !i.isGift);
    if (index == -1) return;

    final newQty = _cartItems[index].quantity + delta;
    if (newQty <= 0) {
      await removeItem(_cartItems[index], userRole);
      return;
    }

    _cartItems[index].quantity = newQty;
    notifyListeners(); // تحديث فوري ⚡

    await _saveCartToLocal(_sellersOrders);
    loadCartAndRecalculate(userRole);
  }

  Future<void> removeItem(CartItem itemToRemove, String userRole) async {
    _cartItems.removeWhere((i) => i.offerId == itemToRemove.offerId && !i.isGift);
    notifyListeners();
    await _saveCartToLocal(_sellersOrders);
    loadCartAndRecalculate(userRole);
  }

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

  Future<void> proceedToCheckout(BuildContext context, String userRole) async {
    await loadCartAndRecalculate(userRole);
    if (_hasCheckoutErrors) return;

    final ordersToProceed = <CartItem>[];
    final itemsToKeep = <CartItem>[];

    for (final sellerData in _sellersOrders.values) {
      if (sellerData.minOrderTotal > 0 && !sellerData.isMinOrderMet) {
        itemsToKeep.addAll(sellerData.items);
      } else {
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
        ordersToProceed.addAll(sellerData.items);
        ordersToProceed.addAll(sellerData.giftedItems);
      }
    }

    if (ordersToProceed.isNotEmpty) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cartItems', jsonEncode(itemsToKeep.map((e) => e.toJson()).toList()));
      await prefs.setString('checkoutOrders', jsonEncode(ordersToProceed.map((e) => e.toJson()).toList()));
      await loadCartAndRecalculate(userRole);
      Navigator.of(context).pushNamed('/checkout');
    }
  }

  Future<void> cancelPendingCheckout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('checkoutOrders');
    notifyListeners();
  }
}

