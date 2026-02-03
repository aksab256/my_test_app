// lib/screens/consumer/abaatly_had_pro_screen.dart

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:sizer/sizer.dart';
import 'package:geolocator/geolocator.dart';
import 'package:my_test_app/screens/consumer/consumer_widgets.dart'; 
import 'location_picker_screen.dart';

class AbaatlyHadProScreen extends StatefulWidget {
  static const routeName = '/abaatly-had';
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
  final TextEditingController _pickupController = TextEditingController();

  LatLng? _pickupCoords;
  bool _pickupConfirmed = false;
  late LatLng _liveLocation;

  @override
  void initState() {
    super.initState();
    _liveLocation = widget.userCurrentLocation;
    _checkPermissionAndGetLocation();
  }

  Future<void> _checkPermissionAndGetLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    
    Position position = await Geolocator.getCurrentPosition();
    setState(() {
      _liveLocation = LatLng(position.latitude, position.longitude);
    });
  }

  Future<void> _pickLocation() async {
    final LatLng? result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LocationPickerScreen(
          initialLocation: _liveLocation, 
          title: "حدد مكان الاستلام",
        ),
      ),
    );

    if (result != null) {
      setState(() {
        _pickupCoords = result;
        _pickupController.text = "تم تحديد مكان الاستلام ✅";
        _pickupConfirmed = true;
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
          title: Text("إعداد مسار التوصيل", 
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20.sp, color: Colors.black)), // تكبير عنوان الأب بار
          centerTitle: true,
          backgroundColor: Colors.white,
          elevation: 0.5,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black, size: 28), 
            onPressed: () => Navigator.pop(context)
          ),
        ),
        body: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // كارت الاستلام - الوحيد المطلوب الآن
              _buildLocationCard(
                label: "من أين سيستلم المندوب؟",
                controller: _pickupController,
                icon: Icons.location_on,
                color: const Color(0xFF43A047),
                isConfirmed: _pickupConfirmed,
                onTap: () => _pickLocation(),
              ),

              const SizedBox(height: 40),
              
              // قسم الشروط بتنسيق أوضح وخط أكبر
              _buildTermsSection(),
              
              const SizedBox(height: 40),
              
              // زر التأكيد يظهر عند تحديد الموقع
              if (_pickupConfirmed)
                _buildConfirmButton(),
              
              const SizedBox(height: 60), 
            ],
          ),
        ),
        bottomNavigationBar: const ConsumerFooterNav(cartCount: 0, activeIndex: -1),
      ),
    );
  }

  Widget _buildLocationCard({
    required String label, 
    required TextEditingController controller, 
    required IconData icon, 
    required Color color, 
    required bool isConfirmed, 
    required VoidCallback onTap
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.all(25), // زيادة البادينج الداخلي
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: isConfirmed ? color.withOpacity(0.6) : Colors.grey.withOpacity(0.2), 
              width: 2.5
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06), 
                blurRadius: 25, 
                offset: const Offset(0, 10)
              )
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(icon, color: color, size: 32), // تكبير الأيقونة
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 13.sp, fontWeight: FontWeight.bold)), // تكبير الخط
                    const SizedBox(height: 8),
                    Text(
                      controller.text.isEmpty ? "اضغط للتحديد من الخريطة" : controller.text, 
                      style: TextStyle(
                        fontWeight: FontWeight.w900, 
                        fontSize: 15.sp, // تكبير الخط الأساسي
                        color: isConfirmed ? Colors.black : Colors.orange[800]
                      )
                    ),
                  ],
                ),
              ),
              Icon(
                isConfirmed ? Icons.check_circle_rounded : Icons.add_location_alt_outlined, 
                color: isConfirmed ? Colors.green : Colors.grey[300], 
                size: 32
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTermsSection() {
    return Container(
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: Colors.amber.withOpacity(0.4), width: 1.5),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.gavel_rounded, color: Colors.amber, size: 30),
              const SizedBox(width: 12),
              Text("شروط الاستخدام والضمان", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16.sp)), // تكبير العنوان
            ],
          ),
          const Divider(height: 40),
          _buildTermItem("المسؤولية القانونية عن المحتوى تقع على طرفي العملية."),
          _buildTermItem("يُمنع نقل الأموال أو المواد المحظورة قانوناً."),
          _buildTermItem("كود التسليم هو توقيعك؛ لا تعطه للمندوب إلا بعد الفحص."),
          _buildTermItem("طابق هوية المندوب وصورته من التطبيق قبل التسليم."),
        ],
      ),
    );
  }

  Widget _buildTermItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18), // زيادة المسافة بين العناصر
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.circle, size: 10, color: Colors.amber[700]).paddingOnly(top: 10),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w700, color: Colors.black87, height: 1.4))), // تكبير خط الشروط
        ],
      ),
    );
  }

  Widget _buildConfirmButton() {
    return Container(
      width: double.infinity,
      height: 70, // زيادة طول الزر
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(colors: [Color(0xFF43A047), Color(0xFF2E7D32)]),
        boxShadow: [BoxShadow(color: Colors.green.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: ElevatedButton(
        onPressed: () {
          // الانتقال للخطوة التالية
        }, 
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent, 
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22))
        ), 
        child: Text("تأكيد المسار والمتابعة", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17.sp, color: Colors.white)) // تكبير خط الزر
      ),
    );
  }
}

extension OnWidget on Widget {
  Widget paddingOnly({double top = 0}) => Padding(padding: EdgeInsets.only(top: top), child: this);
}
