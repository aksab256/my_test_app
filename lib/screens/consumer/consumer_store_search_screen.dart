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
import 'package:my_test_app/screens/special_requests/location_picker_screen.dart';

class ConsumerStoreSearchScreen extends StatefulWidget {
  static const routeName = '/consumerStoreSearch';
  const ConsumerStoreSearchScreen({super.key});

  @override
  State<ConsumerStoreSearchScreen> createState() => _ConsumerStoreSearchScreenState();
}

class _ConsumerStoreSearchScreenState extends State<ConsumerStoreSearchScreen> {
  LatLng? _currentSearchLocation;
  bool _isLoading = false;
  String _loadingMessage = 'جاري المسح الجغرافي...';
  List<Map<String, dynamic>> _nearbySupermarkets = [];
  List<Marker> _mapMarkers = [];
  final MapController _mapController = MapController();
  final double _searchRadiusKm = 5.0;
  final Distance distance = const Distance();

  // 🎨 الألوان المعتمدة (الأخضر المريح)
  final Color brandGreen = const Color(0xFF66BB6A); 
  final Color darkText = const Color(0xFF212121);
  
  // 🔑 Mapbox Access Token الخاص بك
  final String mapboxToken = 'pk.eyJ1IjoiYW1yc2hpcGwiLCJhIjoiY21lajRweGdjMDB0eDJsczdiemdzdXV6biJ9.E--si9vOB93NGcAq7uVgGw';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _promptLocationSelection());
  }

  // --- Logic البحث والموقع ---
  Future<Position?> _getCurrentLocation() async {
    setState(() { _isLoading = true; _loadingMessage = 'تحديد إحداثياتك...'; });
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
          throw Exception('يرجى تفعيل إذن الموقع');
        }
      }
      return await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
      return null;
    }
  }

  Future<void> _promptLocationSelection() async {
    final buyerDataProvider = Provider.of<BuyerDataProvider>(context, listen: false);
    final LatLng? registeredLocation = (buyerDataProvider.userLat != null && buyerDataProvider.userLng != null)
        ? LatLng(buyerDataProvider.userLat!, buyerDataProvider.userLng!)
        : null;

    final selectedOption = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildLocationSelectionSheet(registeredLocation != null),
    );

    if (selectedOption == 'current') {
      final position = await _getCurrentLocation();
      if (position != null) {
        _currentSearchLocation = LatLng(position.latitude, position.longitude);
        _searchAndDisplayStores(_currentSearchLocation!);
      }
    } else if (selectedOption == 'registered' && registeredLocation != null) {
      _currentSearchLocation = registeredLocation;
      _searchAndDisplayStores(_currentSearchLocation!);
    }
  }

  Future<void> _searchAndDisplayStores(LatLng location) async {
    setState(() { _isLoading = true; _loadingMessage = 'جاري رصد المتاجر...'; _nearbySupermarkets = []; _mapMarkers = []; });
    try {
      _mapController.move(location, 14.5);
      _mapMarkers.add(Marker(point: location, width: 80, height: 80, child: _buildUserLocationMarker()));

      final QuerySnapshot snapshot = await FirebaseFirestore.instance.collection('deliverySupermarkets').get();
      final List<Map<String, dynamic>> foundStores = [];

      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        LatLng? storeLoc;
        if (data['location'] is GeoPoint) {
          storeLoc = LatLng(data['location'].latitude, data['location'].longitude);
        } else if (data['location'] is Map) {
          storeLoc = LatLng(data['location']['lat'] as double, data['location']['lng'] as double);
        }

        if (storeLoc != null) {
          final distInKm = distance(location, storeLoc) / 1000;
          if (distInKm <= _searchRadiusKm) {
            final storeData = {'id': doc.id, ...data, 'location': storeLoc, 'distance': distInKm.toStringAsFixed(2)};
            foundStores.add(storeData);
            _mapMarkers.add(Marker(point: storeLoc, width: 60, height: 60, child: _buildStoreMarker(storeData)));
          }
        }
      }

      foundStores.sort((a, b) => double.parse(a['distance']).compareTo(double.parse(b['distance'])));
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
          title: Text('رادار البحث عن المحلات', 
            style: TextStyle(fontWeight: FontWeight.w900, color: darkText, fontSize: 19)),
          centerTitle: true,
        ),
        body: Stack(
          children: [
            // 🗺️ خريطة Mapbox ستايل Streets
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _currentSearchLocation ?? const LatLng(31.2001, 29.9187),
                initialZoom: 14.0,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://api.mapbox.com/styles/v1/mapbox/streets-v11/tiles/{z}/{x}/{y}?access_token={accessToken}',
                  additionalOptions: {'accessToken': mapboxToken},
                ),
                MarkerLayer(markers: _mapMarkers),
              ],
            ),

            // 📍 شريط معلومات البحث العلوي
            Positioned(top: 110, left: 15, right: 15, child: _buildRadarStatusCard()),

            // 🛒 قائمة المتاجر السفلية بخطوط 19
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
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 15, offset: const Offset(0, 5))],
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
                Text("يتم البحث في دائرة $_searchRadiusKm كم", style: TextStyle(fontSize: 14, color: Colors.grey[600], fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          IconButton(onPressed: _promptLocationSelection, icon: Icon(Icons.my_location, color: brandGreen, size: 28))
        ],
      ),
    );
  }

  Widget _buildBottomStoresCarousel() {
    if (_nearbySupermarkets.isEmpty) return const SizedBox.shrink();
    return Container(
      height: 200,
      margin: const EdgeInsets.only(bottom: 30),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 15),
        itemCount: _nearbySupermarkets.length,
        itemBuilder: (context, index) {
          final store = _nearbySupermarkets[index];
          return Container(
            width: MediaQuery.of(context).size.width * 0.85,
            margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(35),
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 20)],
            ),
            child: InkWell(
              onTap: () => _showStoreDetailSheet(store),
              borderRadius: BorderRadius.circular(35),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      width: 70, height: 70,
                      decoration: BoxDecoration(color: brandGreen.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                      child: Icon(Icons.storefront, color: brandGreen, size: 35),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(store['supermarketName'] ?? 'متجر',
                            maxLines: 1, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 19, color: darkText)), // 🎯 حجم 19
                          const SizedBox(height: 5),
                          Text("يبعد ${store['distance']} كم",
                            style: TextStyle(color: brandGreen, fontSize: 16, fontWeight: FontWeight.w900)),
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
            Text(store['supermarketName'], style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: darkText)),
            const SizedBox(height: 10),
            Text(store['address'] ?? "العنوان متاح داخل المتجر", 
              style: const TextStyle(fontSize: 17, color: Colors.grey, fontWeight: FontWeight.bold)),
            const SizedBox(height: 35),
            SizedBox(
              width: double.infinity,
              height: 65,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: brandGreen, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, MarketplaceHomeScreen.routeName, arguments: {'storeId': store['id'], 'storeName': store['supermarketName']});
                },
                child: const Text("دخول المتجر الآن", style: TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w900)),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildModernLoader() {
    return Container(
      color: Colors.white.withOpacity(0.85),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: brandGreen, strokeWidth: 5),
            const SizedBox(height: 25),
            Text(_loadingMessage, style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: brandGreen)),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationSelectionSheet(bool hasRegistered) {
    return Container(
      padding: const EdgeInsets.fromLTRB(25, 20, 25, 40),
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(35))),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 50, height: 5, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
          const SizedBox(height: 25),
          const Text("أين تبحث اليوم؟", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
          const SizedBox(height: 25),
          ListTile(
            leading: Icon(Icons.gps_fixed, color: brandGreen, size: 30),
            title: const Text("موقعي الحالي", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            onTap: () => Navigator.pop(context, 'current'),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: Colors.grey[200]!)),
          ),
          if (hasRegistered) ...[
            const SizedBox(height: 15),
            ListTile(
              leading: Icon(Icons.home, color: brandGreen, size: 30),
              title: const Text("عنواني المسجل", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
              onTap: () => Navigator.pop(context, 'registered'),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: Colors.grey[200]!)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildUserLocationMarker() => Icon(Icons.person_pin_circle, color: Colors.blue[800], size: 45);
  Widget _buildStoreMarker(Map<String, dynamic> store) => Icon(Icons.location_on, color: brandGreen, size: 40);
}

