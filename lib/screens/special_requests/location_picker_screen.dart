import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'dart:convert'; // لإدارة بيانات JSON
import 'package:http/http.dart' as http; // البديل المتوافق مع إصدارك
import 'package:sizer/sizer.dart';
import '../../services/delivery_service.dart';

enum PickerStep { pickup, dropoff, confirm }

class LocationPickerScreen extends StatefulWidget {
  static const routeName = '/location-picker';
  final LatLng? initialLocation;
  final String title;

  const LocationPickerScreen({super.key, this.initialLocation, this.title = "تحديد الموقع"});

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  final Completer<GoogleMapController> _mapController = Completer<GoogleMapController>();
  final DeliveryService _deliveryService = DeliveryService();
  final TextEditingController _detailsController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  // الإعدادات الخاصة بـ Google Maps API
  final String _apiKey = "AIzaSyB4Nu0SHkkoSQi9gMjxNK5pfnqbKSrS5fg";
  List<dynamic> _searchResults = [];

  PickerStep _currentStep = PickerStep.pickup;
  late LatLng _currentMapCenter;

  LatLng? _pickupLocation;
  String _pickupAddress = "جاري جلب العنوان...";
  LatLng? _dropoffLocation;
  String _dropoffAddress = "";

  double _estimatedPrice = 0.0;
  Map<String, double> _pricingDetails = {'totalPrice': 0.0, 'commissionAmount': 0.0, 'driverNet': 0.0};
  String _tempAddress = "جاري تحديد الموقع...";
  bool _isLoading = false;
  bool _isMapLoading = true;
  MapType _currentMapType = MapType.normal;

  final List<Map<String, dynamic>> _vehicles = [
    {"id": "motorcycle", "name": "موتوسيكل", "icon": Icons.directions_bike},
    {"id": "pickup", "name": "ربع نقل", "icon": Icons.local_shipping},
    {"id": "jumbo", "name": "جامبو", "icon": Icons.fire_truck},
  ];
  String _selectedVehicle = "motorcycle";

  @override
  void initState() {
    super.initState();
    _currentMapCenter = widget.initialLocation ?? const LatLng(30.0444, 31.2357);
    _determinePosition();
  }

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  Future<void> _determinePosition() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() => _isMapLoading = false);
        return;
      }
    }
    try {
      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      LatLng myLocation = LatLng(position.latitude, position.longitude);
      _moveCamera(myLocation);
      await _getAddress(myLocation);
      setState(() {
        _currentMapCenter = myLocation;
        _isMapLoading = false;
      });
    } catch (e) {
      setState(() => _isMapLoading = false);
    }
  }

  Future<void> _moveCamera(LatLng target) async {
    final GoogleMapController controller = await _mapController.future;
    controller.animateCamera(CameraUpdate.newLatLngZoom(target, 16));
  }

  Future<void> _getAddress(LatLng position) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        if (mounted) {
          setState(() {
            _tempAddress = "${place.street ?? ''} ${place.subLocality ?? ''} ${place.locality ?? ''}".trim();
            if (_tempAddress.isEmpty) _tempAddress = "موقع مخصص";
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() => _tempAddress = "نقطة على الخريطة");
    }
  }

  // --- نظام البحث الذكي المدمج (Native Search) ---
  void _openSearch() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => _buildSearchSheet(),
    );
  }

  Widget _buildSearchSheet() {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => StatefulBuilder(
        builder: (context, setModalState) => Column(
          children: [
            Container(margin: const EdgeInsets.symmetric(vertical: 10), height: 5, width: 40, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
            Padding(
              padding: const EdgeInsets.all(15),
              child: TextField(
                autofocus: true,
                style: const TextStyle(fontFamily: 'Cairo'),
                decoration: InputDecoration(
                  hintText: "ابحث عن مكان في مصر...",
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: Colors.grey[100],
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                ),
                onChanged: (value) async {
                  if (value.length > 2) {
                    final url = Uri.parse('https://maps.googleapis.com/maps/api/place/autocomplete/json?input=$value&key=$_apiKey&language=ar&components=country:eg');
                    final response = await http.get(url);
                    if (response.statusCode == 200) {
                      final data = json.decode(response.body);
                      if (data['status'] == 'OK') {
                        setModalState(() => _searchResults = data['predictions']);
                      }
                    }
                  }
                },
              ),
            ),
            Expanded(
              child: ListView.separated(
                controller: scrollController,
                itemCount: _searchResults.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final prediction = _searchResults[index];
                  return ListTile(
                    leading: const Icon(Icons.location_on_outlined, color: Colors.blue),
                    title: Text(prediction['description'] ?? "", style: const TextStyle(fontFamily: 'Cairo', fontSize: 13)),
                    onTap: () async {
                      Navigator.pop(context);
                      setState(() => _isLoading = true);
                      final detailUrl = Uri.parse('https://maps.googleapis.com/maps/api/place/details/json?place_id=${prediction['place_id']}&fields=geometry&key=$_apiKey');
                      final res = await http.get(detailUrl);
                      if (res.statusCode == 200) {
                        final data = json.decode(res.body);
                        final loc = data['result']['geometry']['location'];
                        LatLng newPos = LatLng(loc['lat'], loc['lng']);
                        _moveCamera(newPos);
                        setState(() {
                          _currentMapCenter = newPos;
                          _tempAddress = prediction['description'];
                        });
                      }
                      setState(() => _isLoading = false);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleNextStep() async {
    if (_currentStep == PickerStep.pickup) {
      _pickupLocation = _currentMapCenter;
      _pickupAddress = _tempAddress;
      setState(() {
        _currentStep = PickerStep.dropoff;
        _tempAddress = "حدد وجهة التوصيل...";
      });
    } else if (_currentStep == PickerStep.dropoff) {
      _dropoffLocation = _currentMapCenter;
      _dropoffAddress = _tempAddress;
      await _updatePricing(_selectedVehicle);
      _showFinalConfirmation();
    }
  }

  Future<void> _updatePricing(String vehicleType) async {
    if (_pickupLocation == null || _dropoffLocation == null) return;
    double distance = Geolocator.distanceBetween(_pickupLocation!.latitude, _pickupLocation!.longitude, _dropoffLocation!.latitude, _dropoffLocation!.longitude) / 1000;
    try {
      final results = await _deliveryService.calculateDetailedTripCost(distanceInKm: distance, vehicleType: vehicleType);
      setState(() {
        _estimatedPrice = results['totalPrice']!;
        _pricingDetails = results;
      });
    } catch (e) {
      debugPrint("Pricing Error: $e");
    }
  }

  Future<void> _finalizeAndUpload() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      
      // التزام كامل بالمسميات الأصلية في Firebase لضمان التوافق
      await FirebaseFirestore.instance.collection('specialRequests').add({
        'userId': user?.uid ?? 'anonymous',
        'pickupLocation': GeoPoint(_pickupLocation!.latitude, _pickupLocation!.longitude),
        'pickupAddress': _pickupAddress,
        'dropoffLocation': GeoPoint(_dropoffLocation!.latitude, _dropoffLocation!.longitude),
        'dropoffAddress': _dropoffAddress,
        'totalPrice': _pricingDetails['totalPrice'],
        'driverNet': _pricingDetails['driverNet'],
        'commissionAmount': _pricingDetails['commissionAmount'], 
        'vehicleType': _selectedVehicle,
        'details': _detailsController.text, // الوصف الإجباري بحد أقصى 80 حرف
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'verificationCode': (1000 + (DateTime.now().millisecond % 9000)).toString(),
      });

      if (mounted) {
        Navigator.pop(context); // إغلاق المودال
        Navigator.pop(context); // العودة للشاشة الرئيسية
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(backgroundColor: Colors.green, content: Text("🚀 طلبك قيد التنفيذ", style: TextStyle(fontFamily: 'Cairo'))));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("خطأ: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: Stack(
          children: [
            GoogleMap(
              initialCameraPosition: CameraPosition(target: _currentMapCenter, zoom: 14),
              mapType: _currentMapType,
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              onMapCreated: (controller) => _mapController.complete(controller),
              onCameraMove: (position) => _currentMapCenter = position.target,
              onCameraIdle: () => _getAddress(_currentMapCenter),
            ),
            Center(child: Padding(padding: const EdgeInsets.only(bottom: 35), child: Icon(Icons.location_on, size: 45, color: _currentStep == PickerStep.pickup ? Colors.green : Colors.red))),
            Positioned(
              left: 15,
              bottom: 25.h,
              child: Column(
                children: [
                  FloatingActionButton.small(heroTag: "search_btn", backgroundColor: Colors.white, onPressed: _openSearch, child: Icon(Icons.search, color: Colors.blue[900])),
                  const SizedBox(height: 10),
                  FloatingActionButton.small(heroTag: "map_type", backgroundColor: Colors.white, onPressed: () => setState(() => _currentMapType = _currentMapType == MapType.normal ? MapType.satellite : MapType.normal), child: Icon(Icons.layers, color: Colors.blue[900])),
                  const SizedBox(height: 10),
                  FloatingActionButton.small(heroTag: "gps_btn", backgroundColor: Colors.white, onPressed: _determinePosition, child: Icon(Icons.gps_fixed, color: Colors.blue[900])),
                ],
              ),
            ),
            Positioned(top: 50, right: 15, child: CircleAvatar(backgroundColor: Colors.white, child: IconButton(icon: const Icon(Icons.arrow_forward, color: Colors.black), onPressed: () => Navigator.pop(context)))),
            _buildActionCard(),
            if (_isMapLoading) Container(color: Colors.white, child: const Center(child: CircularProgressIndicator())),
            if (_isLoading) Container(color: Colors.black45, child: const Center(child: CircularProgressIndicator(color: Colors.white))),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard() {
    double safeBottom = MediaQuery.of(context).padding.bottom;
    return Align(
      alignment: Alignment.bottomCenter,
      child: SafeArea(
        child: Container(
          margin: EdgeInsets.fromLTRB(15, 0, 15, safeBottom > 0 ? 5 : 20),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(25), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)]),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(Icons.location_searching, color: _currentStep == PickerStep.pickup ? Colors.green : Colors.red),
                  const SizedBox(width: 10),
                  Expanded(child: Text(_tempAddress, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, fontFamily: 'Cairo'))),
                ],
              ),
              const SizedBox(height: 15),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _handleNextStep,
                  style: ElevatedButton.styleFrom(backgroundColor: _currentStep == PickerStep.pickup ? Colors.green[700] : Colors.red[700], shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                  child: Text(_currentStep == PickerStep.pickup ? "تحديد مكان الاستلام" : "تحديد وجهة التوصيل", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15, fontFamily: 'Cairo')),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  void _showFinalConfirmation() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
          padding: EdgeInsets.fromLTRB(25, 20, 25, MediaQuery.of(context).viewInsets.bottom + 30),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("تفاصيل طلب التوصيل", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, fontFamily: 'Cairo')),
                const Divider(height: 30),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: _vehicles.map((v) {
                    bool isSelected = _selectedVehicle == v['id'];
                    return GestureDetector(
                      onTap: () async {
                        setModalState(() => _selectedVehicle = v['id']);
                        await _updatePricing(v['id']);
                        setModalState(() {});
                      },
                      child: Column(children: [CircleAvatar(radius: 25, backgroundColor: isSelected ? Colors.blue[900] : Colors.grey[200], child: Icon(v['icon'], color: isSelected ? Colors.white : Colors.grey)), const SizedBox(height: 5), Text(v['name'], style: const TextStyle(fontFamily: 'Cairo', fontSize: 11, fontWeight: FontWeight.bold))]),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 25),
                TextFormField(
                  controller: _detailsController,
                  maxLength: 80,
                  validator: (value) => (value == null || value.trim().isEmpty) ? "برجاء وصف الشحنة (إجباري)" : null,
                  decoration: InputDecoration(
                      hintText: "صف الشحنة (مثلاً: أوراق، طرد ملابس)...",
                      hintStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 11),
                      filled: true,
                      fillColor: Colors.grey[100],
                      counterStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none)),
                ),
                const SizedBox(height: 20),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Text("التكلفة التقريبية:", style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
                  Text("${_estimatedPrice.toStringAsFixed(0)} ج.م", style: TextStyle(fontSize: 22.sp, color: Colors.blue[900], fontWeight: FontWeight.w900))
                ]),
                const SizedBox(height: 25),
                SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                        onPressed: _finalizeAndUpload,
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[900], shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
                        child: const Text("تأكيد وإرسال الطلب", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16, fontFamily: 'Cairo')))),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

