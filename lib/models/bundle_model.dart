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

  /// Legacy placeholder (kept for backward compat; superseded by cover*).
  final String? bundleImagePath;

  // ---- Cover (Bundle Image Composer, stored on Cloudinary) ----
  final String description;

  /// Cloudinary `public_id` of the cover (stable reference for any future
  /// server-side cleanup). Never a Firebase Storage path.
  final String? coverImagePath;

  /// Cloudinary `secure_url` (res.cloudinary.com) for direct display.
  final String? coverImageUrl;
  final DateTime? coverUpdatedAt;
  final int coverVersion;
  /// missing | ready | fallback | upload_failed
  final String coverStatus;

  // ---- Pricing ----
  /// ISO code; the app prices in EGP (ج.م) everywhere.
  final String currency;

  // ---- Seller snapshot (display + future purchase checks) ----
  final String sellerName;
  final String sellerPhone;

  /// Snapshot of the seller's live `deliveryAreas` at creation/update.
  /// Purchase-time eligibility MUST re-read the live sellers doc
  /// (same rule as offers: server/live data is final truth).
  final List<String> deliveryZones;
  final String? deliveryZonesSource;
  final DateTime? deliveryZonesSyncedAt;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  const SellerBundleModel({
    this.id,
    required this.sellerId,
    required this.bundleName,
    this.description = '',
    required this.items,
    required this.totalPrice,
    required this.originalTotal,
    this.currency = 'EGP',
    this.status = 'active',
    this.reservationStatus = 'active',
    this.reservedCount = 0,
    this.consumedCount = 0,
    this.releasedCount = 0,
    this.idempotencyKey,
    this.bundleImagePath,
    this.coverImagePath,
    this.coverImageUrl,
    this.coverUpdatedAt,
    this.coverVersion = 0,
    this.coverStatus = 'missing',
    this.sellerName = '',
    this.sellerPhone = '',
    this.deliveryZones = const [],
    this.deliveryZonesSource,
    this.deliveryZonesSyncedAt,
    this.createdAt,
    this.updatedAt,
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
    DateTime? updated;
    final u = data['updatedAt'];
    if (u is Timestamp) {
      updated = u.toDate();
    } else if (u is String) {
      updated = DateTime.tryParse(u);
    }
    DateTime? coverAt;
    final ca = data['coverUpdatedAt'];
    if (ca is Timestamp) {
      coverAt = ca.toDate();
    } else if (ca is String) {
      coverAt = DateTime.tryParse(ca);
    }
    DateTime? zonesAt;
    final za = data['deliveryZonesSyncedAt'];
    if (za is Timestamp) {
      zonesAt = za.toDate();
    } else if (za is String) {
      zonesAt = DateTime.tryParse(za);
    }
    return SellerBundleModel(
      id: docId,
      sellerId: data['sellerId'] as String? ?? '',
      bundleName: data['bundleName'] as String? ?? 'بندل',
      description: data['description']?.toString() ?? '',
      items: items,
      totalPrice: (data['totalPrice'] as num?)?.toDouble() ?? 0.0,
      originalTotal: (data['originalTotal'] as num?)?.toDouble() ?? 0.0,
      currency: data['currency']?.toString() ?? 'EGP',
      status: data['status'] as String? ?? 'active',
      reservationStatus:
          data['reservationStatus'] as String? ?? 'active',
      reservedCount: (data['reservedCount'] as num?)?.toInt() ?? 0,
      consumedCount: (data['consumedCount'] as num?)?.toInt() ?? 0,
      releasedCount: (data['releasedCount'] as num?)?.toInt() ?? 0,
      idempotencyKey: data['idempotencyKey'] as String?,
      bundleImagePath: data['bundleImagePath'] as String?,
      coverImagePath: data['coverImagePath'] as String?,
      coverImageUrl: data['coverImageUrl'] as String?,
      coverUpdatedAt: coverAt,
      coverVersion: (data['coverVersion'] as num?)?.toInt() ?? 0,
      coverStatus: data['coverStatus']?.toString() ?? 'missing',
      sellerName: data['sellerName']?.toString() ?? '',
      sellerPhone: data['sellerPhone']?.toString() ?? '',
      deliveryZones: ((data['deliveryZones'] as List?) ?? [])
          .map((e) => e.toString())
          .toList(),
      deliveryZonesSource: data['deliveryZonesSource'] as String?,
      deliveryZonesSyncedAt: zonesAt,
      createdAt: created,
      updatedAt: updated,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'sellerId': sellerId,
      'bundleName': bundleName,
      'description': description,
      'items': items.map((e) => e.toMap()).toList(),
      'totalPrice': totalPrice,
      'originalTotal': originalTotal,
      'saving': saving,
      'currency': currency,
      'status': status,
      'reservationStatus': reservationStatus,
      'reservedCount': reservedCount,
      'consumedCount': consumedCount,
      'releasedCount': releasedCount,
      if (idempotencyKey != null) 'idempotencyKey': idempotencyKey,
      'bundleImagePath': bundleImagePath,
      if (coverImagePath != null) 'coverImagePath': coverImagePath,
      if (coverImageUrl != null) 'coverImageUrl': coverImageUrl,
      if (coverUpdatedAt != null)
        'coverUpdatedAt': coverUpdatedAt!.toIso8601String(),
      'coverVersion': coverVersion,
      'coverStatus': coverStatus,
      'sellerName': sellerName,
      'sellerPhone': sellerPhone,
      'deliveryZones': deliveryZones,
      if (deliveryZonesSource != null)
        'deliveryZonesSource': deliveryZonesSource,
      if (deliveryZonesSyncedAt != null)
        'deliveryZonesSyncedAt':
            deliveryZonesSyncedAt!.toIso8601String(),
    };
  }
}
