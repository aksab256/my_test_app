import 'package:flutter_test/flutter_test.dart';

// Server-pricing safety net (specification contract).
//
// The functions below are SPEC MIRRORS of `cashback/order_monitor_island`
// (`serverPriceDelivery` trigger + `handleInsuranceLocking`). They pin the
// business/security invariants of the pricing move. If the backend formula
// or guards change, update this file together with the backend.
//
// What this file does NOT do (by design, no production changes allowed):
//  - it does not call the real trigger, Firestore rules, or any emulator;
//  - the `server e2e` group is skipped by default and documents the checks
//    that must run against the emulator / live backend before deploy.
//
// SECURITY INVARIANTS (must all hold):
//  1. The backend is the final pricing authority (client values untrusted).
//  2. commissionAmount is derived server-side, never accepted from clients.
//  3. driverNet/totalPrice are derived from the server pricing only.
//  4. Minimum commission is preserved: max(% of subtotal, fixed fee).
//  5. After serverPriced=true the pricing fields are immutable (rules).
//  6. Missing driverNet at accept must NOT under-lock (fail-closed: full).
//  7. No double pricing (pending + unlocked + unpriced only).

/// Mirror of `priceTrip(distanceKm, cfg)` in order_monitor_island/index.js.
/// Throws on invalid config/distance exactly like the backend.
Map<String, double> specPriceTrip(double distanceKm, Map<String, Object?> cfg) {
  double num(String key) {
    final v = cfg[key];
    final n = v is num ? v.toDouble() : double.tryParse('$v');
    if (n == null || !n.isFinite || n < 0) {
      throw ArgumentError('invalid pricing config: $key');
    }
    return n;
  }

  final baseFare = num('baseFare');
  final kmRate = num('kmRate');
  final minFare = num('minFare');
  final feeFixed = num('serviceFee');
  final feePct = num('serviceFeePercentage');
  if (!distanceKm.isFinite || distanceKm < 0 || distanceKm > 500) {
    throw ArgumentError('invalid trip distance');
  }
  var subtotal = baseFare + distanceKm * kmRate;
  if (subtotal < minFare) subtotal = minFare;
  final byPct = subtotal * (feePct / 100);
  final commission = byPct > feeFixed ? byPct : feeFixed;
  double round2(double x) => (x * 100).round() / 100;
  return {
    'totalPrice': round2(subtotal + commission),
    'commissionAmount': round2(commission),
    'driverNet': round2(subtotal),
  };
}

/// Mirror of the reprice guards in `serverPriceDelivery`.
bool specShouldPrice({required String? status, required bool moneyLocked, required bool serverPriced}) {
  if (status != 'pending' || moneyLocked) return false;
  if (serverPriced) return false;
  return true;
}

/// Mirror of the escrow lock input in `handleInsuranceLocking`:
/// insurance = orderFinalAmount - (driverNet or 0 when missing).
double specInsuranceLock(double orderFinalAmount, double? driverNet) {
  return orderFinalAmount - (driverNet ?? 0);
}

void main() {
  group('server pricing formula (minimums preserved)', () {
    Map<String, Object?> cfg({
      double baseFare = 10.0,
      double kmRate = 5.0,
      double minFare = 15.0,
      double serviceFee = 5.0,
      double serviceFeePercentage = 10.0,
    }) =>
        {
          'baseFare': baseFare,
          'kmRate': kmRate,
          'minFare': minFare,
          'serviceFee': serviceFee,
          'serviceFeePercentage': serviceFeePercentage,
        };

    test('percentage above fixed fee wins', () {
      // subtotal = 10 + 10*5 = 60; 10% = 6 > 5 fixed.
      final p = specPriceTrip(10.0, cfg());
      expect(p['driverNet'], 60.0);
      expect(p['commissionAmount'], 6.0);
      expect(p['totalPrice'], 66.0);
    });

    test('fixed minimum floor wins when percentage is lower', () {
      // subtotal = 10 + 1*5 = 15; 10% = 1.5 < 5 fixed -> 5.
      final p = specPriceTrip(1.0, cfg());
      expect(p['commissionAmount'], 5.0);
      expect(p['driverNet'], 15.0);
      expect(p['totalPrice'], 20.0);
    });

    test('minFare floor applies before commission', () {
      // raw = 10 + 0.1*5 = 10.5 < 15 -> subtotal 15; 10% = 1.5 < 5 -> 5.
      final p = specPriceTrip(0.1, cfg());
      expect(p['driverNet'], 15.0);
      expect(p['commissionAmount'], 5.0);
    });

    test('invalid config and distance are rejected, never priced', () {
      expect(() => specPriceTrip(5.0, cfg(baseFare: -1)), throwsArgumentError);
      expect(() => specPriceTrip(-2.0, cfg()), throwsArgumentError);
      expect(() => specPriceTrip(600.0, cfg()), throwsArgumentError);
    });
  });

  group('no double pricing (trigger guards)', () {
    test('prices only pending + unlocked + unpriced docs', () {
      expect(specShouldPrice(status: 'pending', moneyLocked: false, serverPriced: false), isTrue);
      expect(specShouldPrice(status: 'accepted', moneyLocked: false, serverPriced: false), isFalse);
      expect(specShouldPrice(status: 'pending', moneyLocked: true, serverPriced: false), isFalse);
      expect(specShouldPrice(status: 'pending', moneyLocked: false, serverPriced: true), isFalse);
    });
  });

  group('missing driverNet at accept must not under-lock', () {
    test('null driverNet locks the full order amount (fail-closed)', () {
      expect(specInsuranceLock(250.0, null), 250.0);
      expect(specInsuranceLock(250.0, 0.0), 250.0);
    });

    test('present driverNet locks the remainder only', () {
      expect(specInsuranceLock(250.0, 200.0), 50.0);
    });
  });

  group('server e2e (emulator/live only, skipped by default)', () {
    test('post-pricing client update of money fields is rejected by rules', () async {
      // Requires: Firestore emulator with the deployed firestore.rules.
      // Steps: create pending specialRequests -> wait for pricingMeta.serverPriced
      // == true -> update({driverNet, totalPrice, commissionAmount, pricingMeta})
      // as a signed-in non-admin client -> expect permission-denied.
    }, skip: 'requires Firestore emulator + serverPriceDelivery trigger (e2e gate before deploy)');

    test('accepted-before-pricing locks full amount, no under-lock', () async {
      // Requires: emulator/live. Accept a pending doc before the pricing
      // trigger completes -> expect insurance lock == orderFinalAmount and no
      // settlement from client-supplied values.
    }, skip: 'requires Firestore emulator + serverPriceDelivery trigger (e2e gate before deploy)');
  }, skip: 'server e2e group: needs emulator/live backend; pure spec tests above always run');
}
