import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:sizer/sizer.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';
import 'dart:ui' as ui;
import 'dart:math' show cos, sqrt, asin;

class CustomerTrackingScreen extends StatefulWidget {
  static const routeName = '/customerTracking';
  final String orderId;

  const CustomerTrackingScreen({super.key, required this.orderId});

  @override
  State<CustomerTrackingScreen> createState() => _CustomerTrackingScreenState();
}

class _CustomerTrackingScreenState extends State<CustomerTrackingScreen> {
  final Completer<GoogleMapController> _mapController = Completer<GoogleMapController>();
  BitmapDescriptor? _driverIcon;
  double _driverRotation = 0;
  LatLng? _lastDriverPosition;
  String _estimatedTime = "";
  String _distanceRemaining = "";
  bool _isMapCreated = false;

  @override
  void initState() {
    super.initState();
    _loadCustomMarker();
  }

  Future<void> _loadCustomMarker() async {
    // أيقونة المندوب (سيارة أو موتوسيكل) بلون مميز
    _driverIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure);
  }

  // حساب المسافة والوقت (Haversine formula)
  void _calculateETA(LatLng driver, LatLng destination) {
    var p = 0.017453292519943295;
    var c = cos;
    var a = 0.5 - c((destination.latitude - driver.latitude) * p) / 2 +
        c(driver.latitude * p) * c(destination.latitude * p) *
            (1 - c((destination.longitude - driver.longitude) * p)) / 2;
    double distanceInKm = 12742 * asin(sqrt(a));
    
    // افتراض سرعة متوسطة 30 كم/ساعة في زحمة الإسكندرية
    int travelMinutes = ((distanceInKm / 30) * 60).round() + 2;

    if (mounted) {
      setState(() {
        _distanceRemaining = distanceInKm < 1
            ? "${(distanceInKm * 1000).toInt()} متر"
            : "${distanceInKm.toStringAsFixed(1)} كم";
        _estimatedTime = "$travelMinutes دقيقة";
      });
    }
  }

  double _calculateRotation(LatLng start, LatLng end) {
    double latDiff = (end.latitude - start.latitude).abs();
    double lngDiff = (end.longitude - start.longitude).abs();
    double rotation = 0;
    if (start.latitude < end.latitude && start.longitude < end.longitude) {
      rotation = (57.2957795 * (ui.Offset(lngDiff, latDiff).direction));
    } else if (start.latitude >= end.latitude && start.longitude < end.longitude) {
      rotation = 90 + (57.2957795 * (ui.Offset(latDiff, lngDiff).direction));
    } else if (start.latitude >= end.latitude && start.longitude >= end.longitude) {
      rotation = 180 + (57.2957795 * (ui.Offset(lngDiff, latDiff).direction));
    } else if (start.latitude < end.latitude && start.longitude >= end.longitude) {
      rotation = 270 + (57.2957795 * (ui.Offset(latDiff, lngDiff).direction));
    }
    return rotation;
  }

  Future<void> _animateCameraToDriver(LatLng location) async {
    if (!_isMapCreated) return;
    try {
      final GoogleMapController controller = await _mapController.future;
      controller.animateCamera(CameraUpdate.newLatLng(location));
    } catch (e) {
      debugPrint("Map Animation Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.orderId.isEmpty) return const Scaffold(body: Center(child: Text("طلب غير موجود")));

    return StreamBuilder<DocumentSnapshot>(
      // المطابقة مع الـ Collection المذكورة في طلبك
      stream: FirebaseFirestore.instance.collection('specialRequests').doc(widget.orderId).snapshots(),
      builder: (context, orderSnapshot) {
        if (!orderSnapshot.hasData || !orderSnapshot.data!.exists) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        var orderData = orderSnapshot.data!.data() as Map<String, dynamic>;
        String status = orderData['status'] ?? "pending";
        String? driverId = orderData['driverId'];
        
        // جلب المواقع من GeoPoint (مطابق لبياناتك)
        GeoPoint pickup = orderData['pickupLocation'];
        GeoPoint dropoff = orderData['dropoffLocation'];
        LatLng pickupLatLng = LatLng(pickup.latitude, pickup.longitude);
        LatLng dropoffLatLng = LatLng(dropoff.latitude, dropoff.longitude);

        return StreamBuilder<DocumentSnapshot>(
          stream: (driverId != null && driverId.isNotEmpty)
              ? FirebaseFirestore.instance.collection('freeDrivers').doc(driverId).snapshots()
              : const Stream.empty(),
          builder: (context, driverSnapshot) {
            LatLng? driverLatLng;
            Map<String, dynamic>? driverData;

            if (driverSnapshot.hasData && driverSnapshot.data!.exists) {
              driverData = driverSnapshot.data!.data() as Map<String, dynamic>;
              // التحقق من صيغة الموقع في تطبيق المندوب
              if (driverData.containsKey('lat') && driverData.containsKey('lng')) {
                driverLatLng = LatLng(driverData['lat'], driverData['lng']);
              } else if (driverData.containsKey('location')) {
                GeoPoint dLoc = driverData['location'];
                driverLatLng = LatLng(dLoc.latitude, dLoc.longitude);
              }

              if (driverLatLng != null) {
                if (_lastDriverPosition != null && _lastDriverPosition != driverLatLng) {
                  _driverRotation = _calculateRotation(_lastDriverPosition!, driverLatLng!);
                }
                _lastDriverPosition = driverLatLng;
                _animateCameraToDriver(driverLatLng!);

                // تحديد الوجهة بناءً على حالة الطلب
                LatLng destination = (status == 'accepted' || status == 'at_pickup') ? pickupLatLng : dropoffLatLng;
                
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) _calculateETA(driverLatLng!, destination);
                });
              }
            }

            return Directionality(
              textDirection: TextDirection.rtl,
              child: Scaffold(
                extendBodyBehindAppBar: true,
                appBar: AppBar(
                  backgroundColor: Colors.white.withOpacity(0.9),
                  elevation: 0,
                  title: Text("تتبع رابية أحلى", style: TextStyle(fontFamily: 'Cairo', fontSize: 13.sp, fontWeight: FontWeight.bold)),
                  centerTitle: true,
                ),
                body: Stack(
                  children: [
                    GoogleMap(
                      initialCameraPosition: CameraPosition(target: pickupLatLng, zoom: 15),
                      onMapCreated: (c) {
                        if (!_mapController.isCompleted) _mapController.complete(c);
                        setState(() => _isMapCreated = true);
                      },
                      zoomControlsEnabled: false,
                      myLocationButtonEnabled: false,
                      markers: {
                        Marker(
                          markerId: const MarkerId('pickup'),
                          position: pickupLatLng,
                          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
                          infoWindow: const InfoWindow(title: "موقع المتجر"),
                        ),
                        Marker(
                          markerId: const MarkerId('dropoff'),
                          position: dropoffLatLng,
                          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
                          infoWindow: const InfoWindow(title: "موقع التسليم"),
                        ),
                        if (driverLatLng != null)
                          Marker(
                            markerId: const MarkerId('driver'),
                            position: driverLatLng!,
                            rotation: _driverRotation,
                            icon: _driverIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
                            anchor: const Offset(0.5, 0.5),
                            flat: true,
                          ),
                      },
                    ),

                    // كارت الوقت والمسافة (ETA)
                    if (_estimatedTime.isNotEmpty && status != 'pending' && status != 'delivered')
                      Positioned(
                        top: 10.h,
                        left: 15,
                        right: 15,
                        child: _buildEtaCard(),
                      ),

                    Align(
                      alignment: Alignment.bottomCenter,
                      child: _buildBottomPanel(status, orderData, driverData),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildEtaCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 4))],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildInfoItem("الوقت المتوقع", _estimatedTime, Icons.access_time),
          Container(width: 1, height: 30, color: Colors.grey[200]),
          _buildInfoItem("المسافة المتبقية", _distanceRemaining, Icons.directions_bike),
        ],
      ),
    );
  }

  Widget _buildInfoItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: Colors.blue),
            const SizedBox(width: 5),
            Text(label, style: TextStyle(fontFamily: 'Cairo', fontSize: 9.sp, color: Colors.grey[600])),
          ],
        ),
        Text(value, style: TextStyle(fontFamily: 'Cairo', fontSize: 11.sp, fontWeight: FontWeight.bold, color: Colors.blue[900])),
      ],
    );
  }

  Widget _buildBottomPanel(String status, Map<String, dynamic> order, Map<String, dynamic>? driver) {
    double progress = 0.1;
    String statusDesc = "بانتظار قبول المندوب...";
    Color statusColor = Colors.orange;

    if (status == 'accepted') {
      progress = 0.4;
      statusDesc = "المندوب في طريقه للمحل";
      statusColor = Colors.blue;
    } else if (status == 'at_pickup') {
      progress = 0.6;
      statusDesc = "المندوب يقوم باستلام الطلب الآن";
      statusColor = Colors.indigo;
    } else if (status == 'picked_up') {
      progress = 0.8;
      statusDesc = "الطلب في عهدة المندوب وفي الطريق إليك";
      statusColor = Colors.green;
    } else if (status == 'delivered') {
      progress = 1.0;
      statusDesc = "تم تأكيد استلام الأمانات بنجاح";
      statusColor = Colors.teal;
    }

    return Container(
      margin: const EdgeInsets.all(15),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 15)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          LinearProgressIndicator(value: progress, backgroundColor: Colors.grey[100], color: statusColor, minHeight: 6),
          const SizedBox(height: 15),

          // عرض كود التحقق (verificationCode) بشكل بارز للعميل
          if (status != 'delivered' && order.containsKey('verificationCode'))
            Container(
              margin: const EdgeInsets.only(bottom: 15),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue[100]!),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("كود تأمين العهدة:", style: TextStyle(fontFamily: 'Cairo', fontSize: 10.sp)),
                  Text(
                    "${order['verificationCode']}",
                    style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16.sp, letterSpacing: 2, color: Colors.blue[900]),
                  ),
                ],
              ),
            ),

          Text(statusDesc, style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 12.sp, color: statusColor)),
          const Divider(height: 25),
          
          Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.grey[100],
                child: Icon(Icons.person, color: Colors.blue[900]),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(order['driverName'] ?? "جاري البحث...", style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                    if (order.containsKey('insurance_points'))
                      Text("نقاط تأمين: ${order['insurance_points']} ج.م", style: TextStyle(fontFamily: 'Cairo', fontSize: 9.sp, color: Colors.grey)),
                  ],
                ),
              ),
              if (driver != null && driver.containsKey('phone'))
                IconButton(
                  onPressed: () => launchUrl(Uri.parse("tel:${driver['phone']}")),
                  icon: const Icon(Icons.phone_in_talk, color: Colors.green),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

