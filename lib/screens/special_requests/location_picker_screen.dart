// lib/screens/special_requests/location_picker_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geocoding/geocoding.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // 💡 استيراد فايربيز

class LocationPickerScreen extends StatefulWidget {
  final LatLng initialLocation;
  final String title;
  final String userId; // 💡 نحتاج معرف المستخدم لربط الطلب بصاحبه

  const LocationPickerScreen({
    super.key, 
    required this.initialLocation, 
    required this.title,
    required this.userId,
  });

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  late LatLng _selectedLocation;
  String _address = "جاري تحديد العنوان...";
  final MapController _mapController = MapController();
  Timer? _debounceTimer;
  bool _isSaving = false; // لحالة التحميل عند الحفظ

  @override
  void initState() {
    super.initState();
    _selectedLocation = widget.initialLocation;
    _updateAddress(_selectedLocation);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  // دالة جلب العنوان من الإحداثيات
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

  void _onMapMoved(LatLng newPosition) {
    _selectedLocation = newPosition;
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 800), () {
      _updateAddress(newPosition);
    });
  }

  // 🟢 [الدالة الجديدة]: إرسال البيانات إلى Firestore
  Future<void> _saveRequestToFirestore() async {
    setState(() => _isSaving = true);
    try {
      await FirebaseFirestore.instance.collection('specialRequests').add({
        'userId': widget.userId,
        'title': widget.title,
        'address': _address,
        'latitude': _selectedLocation.latitude,
        'longitude': _selectedLocation.longitude,
        'status': 'pending', // حالة الطلب قيد الانتظار
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ تم إرسال موقعك بنجاح'), backgroundColor: Colors.green),
        );
        Navigator.pop(context, _selectedLocation); // العودة بعد الحفظ
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ خطأ في الإرسال: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.title, style: const TextStyle(fontWeight: FontWeight.bold)),
          actions: [
            _isSaving 
              ? const Padding(padding: EdgeInsets.all(15), child: CircularProgressIndicator(strokeWidth: 2))
              : TextButton(
                  onPressed: _saveRequestToFirestore, // 💡 استدعاء دالة الحفظ
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
                  if (hasGesture) _onMapMoved(position.center!);
                },
              ),
              children: [
                TileLayer(urlTemplate: 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png'),
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
              top: 20, left: 20, right: 20,
              child: Column(
                children: [
                  // شريط التعليمات
                  _buildGlassPanel("حرك الخريطة لتضع الدبوس على الموقع بالضبط", isTitle: false),
                  const SizedBox(height: 10),
                  // شريط العنوان التلقائي
                  _buildAddressPanel(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ويدجت مساعدة لشريط العنوان
  Widget _buildAddressPanel() {
    return Container(
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
          Expanded(child: Text(_address, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }

  Widget _buildGlassPanel(String text, {bool isTitle = false}) {
     return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(text, textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: isTitle ? Colors.black87 : Colors.black54)),
    );
  }
}
