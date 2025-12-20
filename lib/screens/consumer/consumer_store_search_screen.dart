// lib/screens/consumer/consumer_store_search_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' show LatLng, Distance;
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
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
  String _loadingMessage = 'اضغط على الموقع لبدء المسح الجغرافي';
  List<Map<String, dynamic>> _nearbySupermarkets = [];
  List<Marker> _mapMarkers = [];
  final MapController _mapController = MapController();
  final double _searchRadiusKm = 5.0;
  final LatLng _defaultLocation = const LatLng(31.2001, 29.9187);
  final Distance distance = const Distance();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _promptLocationSelection();
    });
  }

  Future<Position?> _getCurrentLocation() async {
    setState(() {
      _isLoading = true;
      _loadingMessage = 'جاري تحديد إحداثياتك الحالية...';
    });
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
          throw Exception('يرجى تفعيل إذن الموقع يدوياً');
        }
      }
      return await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: ${e.toString()}')));
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
    } else {
      _mapController.move(_defaultLocation, 12);
      setState(() { _isLoading = false; });
    }
  }

  Future<void> _searchAndDisplayStores(LatLng location) async {
    setState(() {
      _isLoading = true;
      _loadingMessage = 'جاري مسح المنطقة المحيطة...';
      _nearbySupermarkets = [];
      _mapMarkers = [];
    });
    try {
      _mapController.move(location, 14.5);
      _mapMarkers.add(Marker(
        point: location,
        width: 60, height: 60,
        child: _buildUserLocationMarker(),
      ));

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
            final storeData = {
              'id': doc.id,
              ...data,
              'location': storeLoc,
              'distance': distInKm.toStringAsFixed(2),
            };
            foundStores.add(storeData);
            _mapMarkers.add(Marker(
              point: storeLoc,
              width: 50, height: 50,
              child: _buildStoreMarker(storeData),
            ));
          }
        }
      }

      foundStores.sort((a, b) => double.parse(a['distance']).compareTo(double.parse(b['distance'])));

      setState(() {
        _nearbySupermarkets = foundStores;
        _isLoading = false;
        _loadingMessage = foundStores.isEmpty ? 'لا توجد متاجر قريبة' : 'تم العثور على ${foundStores.length} متاجر';
      });
    } catch (e) {
      setState(() { _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    // ⭐️ [تعديل]: جلب المعرف الصحيح بناءً على ملف الـ Provider
    final buyerProvider = Provider.of<BuyerDataProvider>(context);
    final String userId = buyerProvider.currentUserId ?? 'guest';

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          title: const Text('اكتشف المتاجر', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: Stack(
          children: [
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _currentSearchLocation ?? _defaultLocation,
                initialZoom: 13.0,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
                  userAgentPackageName: 'com.example.app',
                ),
                MarkerLayer(markers: _mapMarkers),
              ],
            ),
            Positioned(
              top: 110, left: 20, right: 20,
              child: _buildFloatingActionHeader(),
            ),
            
            // ⭐️ [تعديل]: رفع الزر ليكون فوق قائمة المتاجر بوضوح
            Positioned(
              bottom: 255, 
              left: 20,
              child: FloatingActionButton.extended(
                onPressed: () {
                  if (_currentSearchLocation != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => LocationPickerScreen(
                          initialLocation: _currentSearchLocation!,
                          title: "ابعتلي حد",
                          userId: userId, // تمرير المعرف المأخوذ من currentUserId
                        ),
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("يرجى تحديد موقعك أولاً لتفعيل الخدمة")),
                    );
                  }
                },
                label: const Text("ابعتلي حد", style: TextStyle(fontWeight: FontWeight.bold)),
                icon: const Icon(Icons.directions_run_rounded, color: Colors.white),
                backgroundColor: Colors.orange[800],
                elevation: 10,
              ),
            ),
            
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: _buildStoresPreviewList(),
            ),
            if (_isLoading) _buildLoadingOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingActionHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Row(
        children: [
          Icon(Icons.location_on, color: Theme.of(context).primaryColor),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _currentSearchLocation == null ? "حدد موقعك للبحث" : "يتم البحث في نطاق $_searchRadiusKm كم",
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
          IconButton(
            onPressed: _promptLocationSelection,
            icon: CircleAvatar(
              backgroundColor: Theme.of(context).primaryColor,
              child: const Icon(Icons.my_location, color: Colors.white, size: 20),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildStoresPreviewList() {
    if (_nearbySupermarkets.isEmpty) return const SizedBox.shrink();
    return SafeArea(
      top: false,
      child: Container(
        height: 180,
        margin: const EdgeInsets.only(bottom: 35),
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 15),
          itemCount: _nearbySupermarkets.length,
          itemBuilder: (context, index) {
            final store = _nearbySupermarkets[index];
            return _buildStoreSmallCard(store);
          },
        ),
      ),
    );
  }

  Widget _buildStoreSmallCard(Map<String, dynamic> store) {
    return Container(
      width: 280,
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 15, offset: const Offset(0, 5))],
      ),
      child: InkWell(
        onTap: () => _showStoreDetailsBottomSheet(store),
        borderRadius: BorderRadius.circular(25),
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Row(
            children: [
              Container(
                width: 60, height: 60,
                decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(15)),
                child: const Icon(Icons.storefront_rounded, color: Colors.green, size: 30),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(store['supermarketName'] ?? 'متجر', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    Text("${store['distance']} كم بعيداً عنك", style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUserLocationMarker() {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(width: 40, height: 40, decoration: BoxDecoration(color: Colors.blue.withOpacity(0.2), shape: BoxShape.circle)),
        Container(width: 15, height: 15, decoration: const BoxDecoration(color: Colors.blue, shape: BoxShape.circle, border: Border.fromBorderSide(BorderSide(color: Colors.white, width: 2)))),
      ],
    );
  }

  Widget _buildStoreMarker(Map<String, dynamic> store) {
    return GestureDetector(
      onTap: () => _showStoreDetailsBottomSheet(store),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 5)]),
            child: const Icon(Icons.shopping_basket, color: Colors.green, size: 20),
          ),
          const Icon(Icons.arrow_drop_down, color: Colors.white, size: 25),
        ],
      ),
    );
  }

  Widget _buildLoadingOverlay() {
    return Container(
      color: Colors.black26,
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(30),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 20),
              Text(_loadingMessage, style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLocationSelectionSheet(bool hasRegistered) {
    return Container(
      padding: const EdgeInsets.all(25),
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
          const SizedBox(height: 20),
          const Text("اختر نقطة البحث الجغرافي", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 25),
          _buildLocationOption(icon: Icons.my_location, title: "موقعي الحالي الآن", subtitle: "البحث حول إحداثيات GPS الحالية", onTap: () => Navigator.pop(context, 'current')),
          if (hasRegistered) ...[
            const SizedBox(height: 15),
            _buildLocationOption(icon: Icons.home_rounded, title: "عنواني المُسجل", subtitle: "البحث حول موقعك الافتراضي في الملف الشخصي", onTap: () => Navigator.pop(context, 'registered')),
          ],
        ],
      ),
    );
  }

  Widget _buildLocationOption({required IconData icon, required String title, required String subtitle, required VoidCallback onTap}) {
    return ListTile(
      leading: CircleAvatar(backgroundColor: Colors.green.withOpacity(0.1), child: Icon(icon, color: Colors.green)),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: BorderSide(color: Colors.grey[200]!)),
    );
  }

  void _showStoreDetailsBottomSheet(Map<String, dynamic> store) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StoreDetailsBottomSheet(store: store),
    );
  }
}

class StoreDetailsBottomSheet extends StatelessWidget {
  final Map<String, dynamic> store;
  const StoreDetailsBottomSheet({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(25),
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.storefront_rounded, color: Colors.green, size: 30),
              const SizedBox(width: 15),
              Expanded(child: Text(store['supermarketName'] ?? 'المتجر', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold))),
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
            ],
          ),
          const Divider(),
          _buildInfoRow(Icons.location_on_outlined, store['address'] ?? 'العنوان غير متاح'),
          _buildInfoRow(Icons.directions_walk, "يبعد عنك مسافة ${store['distance']} كم"),
          const SizedBox(height: 25),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.of(context).pushNamed(MarketplaceHomeScreen.routeName, arguments: {'storeId': store['id'], 'storeName': store['supermarketName']});
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green, padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            ),
            child: const Text("دخول المتجر وتصفح العروض 🔥", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey, size: 20),
          const SizedBox(width: 15),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 15))),
        ],
      ),
    );
  }
}
