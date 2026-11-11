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

/// Cart strike-through condition: a stamped original exists and is higher
/// than the charged price (set by CartProvider.loadCartAndRecalculate).
bool hasCartDiscount({
  required double price,
  required double? originalPrice,
}) {
  return originalPrice != null && originalPrice > price;
}
