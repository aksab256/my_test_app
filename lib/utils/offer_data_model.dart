import 'package:cloud_firestore/cloud_firestore.dart';

class OfferModel {
  final String offerId;
  final String productId; // 👈 تم الإضافة (مهمة للفلترة)
  final String sellerId;
  final String sellerName;
  final List<String>? deliveryAreas; // 👈 تم الإضافة (مهمة جداً للفلترة الجغرافية)
  final dynamic price; 
  final String unitName;
  final int stock;
  final int? minQty;
  final int? maxQty;
  final int? unitIndex; 
  final bool disabled;

  OfferModel({
    required this.offerId,
    required this.productId, // 👈 أضفناه هنا
    required this.sellerId,
    required this.sellerName,
    this.deliveryAreas, // 👈 أضفناه هنا
    required this.price,
    required this.unitName,
    required this.stock,
    this.minQty = 1,
    this.maxQty,
    this.unitIndex = -1,
    this.disabled = false,
  });

  static List<OfferModel> fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) return [];

    final String offerId = doc.id;
    final String productId = data['productId'] ?? ''; // جلب معرف المنتج
    final String sellerId = data['sellerId'] ?? '';
    final String sellerName = data['sellerName'] ?? 'بائع غير معروف';
    final int productMinQty = data['minOrder'] ?? 1;
    final int? productMaxQty = data['maxOrder'];
    
    // 🎯 جلب قائمة المناطق الجغرافية من الـ Document
    final List<String>? areas = data['deliveryAreas'] != null 
        ? List<String>.from(data['deliveryAreas']) 
        : null;
    
    List<OfferModel> unitsList = [];
    
    if (data.containsKey('units') && data['units'] is List) {
      final List units = data['units'] as List;

      units.asMap().forEach((index, unitData) {
        if (unitData is Map<String, dynamic>) {
          final String unitName = unitData['unitName'] ?? 'وحدة غير محددة';
          final dynamic price = unitData['price'] ?? '?';
          final int stock = unitData['availableStock'] ?? 0;
          
          final bool isDisabled = stock < productMinQty;

          unitsList.add(OfferModel(
            offerId: offerId,
            productId: productId, // تمرير المنتج
            sellerId: sellerId,
            sellerName: sellerName,
            deliveryAreas: areas, // تمرير المناطق
            price: price,
            unitName: unitName,
            stock: stock,
            minQty: productMinQty,
            maxQty: productMaxQty,
            unitIndex: index,
            disabled: isDisabled,
          ));
        }
      });
    } 
    else {
      final dynamic price = data['price'] ?? '?';
      final int stock = data['availableQuantity'] ?? 0;
      final String unitName = data['unitName'] ?? 'وحدة افتراضية';
      
      final bool isDisabled = stock < productMinQty;

      unitsList.add(OfferModel(
        offerId: offerId,
        productId: productId, // تمرير المنتج
        sellerId: sellerId,
        sellerName: sellerName,
        deliveryAreas: areas, // تمرير المناطق
        price: price,
        unitName: unitName,
        stock: stock,
        minQty: productMinQty,
        maxQty: productMaxQty,
        unitIndex: -1,
        disabled: isDisabled,
      ));
    }
    
    return unitsList;
  }
}

extension IterableExtension<E> on Iterable<E> {
  E? firstWhereOrNull(bool Function(E element) test) {
    for (var element in this) {
      if (test(element)) return element;
    }
    return null;
  }
}
