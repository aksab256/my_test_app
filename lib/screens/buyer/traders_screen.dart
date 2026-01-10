import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart' show rootBundle;

// استيراد الـ Widgets الخاصة بك
import '../../widgets/traders_header_widget.dart';
import '../../widgets/traders_list_widget.dart';
import '../../widgets/traders_filter_widget.dart';
import '../../widgets/chat_support_widget.dart';
import '../../widgets/buyer_mobile_nav_widget.dart';

class Coordinates {
  final double lat;
  final double lng;
  Coordinates({required this.lat, required this.lng});
}

class TradersScreen extends StatefulWidget {
  static const String routeName = '/traders';
  const TradersScreen({super.key});

  @override
  State<TradersScreen> createState() => _TradersScreenState();
}

class _TradersScreenState extends State<TradersScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final int _selectedIndex = 3; 

  String _searchQuery = '';
  String _currentFilter = 'all';
  List<DocumentSnapshot> _activeSellers = [];
  List<DocumentSnapshot> _filteredTraders = [];
  List<String> _categories = [];
  bool _isLoading = true;
  
  Coordinates? _userCoordinates;
  Map<String, List<Coordinates>> _areaCoordinatesMap = {};

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    
    // 1. تحميل المناطق أولاً (fetchAndProcessAdministrativeAreas)
    await _fetchAndProcessGeoJson();
    // 2. استخراج موقع المستخدم (USER LOCATION EXTRACTION)
    _userCoordinates = await _getUserLocation();
    // 3. تحميل التجار (loads function)
    await _loadTraders();

    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _fetchAndProcessGeoJson() async {
    try {
      final String jsonString = await rootBundle.loadString('assets/OSMB-bc319d822a17aa9ad1089fc05e7d4e752460f877.geojson');
      final data = json.decode(jsonString);
      if (data['features'] != null) {
        for (var feature in data['features']) {
          final areaName = feature['properties']?['name'];
          final geometry = feature['geometry'];
          if (areaName != null && geometry != null) {
            List polygonCoords = [];
            if (geometry['type'] == 'MultiPolygon') {
              polygonCoords = geometry['coordinates'][0][0];
            } else if (geometry['type'] == 'Polygon') {
              polygonCoords = geometry['coordinates'][0];
            }
            
            if (polygonCoords.length >= 3) {
              _areaCoordinatesMap[areaName] = polygonCoords.map<Coordinates>((coord) => 
                  Coordinates(lat: coord[1].toDouble(), lng: coord[0].toDouble())).toList();
            }
          }
        }
      }
    } catch (e) { debugPrint("GeoJSON Error: $e"); }
  }

  Future<Coordinates?> _getUserLocation() async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString('loggedUser');
    if (userJson == null) return null;
    final user = json.decode(userJson);
    final loc = user['location'];
    if (loc != null) {
      double? lat = (loc['lat'] ?? loc['latitude'])?.toDouble();
      double? lng = (loc['lng'] ?? loc['longitude'])?.toDouble();
      if (lat != null && lng != null) return Coordinates(lat: lat, lng: lng);
    }
    return null;
  }

  // 🔥 الدالة المقابلة تماماً لـ async function loads() في الـ HTML
  Future<void> _loadTraders() async {
    try {
      // البحث في مجموعة "sellers" كما في الـ HTML
      final snapshot = await _db.collection("sellers")
          .where("status", isEqualTo: "active").get();
      
      List<DocumentSnapshot> sellersServingArea = [];
      bool isBuyerLocationKnown = (_userCoordinates != null);

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final List? deliveryAreas = data['deliveryAreas'] as List?;

        // 🎯 منطق التصفية (نفس الـ HTML بالحرف):
        
        // الحالة 1: موقع المشتري غير معروف
        if (!isBuyerLocationKnown) {
          if (deliveryAreas == null || deliveryAreas.isEmpty) {
            sellersServingArea.add(doc); // توصيل شامل
          }
          continue;
        }

        // الحالة 2: موقع المشتري معروف
        // 2.1 التاجر يوصل توصيل شامل
        if (deliveryAreas == null || deliveryAreas.isEmpty) {
          sellersServingArea.add(doc);
          continue;
        }

        // 2.2 التاجر لديه مناطق توصيل محددة
        bool isAreaMatch = deliveryAreas.any((areaName) {
          final areaPolygon = _areaCoordinatesMap[areaName];
          if (areaPolygon != null && areaPolygon.length >= 3) {
            return _isPointInPolygon(_userCoordinates!, areaPolygon);
          }
          return false;
        });

        if (isAreaMatch) {
          sellersServingArea.add(doc);
        }
      }

      _activeSellers = sellersServingArea;
      _categories = _getUniqueCategories(_activeSellers);
      _applyFilters();
    } catch (e) { debugPrint("Load Error: $e"); }
  }

  List<String> _getUniqueCategories(List<DocumentSnapshot> sData) {
    final categories = <String>{};
    for (var doc in sData) {
      final businessType = (doc.data() as Map)['businessType'];
      if (businessType != null && businessType.toString().trim().isNotEmpty) {
        categories.add(businessType.toString().trim());
      } else {
        categories.add("أخرى");
      }
    }
    return categories.toList()..sort();
  }

  bool _isPointInPolygon(Coordinates point, List<Coordinates> polygon) {
    final x = point.lng; final y = point.lat;
    bool inside = false;
    for (int i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
      final xi = polygon[i].lng; final yi = polygon[i].lat;
      final xj = polygon[j].lng; final yj = polygon[j].lat;
      if (((yi > y) != (yj > y)) && (x < (xj - xi) * (y - yi) / (yj - yi) + xi)) inside = !inside;
    }
    return inside;
  }

  void _applyFilters() {
    if (!mounted) return;
    setState(() {
      _filteredTraders = _activeSellers.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final name = (data['merchantName'] ?? "تاجر غير معروف").toString().toLowerCase();
        final type = data['businessType']?.toString() ?? 'أخرى';
        return name.contains(_searchQuery.toLowerCase()) && 
               (_currentFilter == 'all' || type == _currentFilter);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // تأمين زر الرجوع لمنع الخروج
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        Navigator.pushReplacementNamed(context, '/buyerHome');
      },
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: const Color(0xFFf4f6f8),
          appBar: AppBar(
            elevation: 2,
            backgroundColor: const Color(0xFF4CAF50),
            title: const Text('التجار المعتمدون', 
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'Tajawal')),
            centerTitle: true,
          ),
          body: _isLoading 
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF4CAF50)))
            : Column(
                children: [
                  TradersHeaderWidget(
                    onSearch: (val) { _searchQuery = val; _applyFilters(); },
                    currentQuery: _searchQuery,
                  ),
                  TradersFilterWidget(
                    categories: _categories,
                    currentFilter: _currentFilter,
                    onFilterSelected: (val) { _currentFilter = val; _applyFilters(); },
                  ),
                  Expanded(
                    child: _filteredTraders.isEmpty 
                      ? const Center(child: Text("لا يوجد تجار معتمدون يخدمون منطقتك حالياً."))
                      : TradersListWidget(
                          traders: _filteredTraders,
                          onTraderTap: (doc) {
                            // نفس مسار الـ HTML: trader-offers.html?sellerId=...
                            Navigator.pushNamed(context, '/traderOffers', arguments: doc.id);
                          },
                        ),
                  ),
                ],
              ),
          bottomNavigationBar: BuyerMobileNavWidget(
            selectedIndex: _selectedIndex,
            onItemSelected: (index) {
              if (index == 1) Navigator.pushReplacementNamed(context, '/buyerHome');
              // أضف باقي المسارات هنا
            },
            cartCount: 0, 
            ordersChanged: false,
          ),
        ),
      ),
    );
  }
}
