// lib/screens/special_requests/location_picker_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/delivery_service.dart';
import 'package:sizer/sizer.dart';

enum PickerStep { pickup, dropoff, confirm }

class LocationPickerScreen extends StatefulWidget {
  static const routeName = '/location-picker';
  final LatLng? initialLocation;

  const LocationPickerScreen({super.key, this.initialLocation});

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  final MapController _mapController = MapController();
  final DeliveryService _deliveryService = DeliveryService();
  
  PickerStep _currentStep = PickerStep.pickup;
  late LatLng _currentMapCenter;
  
  LatLng? _pickupLocation;
  String _pickupAddress = "جاري جلب العنوان...";
  LatLng? _dropoffLocation;
  String _dropoffAddress = "";
  double _estimatedPrice = 0.0;
  String _tempAddress = "حرك الخريطة لتحديد الموقع";
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _currentMapCenter = widget.initialLocation ?? const LatLng(30.0444, 31.2357);
    _determinePosition();
  }

  Future<void> _determinePosition() async {
    if (widget.initialLocation != null) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    Position position = await Geolocator.getCurrentPosition();
    setState(() {
      _currentMapCenter = LatLng(position.latitude, position.longitude);
      _mapController.move(_currentMapCenter, 15);
    });
  }

  // دالة جلب العنوان عند تحريك الخريطة
  Future<void> _getAddress(LatLng position) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        setState(() {
          _tempAddress = "${place.street}, ${place.subLocality}, ${place.locality}";
        });
      }
    } catch (e) {
      setState(() { _tempAddress = "موقع غير مسمى"; });
    }
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
      _estimatedPrice = await _calculatePrice();
      _showFinalConfirmation();
    }
  }

  Future<double> _calculatePrice() async {
    if (_pickupLocation == null || _dropoffLocation == null) return 0.0;
    double distance = _deliveryService.calculateDistance(
      _pickupLocation!.latitude, _pickupLocation!.longitude,
      _dropoffLocation!.latitude, _dropoffLocation!.longitude
    );
    return await _deliveryService.calculateTripCost(distanceInKm: distance);
  }

  Future<void> _finalizeAndUpload() async {
    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      await FirebaseFirestore.instance.collection('specialRequests').add({
        'userId': user?.uid ?? 'anonymous',
        'pickupLocation': GeoPoint(_pickupLocation!.latitude, _pickupLocation!.longitude),
        'pickupAddress': _pickupAddress,
        'dropoffLocation': GeoPoint(_dropoffLocation!.latitude, _dropoffLocation!.longitude),
        'dropoffAddress': _dropoffAddress,
        'price': _estimatedPrice,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });
      Navigator.pop(context);
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("تم إرسال طلبك بنجاح!")));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("خطأ: $e")));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_currentStep == PickerStep.pickup ? "تحديد مكان الاستلام" : "تحديد وجهة التوصيل"),
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentMapCenter,
              initialZoom: 15.0,
              onPositionChanged: (pos, hasGesture) {
                if (hasGesture) {
                  _currentMapCenter = pos.center!;
                  _getAddress(_currentMapCenter);
                }
              },
            ),
            children: [
              TileLayer(
                // ✅ استخدام نفس الرابط الجمالي والمستقر (CartoDB Voyager)
                urlTemplate: 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
                subdomains: const ['a', 'b', 'c', 'd'],
                // ✅ إضافة الـ User-Agent لمنع الحظر
                userAgentPackageName: 'com.example.app', 
              ),
            ],
          ),
          // الدبوس الثابت في منتصف الخريطة
          Center(
            child: Icon(Icons.location_pin, size: 40, color: _currentStep == PickerStep.pickup ? Colors.green : Colors.red),
          ),
          // الأزرار التفاعلية
          _buildActionCard(),
        ],
      ),
    );
  }

  Widget _buildActionCard() {
    return Positioned(
      bottom: 20, left: 20, right: 20,
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_tempAddress, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(height: 15),
              ElevatedButton(
                onPressed: _handleNextStep,
                style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
                child: Text(_currentStep == PickerStep.pickup ? "تأكيد مكان الاستلام" : "تأكيد وجهة التوصيل"),
              )
            ],
          ),
        ),
      ),
    );
  }

  // دالة إظهار ملخص الفاتورة
  void _showFinalConfirmation() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("ملخص الرحلة", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const Divider(),
            _buildInfoRow(Icons.circle, Colors.green, "من: $_pickupAddress"),
            _buildInfoRow(Icons.location_on, Colors.red, "إلى: $_dropoffAddress"),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("التكلفة التقديرية:"),
                Text("${_estimatedPrice.toStringAsFixed(2)} ج.م", style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 20)),
              ],
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _finalizeAndUpload,
              style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
              child: const Text("تأكيد وطلب المندوب"),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, Color color, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }
}
