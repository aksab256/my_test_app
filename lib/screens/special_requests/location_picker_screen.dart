// lib/screens/special_requests/location_picker_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:sizer/sizer.dart';

class LocationPickerScreen extends StatefulWidget {
  final LatLng? initialLocation;
  final String title;

  const LocationPickerScreen({super.key, this.initialLocation, required this.title});

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  final MapController _mapController = MapController();
  
  // 🔑 Mapbox Token
  final String mapboxToken = "pk.eyJ1IjoiYW1yc2hpcGwiLCJhIjoiY21lajRweGdjMDB0eDJsczdiemdzdXV6biJ9.E--si9vOB93NGcAq7uVgGw";

  late LatLng _currentMapCenter;
  String _tempAddress = "جاري جلب العنوان...";
  bool _hasMovedMap = false; // تأمين: لا يمكن التأكيد بدون تحريك الخريطة
  bool _isLocating = false;

  @override
  void initState() {
    super.initState();
    _currentMapCenter = widget.initialLocation ?? const LatLng(31.2001, 29.9187);
    _determinePosition();
  }

  Future<void> _determinePosition() async {
    setState(() => _isLocating = true);
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      
      if (permission == LocationPermission.always || permission == LocationPermission.whileInUse) {
        Position position = await Geolocator.getCurrentPosition();
        _currentMapCenter = LatLng(position.latitude, position.longitude);
        _mapController.move(_currentMapCenter, 15);
        _getAddress(_currentMapCenter);
      }
    } catch (e) {
      print("Error locating: $e");
    } finally {
      setState(() => _isLocating = false);
    }
  }

  Future<void> _getAddress(LatLng position) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        setState(() {
          _tempAddress = "${place.street ?? ''} ${place.subLocality ?? ''}, ${place.locality ?? ''}";
          if (_tempAddress.trim().isEmpty) _tempAddress = "موقع غير مسمى";
        });
      }
    } catch (e) {
      setState(() => _tempAddress = "إحداثيات: ${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.title, style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w900)),
          centerTitle: true,
          actions: [
            IconButton(icon: const Icon(Icons.my_location), onPressed: _determinePosition)
          ],
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
                    setState(() {
                      _currentMapCenter = pos.center!;
                      _hasMovedMap = true; // المستخدم حرك الخريطة بنفسه
                    });
                    _getAddress(_currentMapCenter);
                  }
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://api.mapbox.com/styles/v1/mapbox/streets-v11/tiles/{z}/{x}/{y}?access_token=$mapboxToken',
                  additionalOptions: {'accessToken': mapboxToken},
                ),
              ],
            ),
            
            // دبوس التحديد (Pin)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 35),
                child: Icon(
                  Icons.location_on_rounded, 
                  size: 40.sp, 
                  color: _hasMovedMap ? Colors.red[900] : Colors.grey[600]
                ),
              ),
            ),

            // كارت العنوان وزر التأكيد
            Positioned(
              bottom: 20, left: 15, right: 15,
              child: Card(
                elevation: 10,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.map_outlined, color: Colors.blue[900]),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(_tempAddress, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.sp)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: _hasMovedMap 
                          ? () => Navigator.pop(context, _currentMapCenter) 
                          : null, // معطل حتى يتم تحريك الخريطة
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[900],
                          minimumSize: const Size(double.infinity, 60),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                          disabledBackgroundColor: Colors.grey[300]
                        ),
                        child: Text(
                          _hasMovedMap ? "تأكيد هذا الموقع ✅" : "حرك الخريطة لتحديد الموقع",
                          style: TextStyle(color: Colors.white, fontSize: 12.sp, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (_isLocating) const Center(child: CircularProgressIndicator()),
          ],
        ),
      ),
    );
  }
}

