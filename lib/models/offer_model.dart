// lib/models/offer_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

// نموذج يمثل بيانات الوحدة داخل العرض
class OfferUnitModel {
  final String unitName;
  final double price;
  final int availableStock;

  OfferUnitModel({
    required this.unitName,
    required this.price,
    required this.availableStock,
  });

  factory OfferUnitModel.fromJson(Map<String, dynamic> json) {
    return OfferUnitModel(
      unitName: json['unitName'] ?? 'وحدة',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      availableStock: (json['availableStock'] as int?) ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'unitName': unitName,
      'price': price,
      'availableStock': availableStock,
    };
  }
}

// نموذج يمثل وثيقة العرض الكاملة (productOffers)
class ProductOfferModel {
  final String? id;
  final String sellerId;
  final String sellerName;
  final String productId;
  final String productName;
  String? imageUrl; // 🎯 أعدناه ليكون قابلاً للحفظ في Firestore
  final List<String> deliveryZones;
  final List<OfferUnitModel> units;
  final int? minOrder;
  final int? maxOrder;
  final int? lowStockThreshold;
  final double? offerPrice; // 🎯 الحقل الجديد لسعر الخصم/العرض
  final String status;
  final Timestamp? createdAt;

  ProductOfferModel({
    this.id,
    required this.sellerId,
    required this.sellerName,
    required this.productId,
    required this.productName,
    this.imageUrl,
    this.deliveryZones = const [],
    required this.units,
    this.minOrder,
    this.maxOrder,
    this.lowStockThreshold,
    this.offerPrice, // 🎯 الممر المباشر في الـ Constructor
    this.status = "active",
    this.createdAt,
  });

  factory ProductOfferModel.fromFirestore(Map<String, dynamic> data, String id) {
    final List<dynamic> unitsData = data['units'] ?? [];
    final unitsList = unitsData.map((e) => OfferUnitModel.fromJson(e as Map<String, dynamic>)).toList();

    return ProductOfferModel(
      id: id,
      sellerId: data['sellerId'] ?? data['ownerId'] ?? '',
      sellerName: data['sellerName'] ?? data['merchantName'] ?? 'بائع', // 🎯 توافق مع merchantName في الويب
      productId: data['productId'] ?? '',
      productName: data['productName'] ?? 'غير معروف',
      imageUrl: data['imageUrl'], // 🎯 نقرأ الصورة إذا كانت موجودة
      deliveryZones: List<String>.from(data['deliveryZones'] ?? []),
      units: unitsList,
      minOrder: data['minOrder'] as int?,
      maxOrder: data['maxOrder'] as int?,
      lowStockThreshold: data['lowStockThreshold'] as int?,
      offerPrice: (data['offerPrice'] as num?)?.toDouble(), // 🎯 قراءة سعر العرض
      status: data['status'] ?? 'active',
      createdAt: data['createdAt'] as Timestamp?,
    );
  }

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{
      'sellerId': sellerId,
      'sellerName': sellerName,
      'productId': productId,
      'productName': productName,
      'imageUrl': imageUrl, // 🎯 ضروري جداً للحفظ ليظهر العرض فوراً للمشتري
      'deliveryZones': deliveryZones,
      'units': units.map((u) => u.toJson()).toList(),
      'status': status,
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
    };

    if (minOrder != null) data['minOrder'] = minOrder;
    if (maxOrder != null) data['maxOrder'] = maxOrder;
    if (lowStockThreshold != null) data['lowStockThreshold'] = lowStockThreshold;
    if (offerPrice != null) data['offerPrice'] = offerPrice; // 🎯 حفظ سعر العرض إن وجد (ولن يحفظ إذا كان null)

    return data;
  }

  void setImageUrl(String url) {
    imageUrl = url;
  }
}