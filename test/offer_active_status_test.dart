import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:my_test_app/data_sources/offer_data_source.dart';
import 'package:my_test_app/utils/offer_geo_filter.dart';

void main() {
  group('isOfferActive', () {
    test('active (any case/whitespace) is visible', () {
      expect(isOfferActive({'status': 'active'}), isTrue);
      expect(isOfferActive({'status': ' Active '}), isTrue);
      expect(isOfferActive({'status': 'ACTIVE'}), isTrue);
    });

    test('inactive and future hidden states are not visible', () {
      expect(isOfferActive({'status': 'inactive'}), isFalse);
      expect(isOfferActive({'status': 'retired'}), isFalse);
      expect(isOfferActive({'status': 'disabled'}), isFalse);
    });

    test('missing or empty status stays visible (legacy offers)', () {
      expect(isOfferActive({}), isTrue);
      expect(isOfferActive({'status': null}), isTrue);
      expect(isOfferActive({'status': ''}), isTrue);
      expect(isOfferActive({'status': '   '}), isTrue);
    });
  });

  group('offerBlockedReason', () {
    test('active or legacy offer is orderable', () {
      expect(offerBlockedReason({'status': 'active'}), isNull);
      expect(offerBlockedReason({}), isNull);
    });

    test('inactive offer is rejected with a message', () {
      expect(offerBlockedReason({'status': 'inactive'}), isNotNull);
    });
  });

  group('visibleOfferSellerIds respects status', () {
    test('seller with only inactive offers is hidden', () {
      final ids = visibleOfferSellerIds(
        offerDocs: [
          {'sellerId': 's1', 'status': 'inactive'},
        ],
        buyerAreas: const [],
      );
      expect(ids, isEmpty);
    });

    test('seller with one visible active offer shows (Global)', () {
      final ids = visibleOfferSellerIds(
        offerDocs: [
          {'sellerId': 's1', 'status': 'inactive'},
          {'sellerId': 's2', 'status': 'active'},
        ],
        buyerAreas: const [],
      );
      expect(ids, contains('s2'));
      expect(ids, isNot(contains('s1')));
    });

    test('active offer outside buyer areas stays hidden', () {
      final ids = visibleOfferSellerIds(
        offerDocs: [
          {
            'sellerId': 's1',
            'status': 'active',
            'deliveryZones': ['zone-a']
          },
        ],
        buyerAreas: const ['zone-b'],
      );
      expect(ids, isEmpty);
    });

    test('legacy offer without status still counts (backward compat)', () {
      final ids = visibleOfferSellerIds(
        offerDocs: [
          {'sellerId': 's1'},
        ],
        buyerAreas: const [],
      );
      expect(ids, contains('s1'));
    });
  });

  group('trader grid composition hides inactive offers', () {
    test('inactive docs never reach the geo filter output', () {
      final loaded = [
        {'offerDocId': 'o1', 'status': 'active'},
        {'offerDocId': 'o2', 'status': 'inactive'},
        {'offerDocId': 'o3'},
      ];
      final activeOnly = loaded.where(isOfferActive).toList();
      final out = filterOfferDocs(
          activeOnly, const [], OfferListContext.productOffers);
      expect(out.map((e) => e['offerDocId']), ['o1', 'o3']);
    });
  });

  group('seller keeps managing hidden offers', () {
    test('loadSellerOffers returns active and inactive offers alike', () async {
      final fake = FakeFirebaseFirestore();
      await fake.collection('productOffers').doc('o1').set({
        'sellerId': 's1',
        'sellerName': 'seller one',
        'productId': 'p1',
        'productName': 'item one',
        'units': [],
        'status': 'active',
      });
      await fake.collection('productOffers').doc('o2').set({
        'sellerId': 's1',
        'sellerName': 'seller one',
        'productId': 'p2',
        'productName': 'item two',
        'units': [],
        'status': 'inactive',
      });
      final dataSource = OfferDataSource(firestore: fake);
      final offers = await dataSource.loadSellerOffers('s1');
      final byId = {for (final o in offers) o.id: o.status};
      expect(byId['o1'], 'active');
      expect(byId['o2'], 'inactive');
    });
  });

  group('cart and checkout decisions', () {
    test('fresh doc shapes from details fetch drive the same rule', () {
      // Mirrors _getProductOfferDetails return contract + checkout re-read.
      expect(offerBlockedReason({'status': 'active'}), isNull);
      expect(offerBlockedReason({'status': null}), isNull);
      expect(
          offerBlockedReason({'status': 'inactive'}), 'هذا العرض لم يعد متاحًا');
    });
  });
}
