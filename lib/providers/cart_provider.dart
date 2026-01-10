// lib/providers/cart_provider.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';
import '../services/marketplace_data_service.dart';

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
      productId: json['productId']?.toString() ?? '',
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

  SellerOrderData({
    required this.sellerId,
    required this.sellerName,
    required this.items,
  });
}

class CartProvider with ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final MarketplaceDataService _dataService = MarketplaceDataService();

  List<CartItem> _cartItems = [];
  Map<String, SellerOrderData> _sellersOrders = {};
  double _totalProductsAmount = 0.0;
  double _totalDeliveryFees = 0.0;
  bool _hasCheckoutErrors = false;

  Map<String, SellerOrderData> get sellersOrders => _sellersOrders;
  double get totalProductsAmount => _totalProductsAmount;
  double get totalDeliveryFees => _totalDeliveryFees;
  double get finalTotal => _totalProductsAmount + _totalDeliveryFees;
  bool get hasCheckoutErrors => _hasCheckoutErrors;
  int get itemCount => _cartItems.where((item) => !item.isGift).length;
  bool get isCartEmpty => _cartItems.isEmpty;

  Future<void> loadCartAndRecalculate(String userRole) async {
    final prefs = await SharedPreferences.getInstance();
    final cartJson = prefs.getString('cartItems');

    if (cartJson != null) {
      try {
        final List<dynamic> rawList = jsonDecode(cartJson);
        _cartItems = rawList.map((e) => CartItem.fromJson(e)).toList();
      } catch (_) { _cartItems = []; }
    } else {
      _cartItems = [];
    }

    if (_cartItems.isEmpty) {
      _resetTotals();
      notifyListeners();
      return;
    }

    final tempSellersOrders = <String, SellerOrderData>{};
    for (var item in _cartItems.where((item) => !item.isGift)) {
      tempSellersOrders.putIfAbsent(item.sellerId, () => SellerOrderData(
        sellerId: item.sellerId,
        sellerName: item.sellerName,
        items: [],
      )).items.add(item);
    }

    _totalProductsAmount = 0.0;
    _totalDeliveryFees = 0.0;
    _hasCheckoutErrors = false;

    for (var sellerId in tempSellersOrders.keys) {
      final sellerData = tempSellersOrders[sellerId]!;
      final rules = await _getSellerBusinessRules(sellerId, userRole);
      
      sellerData.minOrderTotal = rules['minTotal'];
      sellerData.deliveryFee = rules['deliveryFee'];
      sellerData.total = 0.0;

      for (var item in sellerData.items) {
        final details = await _getProductOfferDetails(item.offerId, item.unitIndex);
        item.price = details['currentPrice'];
        sellerData.total += (item.price * item.quantity);

        if (item.quantity > details['maxQty'] || item.quantity < details['minQty'] || details['stock'] < item.quantity) {
          sellerData.hasProductErrors = true;
          _hasCheckoutErrors = true;
        }
      }

      if (sellerData.total < sellerData.minOrderTotal) {
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
    await _saveCartToLocal();
    notifyListeners();
  }

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
    String verifiedName = sellerName;
    if (userRole == 'consumer') {
      verifiedName = await _dataService.fetchSupermarketNameById(sellerId);
    }

    final int finalMax = min(availableStock, maxOrderQuantity);
    final index = _cartItems.indexWhere((item) => item.offerId == offerId && item.unitIndex == unitIndex);

    int totalNewQty = ((index != -1) ? _cartItems[index].quantity : 0) + quantityToAdd;

    if (totalNewQty > finalMax) throw 'تجاوز الحد المتاح';
    if (totalNewQty < minOrderQuantity) throw 'أقل من الحد الأدنى';

    _cartItems.removeWhere((item) => item.isGift);

    if (index != -1) {
      _cartItems[index].quantity = totalNewQty;
    } else {
      _cartItems.add(CartItem(
        offerId: offerId, productId: productId, sellerId: sellerId,
        sellerName: verifiedName, name: name, price: price,
        unit: unit, unitIndex: unitIndex, quantity: quantityToAdd,
        imageUrl: imageUrl, mainId: mainId, subId: subId,
      ));
    }
    await loadCartAndRecalculate(userRole);
  }

  Future<Map<String, dynamic>> _getSellerBusinessRules(String sellerId, String role) async {
    final col = (role == 'buyer') ? 'sellers' : 'deliverySupermarkets';
    final doc = await _db.collection(col).doc(sellerId).get();
    if (doc.exists) {
      final d = doc.data()!;
      return {
        'minTotal': (d['minOrderTotal'] ?? d['minimumOrderValue'] ?? 0.0).toDouble(),
        'deliveryFee': (d['deliveryFee'] ?? 0.0).toDouble(),
      };
    }
    return {'minTotal': 0.0, 'deliveryFee': 0.0};
  }

  Future<Map<String, dynamic>> _getProductOfferDetails(String id, int idx) async {
    final doc = await _db.collection('productOffers').doc(id).get();
    if (!doc.exists) return {'minQty': 1, 'maxQty': 9999, 'stock': 9999, 'currentPrice': 0.0};
    final d = doc.data()!;
    double price = 0.0;
    int stock = 0;
    if (idx != -1 && d['units'] != null) {
      final u = d['units'][idx];
      price = (u['price'] as num).toDouble();
      stock = (u['availableStock'] as num).toInt();
    } else {
      price = (d['price'] as num).toDouble();
      stock = (d['availableQuantity'] as num).toInt();
    }
    return {
      'minQty': (d['minOrder'] as num? ?? 1).toInt(),
      'maxQty': (d['maxOrder'] as num? ?? 9999).toInt(),
      'stock': stock,
      'currentPrice': price,
    };
  }

  List<CartItem> _calculateGifts(SellerOrderData seller, List<Map<String, dynamic>> promos) {
    final gifts = <CartItem>[];
    for (var promo in promos) {
      final trigger = promo['trigger'] as Map<String, dynamic>?;
      if (trigger == null) continue;
      int qty = 0;
      if (trigger['type'] == "min_order" && seller.total >= (trigger['value'] ?? 0)) {
        qty = promo['giftQuantityPerBase'] ?? 1;
      } else if (trigger['type'] == "specific_item") {
        final match = seller.items.firstWhere((i) => i.offerId == trigger['offerId'], orElse: () => seller.items.first);
        if (match.offerId == trigger['offerId']) {
          qty = (match.quantity ~/ (trigger['triggerQuantityBase'] ?? 1)) * (promo['giftQuantityPerBase'] as int? ?? 1);
        }
      }
      if (qty > 0) {
        gifts.add(CartItem(
          offerId: promo['giftOfferId'], productId: promo['giftProductId'],
          sellerId: seller.sellerId, sellerName: seller.sellerName,
          name: promo['giftProductName'], price: 0.0, unit: promo['giftUnitName'],
          unitIndex: -1, quantity: qty, isGift: true, imageUrl: promo['giftProductImage'],
        ));
      }
    }
    return gifts;
  }

  Future<List<Map<String, dynamic>>> _getGiftPromosBySellerId(String id) async {
    final snap = await _db.collection('giftPromos').where('sellerId', isEqualTo: id).where('status', isEqualTo: 'active').get();
    return snap.docs.map((d) => d.data()).toList();
  }

  Future<void> _saveCartToLocal() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('cartItems', jsonEncode(_cartItems.where((i) => !i.isGift).map((e) => e.toJson()).toList()));
  }

  void _resetTotals() {
    _sellersOrders = {};
    _totalProductsAmount = 0.0;
    _totalDeliveryFees = 0.0;
    _hasCheckoutErrors = false;
  }

  Future<void> removeItem(CartItem item, String role) async {
    _cartItems.removeWhere((i) => i.offerId == item.offerId && i.unitIndex == item.unitIndex);
    await loadCartAndRecalculate(role);
  }

  Future<void> clearCart() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('cartItems');
    _cartItems = [];
    _resetTotals();
    notifyListeners();
  }
}
