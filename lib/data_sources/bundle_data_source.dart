// lib/data_sources/bundle_data_source.dart
//
// Seller catalog + bundle lifecycle gateway.
//
// Creation NEVER writes stock from the client: it refetches fresh offer docs
// (physical + reservations) for the preview/final gate, then calls the
// `createBundleWithReservation` callable. All stock mutation happens in the
// backend transaction.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:my_test_app/models/bundle_model.dart';

/// One catalog row from the seller's own `productOffers`.
class BundleCatalogRow {
  final String offerId;
  final String productId;
  final String productName;
  final String? imageUrl;
  final int unitIndex;
  final String unitName;
  final double price;
  final int physicalStock;
  final int giftReserved;
  final int bundleReserved;

  /// Sellable right now (mirrors units[i].availableStock when coherent).
  int get availableStock {
    final int v = physicalStock - giftReserved - bundleReserved;
    return v < 0 ? 0 : v;
  }

  const BundleCatalogRow({
    required this.offerId,
    required this.productId,
    required this.productName,
    this.imageUrl,
    this.unitIndex = 0,
    required this.unitName,
    required this.price,
    required this.physicalStock,
    required this.giftReserved,
    required this.bundleReserved,
  });
}

class BundleDataSource {
  final FirebaseFirestore _db;
  final FirebaseFunctions _functions;

  BundleDataSource({FirebaseFirestore? db, FirebaseFunctions? functions})
      : _db = db ?? FirebaseFirestore.instance,
        _functions = functions ?? FirebaseFunctions.instance;

  static int _asInt(dynamic v) =>
      v is num ? v.toInt() : int.tryParse('$v') ?? 0;

  BundleCatalogRow _rowFromOffer(
      DocumentSnapshot doc, int unitIndex, String? productImage) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final units = (data['units'] as List?) ?? [];
    final Map<String, dynamic> unit = units.isNotEmpty &&
            unitIndex < units.length &&
            units[unitIndex] is Map
        ? Map<String, dynamic>.from(units[unitIndex] as Map)
        : (units.isNotEmpty && units.first is Map
            ? Map<String, dynamic>.from(units.first as Map)
            : <String, dynamic>{});
    final int avail = _asInt(unit['availableStock']);
    final int giftRes = _asInt(unit['reservedForPromos']);
    final int bundleRes = _asInt(unit['reservedForBundles']);
    return BundleCatalogRow(
      offerId: doc.id,
      productId: (data['productId'] ?? doc.id).toString(),
      productName:
          (data['productName'] ?? 'منتج').toString(),
      imageUrl: (data['imageUrl'] ?? productImage)?.toString(),
      unitIndex: unitIndex,
      unitName: (unit['unitName'] ?? 'وحدة').toString(),
      price: (unit['price'] as num?)?.toDouble() ?? 0.0,
      giftReserved: giftRes,
      bundleReserved: bundleRes,
      // Physical is reconstructed so the UI can show the task's columns:
      // physical = available + all reservations.
      physicalStock: avail + giftRes + bundleRes,
    );
  }

  /// Seller catalog only (2-5 pick happens in the UI).
  /// Reads each `productOffers` unit as its own row (unit 0 primary).
  Future<List<BundleCatalogRow>> loadSellerCatalog(String sellerId,
      {bool activeOnly = true}) async {
    Query query =
        _db.collection('productOffers').where('sellerId', isEqualTo: sellerId);
    if (activeOnly) query = query.where('status', isEqualTo: 'active');
    final snap = await query.get();
    final rows = <BundleCatalogRow>[];
    for (final doc in snap.docs) {
      final data = doc.data() as Map<String, dynamic>? ?? {};
      final units = (data['units'] as List?) ?? [];
      if (units.isEmpty) {
        rows.add(_rowFromOffer(doc, 0, null));
      } else {
        for (int i = 0; i < units.length; i++) {
          rows.add(_rowFromOffer(doc, i, null));
        }
      }
    }
    // Enrich the first-row image from `products` when the offer has none.
    final needImage =
        rows.where((r) => r.imageUrl == null || r.imageUrl!.isEmpty).toList();
    final ids = needImage.map((r) => r.productId).toSet();
    final Map<String, String> images = {};
    for (final pid in ids) {
      try {
        final p = await _db.collection('products').doc(pid).get();
        final urls = (p.data()?['imageUrls'] as List?);
        if (urls != null && urls.isNotEmpty) {
          images[pid] = urls.first.toString();
        }
      } catch (_) {}
    }
    return rows
        .map((r) => (r.imageUrl == null || r.imageUrl!.isEmpty) &&
                images.containsKey(r.productId)
            ? BundleCatalogRow(
                offerId: r.offerId,
                productId: r.productId,
                productName: r.productName,
                imageUrl: images[r.productId],
                unitIndex: r.unitIndex,
                unitName: r.unitName,
                price: r.price,
                physicalStock: r.physicalStock,
                giftReserved: r.giftReserved,
                bundleReserved: r.bundleReserved,
              )
            : r)
        .toList();
  }

  /// Fresh refetch of the exact offer/unit rows before submit.
  Future<List<BundleCatalogRow>> refetchRows(
      List<Map<String, dynamic>> items) async {
    final out = <BundleCatalogRow>[];
    for (final it in items) {
      final doc =
          await _db.collection('productOffers').doc('${it['offerId']}').get();
      if (!doc.exists) continue;
      out.add(_rowFromOffer(
          doc, (it['unitIndex'] as num?)?.toInt() ?? 0, null));
    }
    return out;
  }

  Stream<List<SellerBundleModel>> streamSellerBundles(String sellerId) {
    return _db
        .collection('sellerBundles')
        .where('sellerId', isEqualTo: sellerId)
        .snapshots()
        .map((s) => s.docs
            .map((d) =>
                SellerBundleModel.fromFirestore(d.data(), d.id))
            .toList());
  }

  Future<Map<String, dynamic>> createBundle({
    required String bundleName,
    required List<Map<String, dynamic>> items,
    required double totalPrice,
    required String idempotencyKey,
  }) async {
    final callable =
        _functions.httpsCallable('createBundleWithReservation');
    final res = await callable.call({
      'bundleName': bundleName,
      'items': items,
      'totalPrice': totalPrice,
      'idempotencyKey': idempotencyKey,
    });
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<Map<String, dynamic>> updateBundleItems({
    required String bundleId,
    required List<Map<String, dynamic>> items,
  }) async {
    final callable =
        _functions.httpsCallable('updateBundleReservation');
    final res = await callable.call({'bundleId': bundleId, 'items': items});
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<Map<String, dynamic>> setBundleStatus(
      {required String bundleId, required String status}) async {
    final callable = _functions.httpsCallable('setBundleStatus');
    final res = await callable.call({'bundleId': bundleId, 'status': status});
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<Map<String, dynamic>> deleteBundle(String bundleId) async {
    return setBundleStatus(bundleId: bundleId, status: 'deleted');
  }

  Future<Map<String, dynamic>> consumeBundleSale(
      {required String bundleId, required int bundleCount}) async {
    final callable = _functions.httpsCallable('consumeBundleSale');
    final res = await callable
        .call({'bundleId': bundleId, 'bundleCount': bundleCount});
    return Map<String, dynamic>.from(res.data as Map);
  }
}
