// lib/screens/special_requests/abaatly_had_pro_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';
// استيراد صفحة اختيار الموقع الجديدة
import 'location_picker_screen.dart'; 

class AbaatlyHadProScreen extends StatefulWidget {
  final LatLng userCurrentLocation;
  final bool isStoreOwner;

  const AbaatlyHadProScreen({
    super.key, 
    required this.userCurrentLocation, 
    this.isStoreOwner = false
  });

  @override
  State<AbaatlyHadProScreen> createState() => _AbaatlyHadProScreenState();
}

class _AbaatlyHadProScreenState extends State<AbaatlyHadProScreen> {
  final TextEditingController _detailsController = TextEditingController();
  final TextEditingController _pickupController = TextEditingController();
  final TextEditingController _dropoffController = TextEditingController();
  
  LatLng? _pickupCoords;
  LatLng? _dropoffCoords;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _setupInitialLocations();
  }

  void _setupInitialLocations() {
    if (widget.isStoreOwner) {
      _pickupController.text = "موقعي الحالي (المحل)";
      _pickupCoords = widget.userCurrentLocation;
    } else {
      _dropoffController.text = "موقعي الحالي (المنزل)";
      _dropoffCoords = widget.userCurrentLocation;
    }
  }

  // --- التعديل الجوهري هنا: ربط الخريطة الحقيقية ---
  Future<void> _pickLocation(bool isPickup) async {
    final LatLng? result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LocationPickerScreen(
          initialLocation: widget.userCurrentLocation,
          title: isPickup ? "حدد مكان الاستلام" : "حدد مكان التسليم",
        ),
      ),
    );

    if (result != null) {
      setState(() {
        if (isPickup) {
          _pickupCoords = result;
          // عرض الإحداثيات بشكل مبسط للمستخدم للتأكيد
          _pickupController.text = "تم التحديد من الخريطة ✅"; 
        } else {
          _dropoffCoords = result;
          _dropoffController.text = "تم التحديد من الخريطة ✅";
        }
      });
    }
  }

  Future<void> _submitOrder() async {
    if (_detailsController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("يرجى كتابة تفاصيل الطلب")));
      return;
    }
    
    if (_pickupCoords == null || _dropoffCoords == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("يرجى تحديد النقطتين من الخريطة")));
      return;
    }

    setState(() => _isLoading = true);

    try {
      await FirebaseFirestore.instance.collection('specialRequests').add({
        'details': _detailsController.text,
        'pickupAddress': _pickupController.text,
        'dropoffAddress': _dropoffController.text,
        // إرسال الإحداثيات الفعلية كـ GeoPoint للمناديب
        'pickupLocation': GeoPoint(_pickupCoords!.latitude, _pickupCoords!.longitude),
        'dropoffLocation': GeoPoint(_dropoffCoords!.latitude, _dropoffCoords!.longitude),
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'requestType': widget.isStoreOwner ? 'store_delivery' : 'consumer_personal',
      });

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("تم إرسال طلبك للمناديب 🚀")));
      Navigator.pop(context);
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("خطأ: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("ابعتلي حد (توصيل خاص)", style: TextStyle(fontWeight: FontWeight.bold)),
          centerTitle: true,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              _buildLocationInput(
                label: "منين؟ (مكان الاستلام)", 
                controller: _pickupController, 
                icon: Icons.location_on, 
                color: Colors.green,
                onTap: () => _pickLocation(true),
              ),
              const Icon(Icons.arrow_downward, color: Colors.grey, size: 30),
              _buildLocationInput(
                label: "لفين؟ (مكان التسليم)", 
                controller: _dropoffController, 
                icon: Icons.flag, 
                color: Colors.red,
                onTap: () => _pickLocation(false),
              ),
              const SizedBox(height: 25),
              TextField(
                controller: _detailsController,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: "اكتب تفاصيل الطلب..",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                  filled: true, fillColor: Colors.grey[100],
                ),
              ),
              const SizedBox(height: 35),
              ElevatedButton(
                onPressed: _isLoading ? null : _submitOrder,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange[900],
                  minimumSize: const Size(double.infinity, 65),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                child: _isLoading 
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text("تأكيد وطلب مندوب الآن", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLocationInput({
    required String label, 
    required TextEditingController controller, 
    required IconData icon, 
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                  Text(
                    controller.text.isEmpty ? "اضغط للتحديد من الخريطة" : controller.text,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ],
              ),
            ),
            const Icon(Icons.map_rounded, color: Colors.blueAccent),
          ],
        ),
      ),
    );
  }
}
