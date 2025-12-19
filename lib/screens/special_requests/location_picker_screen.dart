// lib/screens/special_requests/location_picker_screen.dart

import 'dart:async'; // 💡 استيراد ضروري لإدارة التوقيت
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geocoding/geocoding.dart'; 

class LocationPickerScreen extends StatefulWidget {
  final LatLng initialLocation;
  final String title;

  const LocationPickerScreen({super.key, required this.initialLocation, required this.title});

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  late LatLng _selectedLocation;
  String _address = "جاري تحديد العنوان...";
  final MapController _mapController = MapController();
  
  // 💡 [إدارة الموارد]: تعريف مؤقت لمنع الاستدعاء المتكرر أثناء التحريك
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _selectedLocation = widget.initialLocation;
    _updateAddress(_selectedLocation);
  }

  // 💡 [إلغاء المؤقت]: لضمان عدم تسريب الذاكرة (Memory Leak)
  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  // دالة جلب العنوان (الـ API)
  Future<void> _updateAddress(LatLng position) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        setState(() {
          _address = "${place.street}, ${place.subLocality ?? ''} ${place.locality ?? ''}";
        });
      }
    } catch (e) {
      if (mounted) setState(() => _address = "موقع غير معروف");
    }
  }

  // 💡 [المنطق المضاف]: دالة التحكم في الاستدعاء (Debouncing)
  void _onMapMoved(LatLng newPosition) {
    _selectedLocation = newPosition;
    
    // إلغاء أي طلب سابق إذا استمر المستخدم في التحريك
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();

    // تشغيل الطلب فقط بعد توقف المستخدم عن التحريك لمدة 800 مللي ثانية
    _debounceTimer = Timer(const Duration(milliseconds: 800), () {
      _updateAddress(newPosition);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.title, style: const TextStyle(fontWeight: FontWeight.bold)),
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
                    // 💡 استدعاء دالة إدارة الموارد بدلاً من الـ API مباشرة
                    _onMapMoved(position.center!); 
                  }
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
                ),
              ],
            ),
            
            // الدبوس الثابت
            const Center(
              child: Padding(
                padding: EdgeInsets.only(bottom: 40),
                child: Icon(Icons.location_on, color: Colors.red, size: 50),
              ),
            ),

            // الطبقة العلوية المزدوجة
            Positioned(
              top: 20,
              left: 20,
              right: 20,
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4)],
                    ),
                    child: const Text(
                      "حرك الخريطة لتضع الدبوس على الموقع بالضبط",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: Colors.black54),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 15),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.green.withOpacity(0.5), width: 1.5),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.map_rounded, color: Colors.green, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _address,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
