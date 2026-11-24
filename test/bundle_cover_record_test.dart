// test/bundle_cover_record_test.dart
//
// Bundle record readiness for future purchase: cover metadata, seller
// identity, delivery-zone snapshot source, pricing, and component refs.
// Pure Dart: exercises SellerBundleModel serialization only (no Firebase).

import 'package:flutter_test/flutter_test.dart';
import 'package:my_test_app/models/bundle_model.dart';

SellerBundleModel sample() => SellerBundleModel(
      id: 'b1',
      sellerId: 's1',
      bundleName: 'بندل الفطار',
      description: 'كل احتياجات الفطار',
      items: const [
        BundleItemModel(
          offerId: 'o1',
          productId: 'p1',
          productName: 'جبنة',
          imageUrl: 'https://x/cheese.jpg',
          unitIndex: 0,
          unitName: 'علبة',
          qtyRequired: 2,
          priceSnapshot: 50.0,
        ),
        BundleItemModel(
          offerId: 'o2',
          productId: 'p2',
          productName: 'بيض',
          unitIndex: 1,
          unitName: 'طبق',
          qtyRequired: 1,
          priceSnapshot: 90.0,
        ),
      ],
      totalPrice: 170.0,
      originalTotal: 190.0,
      currency: 'EGP',
      status: 'active',
      bundleCount: 5,
      soldCount: 2,
      remainingCount: 3,
      coverImagePath: 'bundle_covers/b1',
      coverImageUrl: 'https://res.cloudinary.com/dgmmx6jbu/image/upload/v9/bundle_covers/b1.jpg',
      coverUpdatedAt: DateTime.utc(2026, 11, 24, 10, 0, 0),
      coverVersion: 1,
      coverStatus: 'ready',
      sellerName: 'متجر النور',
      sellerPhone: '01000000000',
      deliveryZones: const ['سيدي بشر', 'العصافرة'],
      deliveryZonesSource: 'sellers/s1.deliveryAreas',
      deliveryZonesSyncedAt: DateTime.utc(2026, 11, 24, 9, 0, 0),
    );

void main() {
  group('bundle_cover_record', () {
    test('round trip preserves cover + seller + zones + items', () {
      final json = sample().toJson();
      final back = SellerBundleModel.fromFirestore(json, 'b1');
      expect(back.id, 'b1');
      expect(back.sellerId, 's1');
      expect(back.bundleName, 'بندل الفطار');
      expect(back.description, 'كل احتياجات الفطار');
      expect(back.coverImagePath, 'bundle_covers/b1');
      expect(back.coverImageUrl, 'https://res.cloudinary.com/dgmmx6jbu/image/upload/v9/bundle_covers/b1.jpg');
      expect(back.coverVersion, 1);
      expect(back.coverStatus, 'ready');
      expect(back.sellerName, 'متجر النور');
      expect(back.deliveryZones, ['سيدي بشر', 'العصافرة']);
      expect(back.deliveryZonesSource, 'sellers/s1.deliveryAreas');
      expect(back.items.length, 2);
      expect(back.items[0].offerId, 'o1');
      expect(back.items[0].productId, 'p1');
      expect(back.items[0].qtyRequired, 2);
      expect(back.items[0].priceSnapshot, 50.0);
      expect(back.bundleCount, 5);
      expect(back.soldCount, 2);
      expect(back.remainingCount, 3);
    });

    test('pricing exposes original, final, and saving', () {
      final b = sample();
      expect(b.originalTotal, 190.0);
      expect(b.totalPrice, 170.0);
      expect(b.saving, 20.0);
      expect(b.currency, 'EGP');
    });

    test('missing cover degrades to fallback status, not invented data', () {
      final json = sample().toJson();
      json.remove('coverImagePath');
      json.remove('coverImageUrl');
      json['coverStatus'] = 'missing';
      final back = SellerBundleModel.fromFirestore(json, 'b1');
      expect(back.coverImagePath, isNull);
      expect(back.coverImageUrl, isNull);
      expect(back.coverStatus, 'missing');
      // Components remain the source of truth.
      expect(back.items.length, 2);
      expect(back.items[1].offerId, 'o2');
    });

    test('legacy docs without count fields default to one bundle', () {
      final json = sample().toJson()
        ..remove('bundleCount')
        ..remove('soldCount')
        ..remove('remainingCount');
      final back = SellerBundleModel.fromFirestore(json, 'b1');
      expect(back.bundleCount, 1);
      expect(back.soldCount, 0);
      expect(back.remainingCount, 1);
    });

    test('upload failure status survives the round trip', () {
      final json = sample().toJson()
        ..['coverStatus'] = 'upload_failed';
      json.remove('coverImageUrl');
      final back = SellerBundleModel.fromFirestore(json, 'b1');
      expect(back.coverStatus, 'upload_failed');
      expect(back.sellerId, 's1');
    });
  });
}
