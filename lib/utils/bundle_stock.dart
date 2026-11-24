// lib/utils/bundle_stock.dart
//
// Pure bundle stock math (no Firebase/Flutter).
// Integrates with the existing `productOffers.units[i]` source:
//
//   physicalStock   = total owned units for the offer/unit
//                     (= availableStock + reservedForPromos + reservedForBundles)
//   giftReserved    = units[i].reservedForPromos (gift-promo locks)
//   bundleReserved  = units[i].reservedForBundles (locks from other bundles)
//   available       = physical - giftReserved - bundleReserved
//                     (equals units[i].availableStock when counters are coherent)
//
// Task formula is preserved: `Available = Physical - Existing Reservations`,
// where existing reservations = gift + bundle locks, and the UI surfaces the
// bundle-reserved part in its own column.

/// One bundle line as seen by the stock calculator.
class BundleStockLine {
  /// Offer document id backing this line.
  final String offerId;

  /// Unit index inside `productOffers.units` (default 0).
  final int unitIndex;

  /// Display name (product + unit), used only for error messages.
  final String label;

  /// Total owned units.
  final int physicalStock;

  /// Units already locked by OTHER bundles.
  final int existingBundleReserved;

  /// Units locked by gift promos (shares the same physical pool).
  final int giftReserved;

  /// Units of this line consumed by ONE bundle.
  final int qtyRequired;

  const BundleStockLine({
    required this.offerId,
    this.unitIndex = 0,
    required this.label,
    required this.physicalStock,
    required this.existingBundleReserved,
    this.giftReserved = 0,
    required this.qtyRequired,
  });
}

/// Sellable units for one line after all existing locks.
int bundleLineAvailable(BundleStockLine line) {
  final int avail =
      line.physicalStock - line.giftReserved - line.existingBundleReserved;
  return avail < 0 ? 0 : avail;
}

/// Whole bundles buildable from ONE line (floor division, 0 when impossible).
int maxBundlesForLine(int available, int qtyRequired) {
  if (qtyRequired <= 0 || available <= 0) return 0;
  return available ~/ qtyRequired;
}

/// Whole bundles buildable from ALL lines (the limiting line wins).
int maxBundlesAcross(List<BundleStockLine> lines) {
  if (lines.isEmpty) return 0;
  int best = -1;
  for (final line in lines) {
    final int m =
        maxBundlesForLine(bundleLineAvailable(line), line.qtyRequired);
    if (best < 0 || m < best) best = m;
  }
  return best < 0 ? 0 : best;
}

/// Why a bundle draft cannot be created.
enum BundleBlockReason {
  /// Fewer than 2 or more than 5 distinct products.
  badItemCount,

  /// A line has qty <= 0.
  badQuantity,

  /// Same offer+unit picked twice.
  duplicateLine,

  /// At least one line needs more than its available stock.
  insufficientStock,
}

/// Frontend validation of a bundle draft (preview only, never a guarantee).
class BundleValidation {
  final bool canCreate;
  final BundleBlockReason? reason;
  final String? message;
  final int maxBundles;
  final String? limitingOfferId;

  const BundleValidation({
    required this.canCreate,
    this.reason,
    this.message,
    required this.maxBundles,
    this.limitingOfferId,
  });
}

BundleValidation validateBundleDraft(List<BundleStockLine> lines) {
  if (lines.length < 2 || lines.length > 5) {
    return BundleValidation(
      canCreate: false,
      reason: BundleBlockReason.badItemCount,
      message: 'اختر من منتجين إلى 5 منتجات مختلفة (الحالي: ${lines.length}).',
      maxBundles: 0,
    );
  }
  final seen = <String>{};
  for (final line in lines) {
    if (line.qtyRequired <= 0) {
      return BundleValidation(
        canCreate: false,
        reason: BundleBlockReason.badQuantity,
        message: 'كمية "${line.label}" يجب أن تكون 1 على الأقل.',
        maxBundles: 0,
      );
    }
    final key = '${line.offerId}||${line.unitIndex}';
    if (!seen.add(key)) {
      return BundleValidation(
        canCreate: false,
        reason: BundleBlockReason.duplicateLine,
        message: 'المنتج "${line.label}" مكرر — اختر منتجًا أو وحدة مختلفة.',
        maxBundles: 0,
      );
    }
  }
  int best = -1;
  String? limitingOfferId;
  String? limitingLabel;
  int? limitingAvail;
  int? limitingNeed;
  for (final line in lines) {
    final int avail = bundleLineAvailable(line);
    final int m = maxBundlesForLine(avail, line.qtyRequired);
    if (best < 0 || m < best) {
      best = m;
      limitingOfferId = line.offerId;
      limitingLabel = line.label;
      limitingAvail = avail;
      limitingNeed = line.qtyRequired;
    }
  }
  final int maxB = best < 0 ? 0 : best;
  if (maxB <= 0) {
    return BundleValidation(
      canCreate: false,
      reason: BundleBlockReason.insufficientStock,
      message: 'إنشاء البندل بهذه الكميات غير ممكن: '
          '"$limitingLabel" متاح منه $limitingAvail والمطلوب $limitingNeed لكل بندل.',
      maxBundles: 0,
      limitingOfferId: limitingOfferId,
    );
  }
  return BundleValidation(
    canCreate: true,
    maxBundles: maxB,
    limitingOfferId: limitingOfferId,
  );
}

/// Requested bundle-unit count vs the live computable maximum.
///
/// Independent from the product count and from per-bundle quantities:
/// `requested` is how many identical bundles the seller wants to offer.
class BundleCountCheck {
  final bool ok;
  final int requested;
  final int maxBundles;
  final String? limitingLabel;
  final int limitingAvail;
  final int limitingNeed;
  final String? message;

  const BundleCountCheck({
    required this.ok,
    required this.requested,
    required this.maxBundles,
    this.limitingLabel,
    this.limitingAvail = 0,
    this.limitingNeed = 0,
    this.message,
  });
}

BundleCountCheck validateBundleCount(
    {required List<BundleStockLine> lines, required int requested}) {
  BundleCountCheck fail(String message,
          {int max = 0,
          String? label,
          int avail = 0,
          int need = 0}) =>
      BundleCountCheck(
          ok: false,
          requested: requested,
          maxBundles: max,
          limitingLabel: label,
          limitingAvail: avail,
          limitingNeed: need,
          message: message);
  if (requested < 1) {
    return fail('عدد البندلات المتاحة للبيع يجب أن يكون 1 على الأقل.');
  }
  if (lines.length < 2 || lines.length > 5) {
    return fail(
        'اختر من منتجين إلى 5 منتجات مختلفة (الحالي: ${lines.length}).');
  }
  int best = -1;
  BundleStockLine? limiting;
  for (final line in lines) {
    if (line.qtyRequired <= 0) {
      return fail('كمية "${line.label}" يجب أن تكون 1 على الأقل.');
    }
    final int avail = bundleLineAvailable(line);
    final int m = maxBundlesForLine(avail, line.qtyRequired);
    if (best < 0 || m < best) {
      best = m;
      limiting = line;
    }
  }
  final int maxAll = best < 0 ? 0 : best;
  if (requested > maxAll) {
    final l = limiting!;
    final int avail = bundleLineAvailable(l);
    return fail(
      'الحد الأقصى $maxAll بندل — المنتج "${l.label}" يقيّد العدد '
      '(يحتاج ${l.qtyRequired} لكل بندل، المتاح $avail).',
      max: maxAll,
      label: l.label,
      avail: avail,
      need: l.qtyRequired,
    );
  }
  return BundleCountCheck(ok: true, requested: requested, maxBundles: maxAll);
}

/// Pricing summary: original sum vs bundle price.
class BundlePricing {
  final double originalTotal;
  final double bundlePrice;
  final double saving;

  const BundlePricing({
    required this.originalTotal,
    required this.bundlePrice,
    required this.saving,
  });
}

BundlePricing bundlePricing({
  required List<double> linePrices,
  required List<int> lineQuantities,
  required double bundlePrice,
}) {
  double original = 0;
  for (int i = 0; i < linePrices.length && i < lineQuantities.length; i++) {
    original += linePrices[i] * lineQuantities[i];
  }
  return BundlePricing(
    originalTotal: original,
    bundlePrice: bundlePrice,
    saving: original - bundlePrice,
  );
}
