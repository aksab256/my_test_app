// lib/screens/special_requests/abaatly_had_pro_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sizer/sizer.dart'; // أضفتها لضمان تناسق المقاسات
import 'package:my_test_app/services/bubble_service.dart'; // 🎯 ضروري لتشغيل الفقاعة فوراً
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
  bool _pickupConfirmed = false;
  bool _dropoffConfirmed = false;
  bool _isLoading = false;

  final Color accentOrange = const Color(0xFFE65100);

  @override
  void initState() {
    super.initState();
    _setupInitialLocations();
  }

  void _setupInitialLocations() {
    // 🎯 هنا نضمن استلام الموقع الممرر من الصفحة الرئيسية واستخدامه فوراً
    if (widget.isStoreOwner) {
      _pickupController.text = "موقعي الحالي (المحل) ✅";
      _pickupCoords = widget.userCurrentLocation;
      _pickupConfirmed = true;
    } else {
      _dropoffController.text = "موقعي الحالي (المنزل) ✅";
      _dropoffCoords = widget.userCurrentLocation;
      _dropoffConfirmed = true;
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
    if (_detailsController.text.trim().isEmpty) {
      _showError("يرجى كتابة تفاصيل ما تريد نقله");
      return;
    }
    if (!_pickupConfirmed || !_dropoffConfirmed) {
      _showError("يرجى تأكيد مواقع الاستلام والتسليم");
      return;
    }

    setState(() => _isLoading = true);
    try {
      // 🎯 إرسال البيانات كاملة لـ Firestore
      DocumentReference docRef = await FirebaseFirestore.instance.collection('specialRequests').add({
        'details': _detailsController.text,
        'pickupAddress': _pickupController.text,
        'dropoffAddress': _dropoffController.text,
        'pickupLocation': GeoPoint(_pickupCoords!.latitude, _pickupCoords!.longitude),
        'dropoffLocation': GeoPoint(_dropoffCoords!.latitude, _dropoffCoords!.longitude),
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'requestType': widget.isStoreOwner ? 'store_delivery' : 'consumer_personal',
        'price': 0,
        'isStoreOwner': widget.isStoreOwner, // حفظ صفة صاحب الطلب
      });

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('active_special_order_id', docRef.id);
      
      // 🎯 تفعيل الفقاعة فوراً قبل الخروج من الصفحة
      BubbleService.show(docRef.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("🚀 تم إرسال طلبك! ابحث عن فقاعة التتبع الآن"))
        );
        Navigator.pop(context); // العودة للرئيسية حيث تظهر الفقاعة
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showError("حدث خطأ: $e");
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: TextStyle(fontSize: 14.sp)),
      backgroundColor: Colors.red,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFFBFBFB),
        appBar: AppBar(
          title: Text("طلب توصيل خاص", 
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18.sp)),
          centerTitle: true,
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.close, color: Colors.black), 
            onPressed: () => Navigator.pop(context)
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildLocationCard(
                label: "مكان الاستلام",
                controller: _pickupController,
                icon: Icons.location_on,
                color: Colors.green[700]!,
                isConfirmed: _pickupConfirmed,
                onTap: () => _pickLocation(true),
              ),
              const Center(child: Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Icon(Icons.keyboard_double_arrow_down_rounded, color: Colors.grey, size: 40),
              )),
              _buildLocationCard(
                label: "وجهة التسليم",
                controller: _dropoffController,
                icon: Icons.flag_rounded,
                color: Colors.red[700]!,
                isConfirmed: _dropoffConfirmed,
                onTap: () => _pickLocation(false),
              ),
              const SizedBox(height: 35),
              Text("تفاصيل الحمولة", 
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16.sp)),
              const SizedBox(height: 12),
              TextField(
                controller: _detailsController,
                maxLines: 4,
                style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  hintText: "مثال: شنطة ملابس، كرتونة طلبات...",
                  hintStyle: TextStyle(fontSize: 13.sp, color: Colors.grey[400]),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(25), borderSide: BorderSide(color: Colors.grey[200]!)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(25), borderSide: BorderSide(color: Colors.grey[200]!)),
                ),
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 70,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitOrder,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentOrange,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    elevation: 10,
                    shadowColor: accentOrange.withOpacity(0.4),
                  ),
                  child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text("تأكيد وطلب مندوب الآن", 
                        style: TextStyle(color: Colors.white, fontSize: 17.sp, fontWeight: FontWeight.w900)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLocationCard({
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
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4))],
        ),
        child: Row(
          children: [
            CircleAvatar(backgroundColor: color.withOpacity(0.1), child: Icon(icon, color: color, size: 28)),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 11.sp, fontWeight: FontWeight.bold)),
                  Text(
                    controller.text.isEmpty ? "اضغط للتحديد من الخريطة" : controller.text,
                    style: TextStyle(
                      fontWeight: FontWeight.w900, 
                      fontSize: 14.sp, 
                      color: isConfirmed ? Colors.black : Colors.red[900]
                    )
                  ),
                ],
              ),
            ),
            Icon(isConfirmed ? Icons.check_circle : Icons.map_outlined, color: isConfirmed ? Colors.green : Colors.grey, size: 28),
          ],
        ),
      ),
    );
  }
}

