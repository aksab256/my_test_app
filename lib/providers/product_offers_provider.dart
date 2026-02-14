import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:my_test_app/utils/offer_data_model.dart'; 

class ProductOffersProvider with ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String productId; 
  // 🎯 أضفنا متغير لتخزين منطقة المستخدم الحالية
  final String? userRegionId; 

  // 💡 تحديث المنشئ ليدعم استقبال منطقة المستخدم
  ProductOffersProvider({required this.productId, this.userRegionId}) {
    // نمرر منطقة المستخدم للدالة عند البدء
    fetchOffers(productId, userRegionId);
  }

  List<OfferModel> _availableOffers = [];
  OfferModel? _selectedOffer;                     
  bool _isLoading = true;                         
  int _currentQuantity = 0;
                                                  
  List<OfferModel> get availableOffers => _availableOffers;                                       
  OfferModel? get selectedOffer => _selectedOffer;                                                
  bool get isLoading => _isLoading;               
  int get currentQuantity => _currentQuantity;                                                                                                    
  
  // 💥 تحديث الدالة لتأخذ منطقة المستخدم (regionId)
  Future<void> fetchOffers(String productId, String? regionId) async {
    _isLoading = true;                              
    _availableOffers = [];                          
    _selectedOffer = null;
    notifyListeners(); 

    try {                                             
      // 1. نبدأ الاستعلام الأساسي
      Query offersQuery = _db.collection('productOffers')
        .where('productId', isEqualTo: productId)                                                       
        .where('status', isEqualTo: 'active');

      // 🎯 2. السطر السحري: إذا كانت المنطقة معروفة، هات فقط الموردين الذين يغطونها
      if (regionId != null && regionId.isNotEmpty) {
        offersQuery = offersQuery.where('deliveryZones', arrayContains: regionId);
      }
                                                      
      final offersSnap = await offersQuery.get();                                                     
      List<OfferModel> allOffers = [];
                                                      
      for (var doc in offersSnap.docs) {
        allOffers.addAll(OfferModel.fromFirestore(doc));
      }                                         
      
      _availableOffers = allOffers;             
      
      if (allOffers.isNotEmpty) {
        _selectedOffer = allOffers.first;               
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
        print('Error fetching offers: $e');
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
