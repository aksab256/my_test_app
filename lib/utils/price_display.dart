// lib/utils/price_display.dart
//
// Discount presentation shared by the buyer flow (product list modal,
// product details, trader offers, cart) so every surface shows the same
// "base struck-through + discount" contract:
//   - an offer discount exists only when offerPrice is a number above zero
//     (unit-level first, then document root — see OfferModel.fromFirestore).
//   - the buyer pays the discount when present, otherwise the base price.
//   - the cart strikes the base only when a stamped originalPrice exists
//     and is strictly higher than the charged price.

/// Effective discount value, or null when there is no usable discount.
double? discountPriceOrNull(dynamic offerPrice) {
  if (offerPrice is num && offerPrice > 0) return offerPrice.toDouble();
  return null;
}

/// True when the offer carries a usable discount price.
bool hasOfferDiscount(dynamic offerPrice) =>
    discountPriceOrNull(offerPrice) != null;

/// Base price coerced to double; non-numeric values (e.g. '?') become 0.0.
double basePriceOrZero(dynamic price) {
  if (price is num) return price.toDouble();
  return 0.0;
}

/// Price the buyer actually pays: discount first, then base price.
double payablePrice({
  required dynamic basePrice,
  required dynamic offerPrice,
}) {
  return discountPriceOrNull(offerPrice) ?? basePriceOrZero(basePrice);
}

/// True when the buyer would pay a positive amount for this unit.
/// Non-numeric bases (e.g. '?'), nulls, zeros and negatives are unpriced.
bool hasUsablePrice({
  required dynamic basePrice,
  required dynamic offerPrice,
}) {
  return payablePrice(basePrice: basePrice, offerPrice: offerPrice) > 0;
}

/// True when a raw productOffers document carries at least one priced unit.
///
/// Units are checked first (unit offerPrice, then the document root
/// offerPrice, then the unit base price — the same rule as
/// OfferModel.fromFirestore). Documents without a units list fall back to
/// the root price/offerPrice. Empty-units documents with no root price are
/// unpriced and must stay hidden from buyer surfaces.
bool hasPricedOfferDoc(Map<String, dynamic> data) {
  final dynamic units = data['units'];
  if (units is List && units.isNotEmpty) {
    for (final unit in units) {
      if (unit is Map) {
        final dynamic base = unit['price'];
        final dynamic offer = unit['offerPrice'] ?? data['offerPrice'];
        if (hasUsablePrice(basePrice: base, offerPrice: offer)) return true;
      }
    }
    return false;
  }
  return hasUsablePrice(
    basePrice: data['price'],
    offerPrice: data['offerPrice'],
  );
}

/// First positive chargeable amount on a raw productOffers document.
/// Mirrors [hasPricedOfferDoc]: the first priced unit wins, otherwise the
/// document root price. Returns 0.0 when nothing is priced.
double firstPricedAmount(Map<String, dynamic> data) {
  final dynamic units = data['units'];
  if (units is List && units.isNotEmpty) {
    for (final unit in units) {
      if (unit is Map) {
        final dynamic base = unit['price'];
        final dynamic offer = unit['offerPrice'] ?? data['offerPrice'];
        if (hasUsablePrice(basePrice: base, offerPrice: offer)) {
          return payablePrice(basePrice: base, offerPrice: offer);
        }
      }
    }
    return 0.0;
  }
  final amount = payablePrice(
    basePrice: data['price'],
    offerPrice: data['offerPrice'],
  );
  return amount < 0 ? 0.0 : amount;
}

/// Cart strike-through condition: a stamped original exists and is higher
/// than the charged price (set by CartProvider.loadCartAndRecalculate).
bool hasCartDiscount({
  required double price,
  required double? originalPrice,
}) {
  return originalPrice != null && originalPrice > price;
}
