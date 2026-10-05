import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:my_test_app/utils/offer_data_model.dart';
import 'package:my_test_app/utils/offer_geo_filter.dart';

class ProductOffersProvider with ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  final String productId;
  // 🎯 قائمة المناطق المكتشفة للمشتري بناءً على الـ GPS والـ GeoJSON.
  // مهم: ليست عنوان الشارع الحر (userAddress) — بل أسماء مناطق مطابقة
  // لنفس مفردات deliveryAreas/deliveryZones.
  final List<String> userDetectedAreas;

  // 🎯 سياق القائمة: productOffers (مع geo-filter) هو الافتراضي للحفاظ على
  // السلوك الحالي. sellerStore (بدون إعادة geo-filter) للاستخدام داخل متجر
  // Seller بعد فلترته جغرافيًا في TradersScreen.
  final OfferListContext geoContext;

  // 💡 المُنشئ لاستقبال المنتج والمناطق المكتشفة والسياق الصريح
  ProductOffersProvider({
    required this.productId,
    required this.userDetectedAreas,
    this.geoContext = OfferListContext.productOffers,
  }) {
    // جلب العروض فور إنشاء البروفايدر
    fetchOffers(productId, userDetectedAreas, geoContext: geoContext);
  }

  List<OfferModel> _availableOffers = [];
  OfferModel? _selectedOffer;
  bool _isLoading = true;
  int _currentQuantity = 0;

  List<OfferModel> get availableOffers => _availableOffers;
  OfferModel? get selectedOffer => _selectedOffer;
  bool get isLoading => _isLoading;
  int get currentQuantity => _currentQuantity;

  // 💥 دالة جلب العروض والفلترة الجغرافية المطابقة لبيانات Firestore
  Future<void> fetchOffers(
    String productId,
    List<String> detectedAreas, {
    OfferListContext geoContext = OfferListContext.productOffers,
  }) async {
    _isLoading = true;
    _availableOffers = [];
    _selectedOffer = null;
    notifyListeners();

    try {
      // 1. جلب العروض النشطة الخاصة بالمنتج من مجموعة productOffers
      final offersQuery = _db.collection('productOffers')
        .where('productId', isEqualTo: productId)
        .where('status', isEqualTo: 'active');

      final offersSnap = await offersQuery.get();
      List<OfferModel> filteredOffers = [];

      for (var doc in offersSnap.docs) {
        // تحويل المستند لنموذج OfferModel
        List<OfferModel> offersFromDoc = OfferModel.fromFirestore(doc);

        for (var offer in offersFromDoc) {
          // 🎯 قرار الظهور حسب السياق الصريح (offer_geo_filter.dart):
          // - sellerStore: يظهر دائمًا (الأهلية حُسمت عند مستوى الـSeller).
          // - productOffers: Global أو تطابق مع المناطق المكتشفة عبر GPS.
          final zones = [
            ...?offer.deliveryZones,
            ...?offer.deliveryAreas,
          ].toSet().toList();
          final visible = isOfferVisibleForBuyer(
            offerData: {
              'deliveryZones': zones,
            },
            buyerAreas: detectedAreas,
            context: geoContext,
          );

          if (visible) {
            filteredOffers.add(offer);
          }
        }
      }

      // 2. تحديث قائمة العروض المتاحة
      _availableOffers = filteredOffers;

      if (_availableOffers.isNotEmpty) {
        _selectedOffer = _availableOffers.first;
        _currentQuantity = _selectedOffer!.stock >= (_selectedOffer!.minQty ?? 1)
          ? (_selectedOffer!.minQty ?? 1)
          : 0;
      } else {
        _currentQuantity = 0;
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _availableOffers = [];
      _selectedOffer = null;
      _currentQuantity = 0;
      if (kDebugMode) {
        print('Error fetching and filtering offers: $e');
      }
      notifyListeners();
    }
  }

  void selectOffer(OfferModel offer) {
    _selectedOffer = offer;
    _currentQuantity = offer.stock >= (offer.minQty ?? 1)
      ? (offer.minQty ?? 1)
      : 0;
    notifyListeners();
  }

  void updateQuantity(int newQty) {
    _currentQuantity = newQty;
    notifyListeners();
  }
}
