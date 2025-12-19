// lib/screens/special_requests/abaatly_had_pro_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';

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
  
  // متغيرات حفظ الإحداثيات الحقيقية للمناديب والخرائط
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
      // صاحب المحل: الاستلام من موقعه الحالي
      _pickupController.text = "موقعي الحالي (المحل)";
      _pickupCoords = widget.userCurrentLocation;
    } else {
      // المستهلك: التسليم لموقعه الحالي (المنزل)
      _dropoffController.text = "موقعي الحالي (المنزل)";
      _dropoffCoords = widget.userCurrentLocation;
    }
  }

  // دالة وهمية حالياً لفتح الخريطة واختيار الموقع
  Future<void> _pickLocation(bool isPickup) async {
    // هنا مستقبلاً هنفتح شاشة الخريطة (MapPicker)
    // حالياً هنفترض إن المستخدم اختار نقطة تجريبية لنرى كيف يتم تخزينها
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("سيتم فتح الخريطة لاختيار الموقع بدقة..."))
    );
    
    // مثال لما سيحدث بعد اختيار الموقع من الخريطة:
    setState(() {
      if (isPickup) {
        _pickupCoords = LatLng(31.2, 29.9); // الإحداثيات المختارة
        _pickupController.text = "تم تحديد الموقع من الخريطة ✅";
      } else {
        _dropoffCoords = LatLng(31.21, 29.91);
        _dropoffController.text = "تم تحديد موقع التسليم ✅";
      }
    });
  }

  Future<void> _submitOrder() async {
    if (_detailsController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("يرجى كتابة تفاصيل الطلب")));
      return;
    }
    
    // التأكد من وجود إحداثيات قبل الإرسال
    if (_pickupCoords == null || _dropoffCoords == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("يرجى تحديد نقطة الاستلام والتسليم من الخريطة")));
      return;
    }

    setState(() => _isLoading = true);

    try {
      await FirebaseFirestore.instance.collection('specialRequests').add({
        'details': _detailsController.text,
        'pickupAddress': _pickupController.text,
        'dropoffAddress': _dropoffController.text,
        // إرسال الإحداثيات كـ GeoPoint ليفهمها الفايربيز والخرائط
        'pickupLocation': GeoPoint(_pickupCoords!.latitude, _pickupCoords!.longitude),
        'dropoffLocation': GeoPoint(_dropoffCoords!.latitude, _dropoffCoords!.longitude),
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'requestType': widget.isStoreOwner ? 'store_delivery' : 'consumer_personal',
        'senderId': 'current_user_id', // يجب ربطها بـ Auth لاحقاً
      });

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("تم إرسال طلبك للمناديب 🚀")));
      Navigator.pop(context);
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("خطأ في الإرسال: $e")));
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
              // خانة الاستلام - مع تعطيل الكتابة اليدوية (readOnly)
              _buildLocationInput(
                label: "منين؟ (مكان الاستلام)", 
                controller: _pickupController, 
                icon: Icons.location_on, 
                color: Colors.green,
                onTap: () => _pickLocation(true),
              ),
              
              const Icon(Icons.arrow_downward, color: Colors.grey, size: 30),
              
              // خانة التسليم - مع تعطيل الكتابة اليدوية (readOnly)
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
                  hintText: "اكتب تفاصيل الطلب (مثلاً: كرتونة مياه، أو مفاتيح..)",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                  filled: true, 
                  fillColor: Colors.grey[100],
                ),
              ),
              
              const SizedBox(height: 35),
              
              ElevatedButton(
                onPressed: _isLoading ? null : _submitOrder,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange[900],
                  minimumSize: const Size(double.infinity, 65),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  elevation: 5,
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
      onTap: onTap, // الضغط على الخانة يفتح الخريطة
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey[200]!),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 5))],
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
                  TextField(
                    controller: controller,
                    enabled: false, // يمنع الكتابة اليدوية تماماً لضمان عدم تلف الإحداثيات
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    decoration: const InputDecoration(border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.only(top: 5)),
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
