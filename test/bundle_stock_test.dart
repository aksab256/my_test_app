// test/bundle_stock_test.dart
//
// Pure bundle stock math: task's worked examples + lifecycle guards.
// No Firebase, no Flutter widgets.

import 'package:flutter_test/flutter_test.dart';
import 'package:my_test_app/utils/bundle_stock.dart';

/// Task table: avail 20/5/100 with per-unit qty 2/1/1 => max 5, limiter p2.
List<BundleStockLine> tableLines() => [
      line(offer: 'p1', physical: 20, need: 2),
      line(offer: 'p2', physical: 5, need: 1),
      line(offer: 'p3', physical: 100, need: 1),
    ];

BundleStockLine line({
  String offer = 'o',
  int physical = 10,
  int bundleReserved = 0,
  int giftReserved = 0,
  int need = 1,
}) =>
    BundleStockLine(
      offerId: offer,
      label: offer,
      physicalStock: physical,
      existingBundleReserved: bundleReserved,
      giftReserved: giftReserved,
      qtyRequired: need,
    );

void main() {
  group('bundle_stock', () {
    test('task example: 10/0/10/2 + 10/1/9/3 + 8/2/6/2 => max 3', () {
      final lines = [
        line(offer: 'p1', physical: 10, bundleReserved: 0, need: 2),
        line(offer: 'p2', physical: 10, bundleReserved: 1, need: 3),
        line(offer: 'p3', physical: 8, bundleReserved: 2, need: 2),
      ];
      expect(bundleLineAvailable(lines[0]), 10);
      expect(bundleLineAvailable(lines[1]), 9);
      expect(bundleLineAvailable(lines[2]), 6);
      expect(maxBundlesAcross(lines), 3);
      final v = validateBundleDraft(lines);
      expect(v.canCreate, isTrue);
      expect(v.maxBundles, 3);
      expect(v.limitingOfferId, 'p2');
    });

    test('impossible example: need 5 each with avail 10 and 3', () {
      final lines = [
        line(offer: 'p1', physical: 10, need: 5),
        line(offer: 'p2', physical: 3, need: 5),
      ];
      final v = validateBundleDraft(lines);
      expect(v.canCreate, isFalse);
      expect(v.reason, BundleBlockReason.insufficientStock);
      expect(v.message, contains('غير ممكن'));
    });

    test('one available, one not => blocked with limiting product', () {
      final lines = [
        line(offer: 'ok', physical: 10, need: 2),
        line(offer: 'short', physical: 1, need: 2),
      ];
      final v = validateBundleDraft(lines);
      expect(v.canCreate, isFalse);
      expect(v.limitingOfferId, 'short');
    });

    test('prior bundle reservations reduce availability', () {
      final before = [line(offer: 'a', physical: 10, need: 2)];
      expect(maxBundlesAcross(before), 5);
      final after = [
        line(offer: 'a', physical: 10, bundleReserved: 6, need: 2)
      ];
      expect(bundleLineAvailable(after[0]), 4);
      expect(maxBundlesAcross(after), 2);
    });

    test('gift locks share the same physical pool', () {
      final l = line(offer: 'a', physical: 10, giftReserved: 4, need: 3);
      expect(bundleLineAvailable(l), 6);
      expect(maxBundlesForLine(6, 3), 2);
    });

    test('qty edits recompute the limiting line', () {
      List<BundleStockLine> draft(int needB) => [
            line(offer: 'a', physical: 10, need: 2),
            line(offer: 'b', physical: 9, need: needB),
          ];
      expect(validateBundleDraft(draft(3)).maxBundles, 3);
      expect(validateBundleDraft(draft(5)).maxBundles, 1);
    });

    test('item-count bounds: 1 and 6 rejected, 2 and 5 accepted', () {
      expect(validateBundleDraft([line()]).canCreate, isFalse);
      expect(
          validateBundleDraft([line(), line(offer: 'b')]).canCreate, isTrue);
      expect(
          validateBundleDraft(
                  List.generate(5, (i) => line(offer: 'o$i')))
              .canCreate,
          isTrue);
      expect(
          validateBundleDraft(
                  List.generate(6, (i) => line(offer: 'o$i')))
              .reason,
          BundleBlockReason.badItemCount);
    });

    test('duplicate offer+unit rejected', () {
      final v = validateBundleDraft([line(offer: 'a'), line(offer: 'a')]);
      expect(v.canCreate, isFalse);
      expect(v.reason, BundleBlockReason.duplicateLine);
    });

    test('pricing totals and saving', () {
      final p = bundlePricing(
        linePrices: [100.0, 200.0],
        lineQuantities: [2, 3],
        bundlePrice: 700.0,
      );
      expect(p.originalTotal, 800.0);
      expect(p.saving, 100.0);
    });
  });

  group('bundle_count', () {
    test('exact max request (5 of 5) is accepted', () {
      final c = validateBundleCount(lines: tableLines(), requested: 5);
      expect(c.ok, isTrue);
      expect(c.maxBundles, 5);
      expect(c.requested, 5);
    });

    test('request above max (6 of 5) names the limiting product', () {
      final c = validateBundleCount(lines: tableLines(), requested: 6);
      expect(c.ok, isFalse);
      expect(c.maxBundles, 5);
      expect(c.limitingLabel, 'p2');
      expect(c.limitingAvail, 5);
      expect(c.limitingNeed, 1);
      expect(c.message, contains('الحد الأقصى 5'));
      expect(c.message, contains('p2'));
      expect(c.message, contains('المتاح 5'));
    });

    test('count is independent from product count and per-unit qty', () {
      // 2 lines only, large quantities: max driven by stock, not by shape.
      final lines = [
        line(offer: 'a', physical: 100, need: 10),
        line(offer: 'b', physical: 100, need: 10),
      ];
      expect(validateBundleCount(lines: lines, requested: 10).ok, isTrue);
      expect(validateBundleCount(lines: lines, requested: 11).ok, isFalse);
      // Product count stays 2 while the unit count varies freely.
      expect(validateBundleCount(lines: lines, requested: 1).ok, isTrue);
    });

    test('zero or negative counts rejected', () {
      expect(validateBundleCount(lines: tableLines(), requested: 0).ok,
          isFalse);
      expect(
          validateBundleCount(lines: tableLines(), requested: 0).message,
          contains('1 على الأقل'));
    });

    test('uses available stock after existing reservations, never physical alone', () {
      final lines = [
        line(offer: 'p1', physical: 20, bundleReserved: 12, need: 2),
        line(offer: 'p2', physical: 5, need: 1),
        line(offer: 'p3', physical: 100, need: 1),
      ];
      // p1: avail 8 -> floor(8/2)=4 becomes the new limiter.
      final c = validateBundleCount(lines: lines, requested: 5);
      expect(c.ok, isFalse);
      expect(c.maxBundles, 4);
      expect(c.limitingLabel, 'p1');
      expect(validateBundleCount(lines: lines, requested: 4).ok, isTrue);
    });

    test('per-bundle pricing math is stable regardless of the count', () {
      // Same per-bundle totals whether the seller offers 3 or 5 units.
      final p = bundlePricing(
        linePrices: [320.0, 370.0, 701.0],
        lineQuantities: [2, 1, 1],
        bundlePrice: 1500.0,
      );
      expect(p.originalTotal, 1711.0);
      expect(p.saving, 211.0);
    });
  });
}
