// lib/screens/consumer/abaatly_had_pro_screen.dart

import 'package:flutter/material.dart';
// تم حذف latlong2 واستخدام مكتبة جوجل مابس حصرياً
import 'package:google_maps_flutter/google_maps_flutter.dart'; 
import 'package:sizer/sizer.dart';
import 'package:geolocator/geolocator.dart';
import 'package:my_test_app/screens/consumer/consumer_widgets.dart'; 
import 'location_picker_screen.dart';

class AbaatlyHadProScreen extends StatefulWidget {
  static const routeName = '/abaatly-had';
  // النوع هنا أصبح Google Maps LatLng
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
    _handleLocationPermission();
  }

  Future<void> _handleLocationPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      _showLocationRationale(); 
    } else {
      _getCurrentLocation();
    }
  }

  void _showLocationRationale() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.location_history, color: Colors.green[700], size: 28),
            const SizedBox(width: 10),
            const Text("تحسين تجربة التوصيل"),
          ],
        ),
        content: Text(
          "يحتاج 'أكسب' للوصول إلى موقعك لتحديد نقطة الاستلام بدقة على الخريطة وتسهيل وصول المندوب إليك.\n\n* يتم استخدام الموقع فقط أثناء فتح التطبيق.",
          style: TextStyle(fontSize: 13.sp, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("لاحقاً", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF43A047),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
            ),
            onPressed: () {
              Navigator.pop(context);
              _requestAndGetLocation();
            },
            child: const Text("موافق"),
          ),
        ],
      ),
    );
  }

  Future<void> _requestAndGetLocation() async {
    LocationPermission permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.always || permission == LocationPermission.whileInUse) {
      _getCurrentLocation();
    }
  }

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;
    
    try {
      Position position = await Geolocator.getCurrentPosition();
      if (mounted) {
        setState(() {
          // استخدام LatLng الخاص بـ google_maps_flutter
          _liveLocation = LatLng(position.latitude, position.longitude);
        });
      }
    } catch (e) {
      debugPrint("Location Error: $e");
    }
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
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18.sp, color: Colors.black)),
          centerTitle: true,
          backgroundColor: Colors.white,
          elevation: 0.5,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black, size: 24), 
            onPressed: () => Navigator.pop(context)
          ),
        ),
        body: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 25),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildLocationCard(
                label: "من أين سيستلم المندوب؟",
                controller: _pickupController,
                icon: Icons.location_on,
                color: const Color(0xFF43A047),
                isConfirmed: _pickupConfirmed,
                onTap: () => _pickLocation(),
              ),
              const SizedBox(height: 35),
              _buildTermsSection(),
              const SizedBox(height: 35),
              if (_pickupConfirmed)
                _buildConfirmButton(),
              const SizedBox(height: 50), 
            ],
          ),
        ),
        bottomNavigationBar: const ConsumerFooterNav(cartCount: 0, activeIndex: -1),
      ),
    );
  }

  // --- [باقي الودجتات الـ UI كما هي بدون تغيير] ---

  Widget _buildLocationCard({
    required String label, 
    required TextEditingController controller, 
    required IconData icon, 
    required Color color, 
    required bool isConfirmed, 
    required VoidCallback onTap
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isConfirmed ? color.withOpacity(0.5) : Colors.grey.withOpacity(0.1), 
            width: 2
          ),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 15, offset: const Offset(0, 8))
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(15)),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 12.sp, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 5),
                  Text(
                    controller.text.isEmpty ? "اضغط للتحديد من الخريطة" : controller.text, 
                    style: TextStyle(
                      fontWeight: FontWeight.w900, 
                      fontSize: 14.sp,
                      color: isConfirmed ? Colors.black : Colors.orange[800]
                    )
                  ),
                ],
              ),
            ),
            Icon(
              isConfirmed ? Icons.check_circle_rounded : Icons.add_location_alt_outlined, 
              color: isConfirmed ? Colors.green : Colors.grey[300], 
              size: 28
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTermsSection() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.amber.withOpacity(0.3), width: 1.5),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.security_rounded, color: Colors.amber, size: 28),
              const SizedBox(width: 10),
              Text("إقرار ومسؤولية قانونية", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15.sp)),
            ],
          ),
          const Divider(height: 35),
          _buildTermItem(
            "تطبيق 'أكسب' هو وسيط تقني فقط يربط بين الأطراف، ولا يتدخل في طبيعة أو جودة المنقولات، وتعتبر موافقتك إقراراً بمسؤوليتك الكاملة عن محتوى الطلب.",
            isBold: true
          ),
          _buildTermItem("يُمنع منعاً باتاً نقل الأموال، المشغولات الثمينة، أو المواد المحظورة قانوناً."),
          _buildTermItem("كود التسليم هو توقيعك؛ لا تعطه للمندوب إلا بعد فحص الأغراض."),
          _buildTermItem("طابق هوية المندوب وصورته من التطبيق قبل عملية التسليم."),
        ],
      ),
    );
  }

  Widget _buildTermItem(String text, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.verified_user_outlined, size: 14, color: isBold ? Colors.green : Colors.amber[700]).paddingOnly(top: 8),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text, 
              style: TextStyle(
                fontSize: 12.5.sp, 
                fontWeight: isBold ? FontWeight.w900 : FontWeight.w700, 
                color: isBold ? Colors.black : Colors.black87, 
                height: 1.4
              )
            )
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmButton() {
    return Container(
      width: double.infinity,
      height: 65,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(colors: [Color(0xFF43A047), Color(0xFF2E7D32)]),
        boxShadow: [BoxShadow(color: Colors.green.withOpacity(0.2), blurRadius: 15, offset: const Offset(0, 8))],
      ),
      child: ElevatedButton(
        onPressed: () {
          // هنا يتم ربط اللوكيشن النهائي (_pickupCoords) مع أمازون
        }, 
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent, 
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))
        ), 
        child: Text("تأكيد المسار والمتابعة", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16.sp, color: Colors.white))
      ),
    );
  }
}

extension OnWidget on Widget {
  Widget paddingOnly({double top = 0}) => Padding(padding: EdgeInsets.only(top: top), child: this);
}

