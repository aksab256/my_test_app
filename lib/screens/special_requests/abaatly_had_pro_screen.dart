// lib/screens/special_requests/abaatly_had_pro_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';
import 'package:sizer/sizer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'location_picker_screen.dart';

class AbaatlyHadProScreen extends StatefulWidget {
  final LatLng userCurrentLocation;
  final bool isStoreOwner;

  const AbaatlyHadProScreen({
    super.key,
    required this.userCurrentLocation,
    this.isStoreOwner = false,
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
  
  // متغيرات أمان للتأكد من أن المستخدم "فتح" الخريطة وأكد الموقع
  bool _pickupConfirmed = false;
  bool _dropoffConfirmed = false;
  
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _setupInitialLocations();
  }

  void _setupInitialLocations() {
    // نضع الإحداثيات ولكن نترك تأكيدها (Confirmed) خطأ لإجبار المستخدم على دخول الخريطة
    if (widget.isStoreOwner) {
      _pickupController.text = "موقعي الحالي (المحل)";
      _pickupCoords = widget.userCurrentLocation;
      _pickupConfirmed = true; // صاحب المحل غالباً موقعه ثابت ومعروف
    } else {
      _dropoffController.text = "موقعي الحالي (المنزل)";
      _dropoffCoords = widget.userCurrentLocation;
      _dropoffConfirmed = true; // المستهلك بيطلب لنفسه فموقعه الحالي هو الوجهة غالباً
    }
  }

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
          _pickupController.text = "تم التأكيد من الخريطة ✅";
          _pickupConfirmed = true;
        } else {
          _dropoffCoords = result;
          _dropoffController.text = "تم التأكيد من الخريطة ✅";
          _dropoffConfirmed = true;
        }
      });
    }
  }

  Future<void> _submitOrder() async {
    // 1. فحص التفاصيل
    if (_detailsController.text.trim().isEmpty) {
      _showError("يرجى كتابة تفاصيل ما تريد نقله");
      return;
    }

    // 2. تأمين النقاط (إجبار المستخدم على تأكيد النقطة التي لم تؤكد)
    if (!_pickupConfirmed || !_dropoffConfirmed) {
      _showError("يرجى الضغط على مواقع الاستلام والتسليم للتأكيد من الخريطة أولاً");
      return;
    }

    setState(() => _isLoading = true);

    try {
      // إرسال الطلب لـ Firestore
      DocumentReference docRef = await FirebaseFirestore.instance.collection('specialRequests').add({
        'details': _detailsController.text,
        'pickupAddress': _pickupController.text,
        'dropoffAddress': _dropoffController.text,
        'pickupLocation': GeoPoint(_pickupCoords!.latitude, _pickupCoords!.longitude),
        'dropoffLocation': GeoPoint(_dropoffCoords!.latitude, _dropoffCoords!.longitude),
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'requestType': widget.isStoreOwner ? 'store_delivery' : 'consumer_personal',
        'price': 0, // سيقوم المندوب أو النظام بتحديده لاحقاً
      });

      // ✅ التعديل الأهم: حفظ معرف الطلب لتفعيل الفقاعة العائمة في MaterialApp
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('active_special_order_id', docRef.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("تم إرسال طلبك! ابحث عن فقاعة التتبع على الشاشة 🚀"))
        );
        Navigator.pop(context); // العودة للشاشة الرئيسية حيث ستظهر الفقاعة
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showError("حدث خطأ أثناء إرسال الطلب: $e");
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text("ابعتلي حد (توصيل خاص)", 
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16.sp, color: Colors.black87)),
          centerTitle: true,
          elevation: 0,
          backgroundColor: Colors.transparent,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Column(
            children: [
              _buildLocationInput(
                label: "منين؟ (مكان الاستلام)",
                controller: _pickupController,
                icon: Icons.location_on,
                color: Colors.green[700]!,
                isConfirmed: _pickupConfirmed,
                onTap: () => _pickLocation(true),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Icon(Icons.arrow_downward_rounded, color: Colors.orange[800], size: 35),
              ),
              _buildLocationInput(
                label: "لفين؟ (مكان التسليم)",
                controller: _dropoffController,
                icon: Icons.flag_rounded,
                color: Colors.red[700]!,
                isConfirmed: _dropoffConfirmed,
                onTap: () => _pickLocation(false),
              ),
              const SizedBox(height: 30),
              Text("ماذا تريد أن تنقل؟", 
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.sp, color: Colors.black87)),
              const SizedBox(height: 10),
              TextField(
                controller: _detailsController,
                maxLines: 4,
                style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  hintText: "مثال: كرتونة طلبات، طقم انتريه...",
                  filled: true,
                  fillColor: Colors.grey[50],
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(25), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: _isLoading ? null : _submitOrder,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange[900],
                  minimumSize: const Size(double.infinity, 70),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                  elevation: 8,
                ),
                child: _isLoading 
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Text("تأكيد وطلب مندوب الآن", 
                      style: TextStyle(color: Colors.white, fontSize: 15.sp, fontWeight: FontWeight.w900)),
              ),
              const SizedBox(height: 20),
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
    required bool isConfirmed,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(25),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(25),
          border: Border.all(color: isConfirmed ? color.withOpacity(0.5) : Colors.grey[200]!, width: 2),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 24.sp),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(color: Colors.grey[700], fontSize: 11.sp)),
                  Text(controller.text.isEmpty ? "اضغط للتحديد من الخريطة" : controller.text,
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13.sp, 
                    color: isConfirmed ? Colors.black : Colors.red[900])),
                ],
              ),
            ),
            Icon(isConfirmed ? Icons.check_circle : Icons.map_outlined, 
                 color: isConfirmed ? Colors.green : Colors.blue[800], size: 22.sp),
          ],
        ),
      ),
    );
  }
}

