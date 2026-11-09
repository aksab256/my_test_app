// lib/utils/gift_value.dart
//
// Pure helpers for the gift value quote shown to the seller while creating
// a gift promo, and snapshotted into the giftPromos document.
//
// quote = requiredPurchaseValue (sum of trigger lines) vs giftValue,
// percentage = giftValue / requiredPurchaseValue * 100 (informational only,
// never a discount on the buyer's invoice).
//
// When a unit price is missing the quote is explicitly unavailable
// (value_unavailable) — never an invented number.

/// Result of a gift value quote. Null numbers mean unavailable.
class GiftValueQuote {
  final double? requiredPurchaseValue;
  final double? giftValue;
  final double? percentage;
  final bool available;

  const GiftValueQuote._({
    this.requiredPurchaseValue,
    this.giftValue,
    this.percentage,
    required this.available,
  });

  const GiftValueQuote.unavailable()
      : this._(available: false);

  const GiftValueQuote.available({
    required double requiredPurchaseValue,
    required double giftValue,
    required double percentage,
  }) : this._(
          requiredPurchaseValue: requiredPurchaseValue,
          giftValue: giftValue,
          percentage: percentage,
          available: true,
        );
}

/// Single-product quote: buy [triggerQty] of a unit priced [triggerUnitPrice],
/// get [giftQty] of a unit priced [giftUnitPrice].
GiftValueQuote quoteSingleGiftValue({
  double? triggerUnitPrice,
  required int triggerQty,
  double? giftUnitPrice,
  required int giftQty,
}) {
  if (triggerUnitPrice == null ||
      giftUnitPrice == null ||
      triggerQty <= 0 ||
      giftQty <= 0) {
    return const GiftValueQuote.unavailable();
  }
  final req = triggerUnitPrice * triggerQty;
  final gv = giftUnitPrice * giftQty;
  if (req <= 0) {
    if (gv <= 0) {
      return const GiftValueQuote.available(
        requiredPurchaseValue: 0,
        giftValue: 0,
        percentage: 0,
      );
    }
    return const GiftValueQuote.unavailable();
  }
  return GiftValueQuote.available(
    requiredPurchaseValue: req,
    giftValue: gv,
    percentage: gv / req * 100,
  );
}

/// AND quote: sum of several trigger lines vs one gift line.
GiftValueQuote quoteAndGiftValue({
  required List<({double? unitPrice, int qty})> triggerLines,
  double? giftUnitPrice,
  required int giftQty,
}) {
  if (triggerLines.isEmpty || giftUnitPrice == null || giftQty <= 0) {
    return const GiftValueQuote.unavailable();
  }
  double req = 0;
  for (final line in triggerLines) {
    if (line.unitPrice == null || line.qty <= 0) {
      return const GiftValueQuote.unavailable();
    }
    req += line.unitPrice! * line.qty;
  }
  final gv = giftUnitPrice * giftQty;
  if (req <= 0) {
    if (gv <= 0) {
      return const GiftValueQuote.available(
        requiredPurchaseValue: 0,
        giftValue: 0,
        percentage: 0,
      );
    }
    return const GiftValueQuote.unavailable();
  }
  return GiftValueQuote.available(
    requiredPurchaseValue: req,
    giftValue: gv,
    percentage: gv / req * 100,
  );
}
