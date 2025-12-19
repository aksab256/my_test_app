// lib/screens/special_requests/location_picker_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class LocationPickerScreen extends StatefulWidget {
  final LatLng initialLocation;
  final String title;

  const LocationPickerScreen({
    super.key, 
    required this.initialLocation, 
    required this.title
  });

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  late LatLng _selectedLocation;
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    _selectedLocation = widget.initialLocation;
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.title),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, _selectedLocation),
              child: const Text("تأكيد", style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 18)),
            )
          ],
        ),
        body: Stack(
          children: [
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: widget.initialLocation,
                initialZoom: 15.0,
                onPositionChanged: (position, hasGesture) {
                  if (hasGesture) {
                    setState(() {
                      _selectedLocation = position.center!;
                    });
                  }
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
                ),
              ],
            ),
            // الدبوس الثابت في منتصف الشاشة
            Center(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 40), // لضبط سن الدبوس على الموقع بالضبط
                child: Icon(Icons.location_on, color: Colors.red, size: 50),
              ),
            ),
            // زرار للرجوع للموقع الحالي
            Positioned(
              bottom: 20,
              right: 20,
              child: FloatingActionButton(
                onPressed: () => _mapController.move(widget.initialLocation, 15),
                child: const Icon(Icons.my_location),
              ),
            ),
            // عرض إحداثيات الموقع المختار (اختياري للتأكيد)
            Positioned(
              top: 20,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.9), borderRadius: BorderRadius.circular(10)),
                child: const Text("حرك الخريطة لتضع الدبوس على الموقع بالضبط", textAlign: TextAlign.center),
              ),
            )
          ],
        ),
      ),
    );
  }
}
