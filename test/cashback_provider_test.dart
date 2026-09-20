import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:my_test_app/providers/buyer_data_provider.dart';
import 'package:my_test_app/providers/cashback_provider.dart';

// Test-only Firestore wrapper that can be flipped into failure mode to
// exercise the provider's catch paths with the same instance (stale state).
class FlakyFirestore implements FirebaseFirestore {
  final FakeFirebaseFirestore real;
  bool fail = false;

  FlakyFirestore(this.real);

  @override
  CollectionReference<Map<String, dynamic>> collection(String path) {
    if (fail) throw Exception('firestore down');
    return real.collection(path);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late FakeFirebaseFirestore fake;
  late FlakyFirestore flaky;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    fake = FakeFirebaseFirestore();
    flaky = FlakyFirestore(fake);
  });

  Future<BuyerDataProvider> buyerWithId(String? userId) async {
    final buyer = BuyerDataProvider(firestore: fake);
    await buyer.initializeData(
      userId,
      null,
      userId == null ? null : 'Test User',
    );
    return buyer;
  }

  Future<CashbackProvider> providerFor(
    String? userId, {
    bool useFlaky = false,
  }) async {
    final buyer = await buyerWithId(userId);
    return CashbackProvider(buyer, db: useFlaky ? flaky : fake);
  }

  Map<String, dynamic> cashbackRule({
    String status = 'active',
    int priority = 1,
    DateTime? start,
    DateTime? end,
    dynamic startRaw,
    dynamic endRaw,
    String targetType = 'instant',
    dynamic minPurchaseAmount = 200,
    String description = 'Test offer',
  }) {
    final now = DateTime.now();
    return {
      'status': status,
      'priority': priority,
      'startDate': startRaw ?? Timestamp.fromDate(start ?? now.subtract(const Duration(days: 30))),
      'endDate': endRaw ?? Timestamp.fromDate(end ?? now.add(const Duration(days: 30))),
      'targetType': targetType,
      'minPurchaseAmount': minPurchaseAmount,
      'description': description,
      'value': '10',
      'type': 'percentage',
    };
  }

  Map<String, dynamic> deliveredOrder({
    required String buyerId,
    String status = 'delivered',
    DateTime? orderDate,
    double? total,
    List<Map<String, dynamic>> items = const [],
  }) =>
      {
        'buyer': {'id': buyerId},
        'status': status,
        'orderDate': Timestamp.fromDate(
          orderDate ?? DateTime.now().subtract(const Duration(days: 5)),
        ),
        if (total != null) 'total': total,
        if (items.isNotEmpty) 'items': items,
      };

  group('fetchCashbackBalance', () {
    test('reads a numeric balance', () async {
      await fake.collection('users').doc('u1').set({'cashback': 25.5});

      final provider = await providerFor('u1');

      expect(await provider.fetchCashbackBalance(), 25.5);
      expect(provider.availableBalance, 25.5);
    });

    test('reads a numeric string balance', () async {
      await fake.collection('users').doc('u1').set({'cashback': '30'});

      final provider = await providerFor('u1');

      expect(await provider.fetchCashbackBalance(), 30.0);
    });

    test('missing cashback field reads as zero', () async {
      await fake.collection('users').doc('u1').set({'phone': '01'});

      final provider = await providerFor('u1');

      expect(await provider.fetchCashbackBalance(), 0.0);
      expect(provider.availableBalance, 0.0);
    });

    test('missing user document reads as zero', () async {
      final provider = await providerFor('ghost');

      expect(await provider.fetchCashbackBalance(), 0.0);
      expect(provider.availableBalance, 0.0);
    });

    test('null user id reads as zero without touching Firestore', () async {
      final provider = await providerFor(null);

      expect(await provider.fetchCashbackBalance(), 0.0);
      expect(provider.availableBalance, 0.0);
    });

    test('non-numeric value reads as zero', () async {
      await fake.collection('users').doc('u1').set({'cashback': 'abc'});

      final provider = await providerFor('u1');

      expect(await provider.fetchCashbackBalance(), 0.0);
    });

    test('negative balance is clamped to zero', () async {
      await fake.collection('users').doc('u1').set({'cashback': -10.0});

      final provider = await providerFor('u1');

      expect(await provider.fetchCashbackBalance(), 0.0);
      expect(provider.availableBalance, 0.0);
    });

    test('returned balance can never fund a negative discount', () async {
      await fake.collection('users').doc('u1').set({'cashback': -50.0});

      final provider = await providerFor('u1');
      final balance = await provider.fetchCashbackBalance();

      // Any min(total, balance)-style discount stays non-negative.
      expect(balance, greaterThanOrEqualTo(0.0));
    });

    test('firestore error returns zero but keeps the stale balance',
        () async {
      await fake.collection('users').doc('u1').set({'cashback': 20.0});
      final provider = await providerFor('u1', useFlaky: true);
      expect(await provider.fetchCashbackBalance(), 20.0);

      flaky.fail = true;

      // The caller gets 0.0 while the provider state still holds 20.0.
      expect(await provider.fetchCashbackBalance(), 0.0);
      expect(provider.availableBalance, 20.0);
    });
  });

  group('fetchAvailableOffers', () {
    test('lists an active rule inside its window with parsed fields',
        () async {
      await fake.collection('cashbackRules').add(cashbackRule(
        priority: 3,
        minPurchaseAmount: 200,
        description: 'Spring promo',
      ));

      final provider = await providerFor('u1');
      final offers = await provider.fetchAvailableOffers();

      expect(offers, hasLength(1));
      final offer = offers.single;
      expect(offer['description'], 'Spring promo');
      expect(offer['minAmount'], 200.0);
      expect(offer['value'], '10');
      expect(offer['type'], 'percentage');
      expect(offer['sellerName'], 'كل التجار');
      expect(offer['currentProgress'], 0);
      expect(offer['daysRemaining'], inInclusiveRange(28, 30));
      expect(provider.offersList, hasLength(1));
      expect(provider.isLoading, isFalse);
    });

    test('rules outside their window are excluded', () async {
      final now = DateTime.now();
      await fake.collection('cashbackRules').add(cashbackRule(
        start: now.add(const Duration(days: 1)),
        end: now.add(const Duration(days: 10)),
        description: 'future',
      ));
      await fake.collection('cashbackRules').add(cashbackRule(
        start: now.subtract(const Duration(days: 10)),
        end: now.subtract(const Duration(days: 1)),
        description: 'past',
      ));

      final provider = await providerFor('u1');

      expect(await provider.fetchAvailableOffers(), isEmpty);
      expect(provider.offersList, isEmpty);
    });

    test('window edges are inclusive', () async {
      final now = DateTime.now();
      // Just started / just about to end: both still listed.
      await fake.collection('cashbackRules').add(cashbackRule(
        start: now.subtract(const Duration(seconds: 1)),
        end: now.add(const Duration(hours: 1)),
        description: 'just-started',
      ));
      await fake.collection('cashbackRules').add(cashbackRule(
        start: now.subtract(const Duration(hours: 1)),
        end: now.add(const Duration(seconds: 1)),
        description: 'just-ending',
      ));

      final provider = await providerFor('u1');
      final offers = await provider.fetchAvailableOffers();

      expect(offers.map((o) => o['description']),
          containsAll(['just-started', 'just-ending']));
    });

    test('inactive rules are excluded', () async {
      await fake
          .collection('cashbackRules')
          .add(cashbackRule(status: 'paused'));

      final provider = await providerFor('u1');

      expect(await provider.fetchAvailableOffers(), isEmpty);
    });

    test('rules come back ordered by priority descending', () async {
      await fake.collection('cashbackRules').add(cashbackRule(
        priority: 1,
        description: 'low',
      ));
      await fake.collection('cashbackRules').add(cashbackRule(
        priority: 5,
        description: 'high',
      ));

      final provider = await providerFor('u1');
      final offers = await provider.fetchAvailableOffers();

      expect(
        offers.map((o) => o['description']).toList(),
        ['high', 'low'],
      );
    });

    test('cumulative rule sums delivered in-window totals', () async {
      await fake.collection('cashbackRules').add(cashbackRule(
        targetType: 'cumulative_period',
        description: 'cumulative',
      ));
      await fake.collection('orders').add(deliveredOrder(
        buyerId: 'u1',
        total: 40.0,
      ));
      await fake.collection('orders').add(deliveredOrder(
        buyerId: 'u1',
        total: 25.0,
      ));

      final provider = await providerFor('u1');
      final offers = await provider.fetchAvailableOffers();

      expect(offers.single['currentProgress'], 65.0);
    });

    test('placeOrder-style total field is counted in the sum', () async {
      await fake.collection('cashbackRules').add(cashbackRule(
        targetType: 'cumulative_period',
        description: 'cumulative',
      ));
      await fake.collection('orders').add(deliveredOrder(
        buyerId: 'u1',
        total: 100.0,
      ));

      final provider = await providerFor('u1');
      final offers = await provider.fetchAvailableOffers();

      expect(offers.single['currentProgress'], 100.0);
    });

    test('order-level total already excludes gifts (placeOrder contract)',
        () async {
      await fake.collection('cashbackRules').add(cashbackRule(
        targetType: 'cumulative_period',
        description: 'cumulative',
      ));
      // placeOrder flags zero-price lines as gifts and excludes them from
      // the stored 'total'; the provider trusts that order-level total.
      await fake.collection('orders').add(deliveredOrder(
        buyerId: 'u1',
        total: 100.0,
        items: const [
          {'name': 'Paid', 'quantity': 1, 'unit': 'pc', 'price': 100.0},
          {'name': 'Gift', 'quantity': 1, 'unit': 'pc', 'price': 0.0},
        ],
      ));

      final provider = await providerFor('u1');
      final offers = await provider.fetchAvailableOffers();

      expect(offers.single['currentProgress'], 100.0);
    });

    test('cumulative sum skips out-of-window, undelivered and foreign orders',
        () async {
      await fake.collection('cashbackRules').add(cashbackRule(
        targetType: 'cumulative_period',
        description: 'cumulative',
      ));
      await fake.collection('orders').add(deliveredOrder(
        buyerId: 'u1',
        total: 40.0,
      ));
      await fake.collection('orders').add(deliveredOrder(
        buyerId: 'u1',
        total: 500.0,
        orderDate: DateTime.now().subtract(const Duration(days: 60)),
      ));
      await fake.collection('orders').add(deliveredOrder(
        buyerId: 'u1',
        total: 500.0,
        status: 'shipped',
      ));
      await fake.collection('orders').add(deliveredOrder(
        buyerId: 'other',
        total: 500.0,
      ));

      final provider = await providerFor('u1');
      final offers = await provider.fetchAvailableOffers();

      expect(offers.single['currentProgress'], 40.0);
    });

    test('invalid rule is skipped while valid rules still load', () async {
      await fake.collection('cashbackRules').add(cashbackRule(
        description: 'good',
      ));
      await fake.collection('cashbackRules').add(cashbackRule(
        startRaw: 'not-a-date',
        description: 'bad-date',
      ));

      final provider = await providerFor('u1');
      final offers = await provider.fetchAvailableOffers();

      expect(offers.map((o) => o['description']).toList(), ['good']);
    });

    test('rule with valid ISO-8601 string dates is listed', () async {
      final now = DateTime.now();
      await fake.collection('cashbackRules').add(cashbackRule(
        startRaw: now.subtract(const Duration(days: 30)).toIso8601String(),
        endRaw: now.add(const Duration(days: 30)).toIso8601String(),
        description: 'string-dates',
      ));

      final provider = await providerFor('u1');
      final offers = await provider.fetchAvailableOffers();

      expect(offers.map((o) => o['description']).toList(), ['string-dates']);
    });

    test('null user id returns empty without touching Firestore', () async {
      final provider = await providerFor(null);

      expect(await provider.fetchAvailableOffers(), isEmpty);
      expect(provider.offersList, isEmpty);
    });

    test('firestore error returns empty but keeps stale offers', () async {
      await fake.collection('cashbackRules').add(cashbackRule(
        description: 'good',
      ));
      final provider = await providerFor('u1', useFlaky: true);
      expect(await provider.fetchAvailableOffers(), hasLength(1));

      flaky.fail = true;

      expect(await provider.fetchAvailableOffers(), isEmpty);
      expect(provider.offersList, hasLength(1));
    });
  });
}
