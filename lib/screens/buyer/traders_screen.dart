import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart' show rootBundle;

// استيراد الـ Widgets الخاصة بك
import '../../widgets/traders_header_widget.dart';
import '../../widgets/traders_list_widget.dart';
import '../../widgets/traders_filter_widget.dart';
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
  final int _selectedIndex = 3; // ترتيب أيقونة التجار في الـ Nav

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
    
    await _fetchAndProcessGeoJson();
    _userCoordinates = await _getUserLocation();
    await _loadTraders();

    if (mounted) setState(() => _isLoading = false);
  }

  // منطق معالجة المناطق الجغرافية (Polygon Data)
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

  // تحميل التجار بناءً على منطق التغطية الجغرافية
  Future<void> _loadTraders() async {
    try {
      final snapshot = await _db.collection("sellers")
          .where("status", isEqualTo: "active").get();
      
      List<DocumentSnapshot> sellersServingArea = [];
      bool isBuyerLocationKnown = (_userCoordinates != null);

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final List? deliveryAreas = data['deliveryAreas'] as List?;

        // الحالة 1: موقع المشتري غير معروف -> يعرض من يقدم توصيل شامل
        if (!isBuyerLocationKnown) {
          if (deliveryAreas == null || deliveryAreas.isEmpty) {
            sellersServingArea.add(doc);
          }
          continue;
        }

        // الحالة 2: موقع المشتري معروف -> فحص التغطية الجغرافية
        if (deliveryAreas == null || deliveryAreas.isEmpty) {
          sellersServingArea.add(doc); // توصيل شامل
          continue;
        }

        bool isAreaMatch = deliveryAreas.any((areaName) {
          final areaPolygon = _areaCoordinatesMap[areaName];
          if (areaPolygon != null && areaPolygon.length >= 3) {
            return _isPointInPolygon(_userCoordinates!, areaPolygon);
          }
          return false;
        });

        if (isAreaMatch) sellersServingArea.add(doc);
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
        final name = (data['merchantName'] ?? "").toString().toLowerCase();
        final type = data['businessType']?.toString() ?? 'أخرى';
        return name.contains(_searchQuery.toLowerCase()) && 
               (_currentFilter == 'all' || type == _currentFilter);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        Navigator.pushReplacementNamed(context, '/buyerHome');
      },
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: const Color(0xFFF8F9FA),
          appBar: AppBar(
            elevation: 0,
            flexibleSpace: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF4CAF50), Color(0xFF388E3C)],
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                ),
              ),
            ),
            title: const Text('التجار المعتمدون', 
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontFamily: 'Tajawal')),
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
                      ? _buildEmptyState()
                      : TradersListWidget(
                          traders: _filteredTraders,
                          onTraderTap: (doc) {
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
              if (index == 2) Navigator.pushNamed(context, '/myOrders');
            },
            cartCount: 0, 
            ordersChanged: false,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.storefront_outlined, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          const Text("لا يوجد تجار معتمدون يخدمون منطقتك حالياً.",
            style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 16)),
        ],
      ),
    );
  }
}
