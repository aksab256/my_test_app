// lib/screens/special_requests/abaatly_had_pro_screen.dart
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:sizer/sizer.dart';
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

  @override
  void initState() {
    super.initState();
    _setupInitialLocations();
  }

  void _setupInitialLocations() {
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
                maxLines: 3,
                style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  hintText: "مثال: شنطة ملابس، كرتونة طلبات...",
                  hintStyle: TextStyle(fontSize: 12.sp, color: Colors.grey[400]),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide(color: Colors.grey[200]!)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide(color: Colors.grey[200]!)),
                ),
              ),
              const SizedBox(height: 30),
              
              _buildTermsSection(),
              
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTermsSection() {
    return Container(
      padding: const EdgeInsets.all(20), // زيادة الحشو الداخلي
      decoration: BoxDecoration(
        color: Colors.amber.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.amber.withOpacity(0.3), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.gavel_rounded, color: Colors.amber, size: 24), // أيقونة أوضح للمسؤولية القانونية
              const SizedBox(width: 10),
              Text("تنبيهات أمان وهامة", 
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15.sp, color: Colors.black87)),
            ],
          ),
          const SizedBox(height: 15),
          _buildTermItem("Aksab هو وسيط تقني يربطك بالمناديب المستقلين فقط."),
          _buildTermItem("يُمنع منعاً باتاً نقل مقتنيات ثمينة (ذهب، مبالغ مالية كبيرة، أجهزة غالية)."),
          _buildTermItem("المنصة غير مسؤولة قانونياً عن محتوى الشحنة؛ المسؤولية تقع بالكامل على المستخدم والمندوب."),
          _buildTermItem("يرجى التأكد من مطابقة بيانات المندوب قبل تسليمه الأغراض."),
        ],
      ),
    );
  }

  Widget _buildTermItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10), // زيادة المسافة بين العناصر
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 8), 
            child: Icon(Icons.circle, size: 7, color: Colors.amber[800]), // تكبير النقطة وتغيير لونها لتبرز
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text, 
              style: TextStyle(
                fontSize: 12.5.sp, // 👈 تكبير خط الشروط كما طلبت
                fontWeight: FontWeight.w700, // جعل الخط أكثر سمكاً للوضوح
                color: Colors.black87, 
                height: 1.5
              ),
            ),
          ),
        ],
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
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14.sp, color: isConfirmed ? Colors.black : Colors.red[900])
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

