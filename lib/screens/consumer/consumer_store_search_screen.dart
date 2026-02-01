// lib/screens/consumer/consumer_store_search_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' show LatLng, Distance;
import 'package:provider/provider.dart';
import 'package:sizer/sizer.dart';
import 'package:my_test_app/providers/buyer_data_provider.dart';
import 'package:my_test_app/screens/consumer/MarketplaceHomeScreen.dart';

class ConsumerStoreSearchScreen extends StatefulWidget {
  static const routeName = '/consumerStoreSearch';
  const ConsumerStoreSearchScreen({super.key});

  @override
  State<ConsumerStoreSearchScreen> createState() => _ConsumerStoreSearchScreenState();
}

class _ConsumerStoreSearchScreenState extends State<ConsumerStoreSearchScreen> {
  final MapController _mapController = MapController();
  LatLng? _currentSearchLocation;
  bool _isLoading = false;
  String _loadingMessage = 'جاري المسح الجغرافي...';
  List<Map<String, dynamic>> _nearbySupermarkets = [];
  List<Marker> _mapMarkers = [];

  final double _searchRadiusKm = 5.0;
  final Distance distance = const Distance();
  final Color brandGreen = const Color(0xFF66BB6A);
  final Color darkText = const Color(0xFF212121);
  final String mapboxToken = 'pk.eyJ1IjoiYW1yc2hpcGwiLCJhIjoiY21lajRweGdjMDB0eDJsczdiemdzdXV6biJ9.E--si9vOB93NGcAq7uVgGw';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _promptLocationSelection());
  }

  Map<String, dynamic> _getStoreStyle(String? type) {
    switch (type) {
      case 'restaurant':
        return {'icon': Icons.fastfood_rounded, 'color': Colors.orange.shade700};
      case 'pharmacy':
        return {'icon': Icons.local_pharmacy_rounded, 'color': Colors.blue.shade600};
      case 'vegetables':
        return {'icon': Icons.eco_rounded, 'color': Colors.green.shade700};
      case 'butcher':
        return {'icon': Icons.kebab_dining_rounded, 'color': Colors.red.shade700};
      case 'houseware':
        return {'icon': Icons.clean_hands_rounded, 'color': Colors.teal.shade600};
      case 'supermarket':
      default:
        return {'icon': Icons.shopping_basket_rounded, 'color': const Color(0xFF2D9E68)};
    }
  }

  String _getStoreTypeName(String? id) {
    switch (id) {
      case 'restaurant': return 'مطعم / كافيه';
      case 'pharmacy': return 'صيدلية';
      case 'vegetables': return 'خضروات وفاكهة';
      case 'butcher': return 'جزارة / دواجن';
      case 'houseware': return 'أدوات منزلية ومنظفات';
      default: return 'سوبر ماركت';
    }
  }

  Future<void> _promptLocationSelection() async {
    final buyerDataProvider = Provider.of<BuyerDataProvider>(context, listen: false);
    final bool hasValidRegisteredLocation = (buyerDataProvider.userLat != null && 
                                             buyerDataProvider.userLng != null && 
                                             buyerDataProvider.userLat != 0);

    final selectedOption = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      builder: (context) => _buildLocationSelectionSheet(hasValidRegisteredLocation),
    );

    if (selectedOption == 'current') {
      final position = await _getCurrentLocation();
      if (position != null) {
        _currentSearchLocation = LatLng(position.latitude, position.longitude);
        _searchAndDisplayStores(_currentSearchLocation!);
      }
    } else if (selectedOption == 'registered' && hasValidRegisteredLocation) {
      _currentSearchLocation = LatLng(buyerDataProvider.userLat!, buyerDataProvider.userLng!);
      _searchAndDisplayStores(_currentSearchLocation!);
    }
  }

  Future<Position?> _getCurrentLocation() async {
    setState(() { _isLoading = true; _loadingMessage = 'تحديد موقعك...'; });
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      return await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    } catch (e) { return null; }
  }

  // --- الدالة المعدلة بالكامل لتطبيق الفلترة الصارمة ---
  Future<void> _searchAndDisplayStores(LatLng location) async {
    setState(() { _isLoading = true; _loadingMessage = 'جاري رصد المتاجر...'; });
    try {
      _mapController.move(location, 14.5);
      _mapMarkers.clear();
      _mapMarkers.add(Marker(point: location, width: 80, height: 80, child: _buildUserLocationMarker()));

      // الاستعلام مع شروط الحالة الأساسية
      final QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('deliverySupermarkets')
          .where('isActive', isEqualTo: true)
          .where('isVisibleInStore', isEqualTo: true)
          .get();

      final List<Map<String, dynamic>> foundStores = [];
      final now = DateTime.now();

      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;

        // 1. فلاتر الصرامة: استبعاد البيانات الناقصة أو المنتهية
        if (data['trialExpiryDate'] == null) continue; // استبعاد لو مفيش تاريخ انتهاء
        
        final DateTime expiry = (data['trialExpiryDate'] as Timestamp).toDate();
        if (expiry.isBefore(now)) continue; // استبعاد لو الصلاحية انتهت

        LatLng? storeLoc;
        if (data['location'] is GeoPoint) {
          storeLoc = LatLng(data['location'].latitude, data['location'].longitude);
        } else if (data['location'] is Map) {
          storeLoc = LatLng(data['location']['lat'] as double, data['location']['lng'] as double);
        }

        if (storeLoc != null) {
          final distInKm = distance(location, storeLoc) / 1000;
          if (distInKm <= _searchRadiusKm) {
            final storeData = {
              'id': doc.id,
              ...data,
              'location': storeLoc,
              'distance': distInKm.toStringAsFixed(2),
              'storeType': data['storeType'] ?? 'supermarket' 
            };
            foundStores.add(storeData);
            _mapMarkers.add(Marker(
              point: storeLoc,
              width: 60,
              height: 60,
              child: _buildStoreMarker(storeData),
            ));
          }
        }
      }
      setState(() { _nearbySupermarkets = foundStores; _isLoading = false; });
    } catch (e) { setState(() { _isLoading = false; }); }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.white.withOpacity(0.9),
          elevation: 2,
          toolbarHeight: 70,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios, color: brandGreen, size: 28),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text('رادار المحلات القريبة',
              style: TextStyle(fontWeight: FontWeight.w900, color: Colors.black, fontSize: 19)),
          centerTitle: true,
        ),
        body: Stack(
          children: [
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _currentSearchLocation ?? const LatLng(31.2001, 29.9187),
                initialZoom: 13.0,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://api.mapbox.com/styles/v1/mapbox/streets-v11/tiles/{z}/{x}/{y}?access_token={accessToken}',
                  additionalOptions: {'accessToken': mapboxToken},
                ),
                MarkerLayer(markers: _mapMarkers),
              ],
            ),
            Positioned(top: 115, left: 15, right: 15, child: _buildRadarStatusCard()),
            Positioned(bottom: 0, left: 0, right: 0, child: _buildBottomStoresCarousel()),
            if (_isLoading) _buildModernLoader(),
          ],
        ),
      ),
    );
  }

  Widget _buildRadarStatusCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 15)],
      ),
      child: Row(
        children: [
          Icon(Icons.radar, color: brandGreen, size: 30),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("نطاق البحث الذكي", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: darkText)),
                Text("تغطية $_searchRadiusKm كم", style: const TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _promptLocationSelection(),
            icon: Icon(Icons.my_location, color: brandGreen, size: 28),
          )
        ],
      ),
    );
  }

  Widget _buildBottomStoresCarousel() {
    if (_nearbySupermarkets.isEmpty) return const SizedBox.shrink();
    return Container(
      height: 170, 
      margin: const EdgeInsets.only(bottom: 25),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 15),
        itemCount: _nearbySupermarkets.length,
        itemBuilder: (context, index) {
          final store = _nearbySupermarkets[index];
          final style = _getStoreStyle(store['storeType']);
          
          return Container(
            width: 270,
            margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(25),
              border: Border(right: BorderSide(color: style['color'], width: 6)),
              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 15)],
            ),
            child: InkWell(
              onTap: () => _showStoreDetailSheet(store),
              borderRadius: BorderRadius.circular(25),
              child: Padding(
                padding: const EdgeInsets.all(15),
                child: Row(
                  children: [
                    Container(
                      width: 65, height: 65,
                      decoration: BoxDecoration(
                        color: (style['color'] as Color).withOpacity(0.1), 
                        borderRadius: BorderRadius.circular(18)
                      ),
                      child: Icon(style['icon'], color: style['color'], size: 32),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(store['supermarketName'] ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
                          Text(_getStoreTypeName(store['storeType']), 
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 12, fontWeight: FontWeight.bold)),
                          Text("يبعد ${store['distance']} كم",
                              style: TextStyle(color: style['color'], fontWeight: FontWeight.bold, fontSize: 14)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showStoreDetailSheet(Map<String, dynamic> store) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(35),
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(40))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(store['supermarketName'], style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
            Text(_getStoreTypeName(store['storeType']), style: const TextStyle(color: Colors.grey, fontSize: 16)),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: brandGreen, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, MarketplaceHomeScreen.routeName, arguments: {'storeId': store['id'], 'storeName': store['supermarketName']});
                },
                child: const Text("دخول المتجر", style: TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w900)),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildModernLoader() {
    return Container(
      color: Colors.white.withOpacity(0.8),
      child: Center(child: CircularProgressIndicator(color: brandGreen)),
    );
  }

  Widget _buildLocationSelectionSheet(bool hasRegistered) {
    return Container(
      padding: const EdgeInsets.all(25),
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text("تحديد موقع البحث", style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
          const SizedBox(height: 20),
          ListTile(
            leading: Icon(Icons.my_location, color: brandGreen),
            title: const Text("موقعي الحالي", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            onTap: () => Navigator.pop(context, 'current'),
          ),
          if (hasRegistered)
            ListTile(
              leading: Icon(Icons.home, color: brandGreen),
              title: const Text("عنواني المسجل", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              onTap: () => Navigator.pop(context, 'registered'),
            ),
        ],
      ),
    );
  }

  Widget _buildUserLocationMarker() => const Icon(Icons.person_pin_circle, color: Colors.blue, size: 50);

  Widget _buildStoreMarker(Map<String, dynamic> store) {
    final style = _getStoreStyle(store['storeType']);
    return Icon(style['icon'], color: style['color'], size: 40);
  }
}
