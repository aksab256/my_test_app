// lib/models/bundle_model.dart
//
// Firestore design for `sellerBundles` (integrates with `productOffers.units`).
// The unit counter `reservedForBundles` on each offer/unit is the live lock;
// bundle docs are the audit trail (who locked what, how much is consumed or
// released). Stock is never copied as an independent balance.

import 'package:cloud_firestore/cloud_firestore.dart';

/// One component of a bundle.
class BundleItemModel {
  final String offerId;
  final String productId;
  final String productName;
  final String? imageUrl;
  final int unitIndex;
  final String unitName;

  /// Units of this line consumed by ONE bundle.
  final int qtyRequired;

  /// Unit price snapshot at creation (for totals/preview, not for charging).
  final double priceSnapshot;

  const BundleItemModel({
    required this.offerId,
    required this.productId,
    required this.productName,
    this.imageUrl,
    this.unitIndex = 0,
    required this.unitName,
    required this.qtyRequired,
    required this.priceSnapshot,
  });

  factory BundleItemModel.fromMap(Map<String, dynamic> map) {
    return BundleItemModel(
      offerId: map['offerId'] as String? ?? '',
      productId: map['productId'] as String? ?? '',
      productName: map['productName'] as String? ?? 'منتج',
      imageUrl: map['imageUrl'] as String?,
      unitIndex: (map['unitIndex'] as num?)?.toInt() ?? 0,
      unitName: map['unitName'] as String? ?? 'وحدة',
      qtyRequired: (map['qtyRequired'] as num?)?.toInt() ?? 0,
      priceSnapshot: (map['priceSnapshot'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'offerId': offerId,
      'productId': productId,
      'productName': productName,
      if (imageUrl != null) 'imageUrl': imageUrl,
      'unitIndex': unitIndex,
      'unitName': unitName,
      'qtyRequired': qtyRequired,
      'priceSnapshot': priceSnapshot,
    };
  }
}

/// Bundle document in `sellerBundles`.
class SellerBundleModel {
  final String? id;
  final String sellerId;
  final String bundleName;
  final List<BundleItemModel> items;
  final double totalPrice;
  final double originalTotal;

  /// active | disabled | deleted
  final String status;

  /// active | released | consumed | partial (mixed consume+release)
  final String reservationStatus;

  final int reservedCount;
  final int consumedCount;
  final int releasedCount;

  /// Client-generated UUID sent with create; backend enforces uniqueness.
  final String? idempotencyKey;

  /// Future Bundle Image Composer hook. Always null in this task.
  final String? bundleImagePath;

  final DateTime? createdAt;

  const SellerBundleModel({
    this.id,
    required this.sellerId,
    required this.bundleName,
    required this.items,
    required this.totalPrice,
    required this.originalTotal,
    this.status = 'active',
    this.reservationStatus = 'active',
    this.reservedCount = 0,
    this.consumedCount = 0,
    this.releasedCount = 0,
    this.idempotencyKey,
    this.bundleImagePath,
    this.createdAt,
  });

  double get saving => originalTotal - totalPrice;

  factory SellerBundleModel.fromFirestore(
      Map<String, dynamic> data, String docId) {
    final items = ((data['items'] as List?) ?? [])
        .whereType<Map>()
        .map((e) => BundleItemModel.fromMap(Map<String, dynamic>.from(e)))
        .toList();
    DateTime? created;
    final c = data['createdAt'];
    if (c is Timestamp) {
      created = c.toDate();
    } else if (c is String) {
      created = DateTime.tryParse(c);
    }
    return SellerBundleModel(
      id: docId,
      sellerId: data['sellerId'] as String? ?? '',
      bundleName: data['bundleName'] as String? ?? 'بندل',
      items: items,
      totalPrice: (data['totalPrice'] as num?)?.toDouble() ?? 0.0,
      originalTotal: (data['originalTotal'] as num?)?.toDouble() ?? 0.0,
      status: data['status'] as String? ?? 'active',
      reservationStatus:
          data['reservationStatus'] as String? ?? 'active',
      reservedCount: (data['reservedCount'] as num?)?.toInt() ?? 0,
      consumedCount: (data['consumedCount'] as num?)?.toInt() ?? 0,
      releasedCount: (data['releasedCount'] as num?)?.toInt() ?? 0,
      idempotencyKey: data['idempotencyKey'] as String?,
      bundleImagePath: data['bundleImagePath'] as String?,
      createdAt: created,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'sellerId': sellerId,
      'bundleName': bundleName,
      'items': items.map((e) => e.toMap()).toList(),
      'totalPrice': totalPrice,
      'originalTotal': originalTotal,
      'saving': saving,
      'status': status,
      'reservationStatus': reservationStatus,
      'reservedCount': reservedCount,
      'consumedCount': consumedCount,
      'releasedCount': releasedCount,
      if (idempotencyKey != null) 'idempotencyKey': idempotencyKey,
      'bundleImagePath': bundleImagePath,
    };
  }
}
