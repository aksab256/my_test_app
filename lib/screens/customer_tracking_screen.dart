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
  bool _hasInitialCenteringDone = false; // لمنع تجمد الخريطة
  final Set<Polyline> _polylines = {}; // لرسم الخط

  @override
  void initState() {
    super.initState();
    _loadCustomMarker();
  }

  Future<void> _loadCustomMarker() async {
    _driverIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure);
  }

  void _calculateETA(LatLng driver, LatLng destination) {
    var p = 0.017453292519943295;
    var c = cos;
    var a = 0.5 - c((destination.latitude - driver.latitude) * p) / 2 +
        c(driver.latitude * p) * c(destination.latitude * p) *
            (1 - c((destination.longitude - driver.longitude) * p)) / 2;
    double distanceInKm = 12742 * asin(sqrt(a));
    int travelMinutes = ((distanceInKm / 30) * 60).round() + 2;

    if (mounted) {
      setState(() {
        _distanceRemaining = distanceInKm < 1
            ? "${(distanceInKm * 1000).toInt()} متر"
            : "${distanceInKm.toStringAsFixed(1)} كم";
        _estimatedTime = "$travelMinutes دقيقة";
        
        // تحديث الخط المرسوم
        _polylines.clear();
        _polylines.add(Polyline(
          polylineId: const PolylineId("route"),
          points: [driver, destination],
          color: Colors.blue.withOpacity(0.7),
          width: 5,
          jointType: JointType.round,
        ));
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

  Future<void> _animateCameraOnce(LatLng location) async {
    if (!_isMapCreated || _hasInitialCenteringDone) return;
    try {
      final GoogleMapController controller = await _mapController.future;
      controller.animateCamera(CameraUpdate.newLatLngZoom(location, 15));
      _hasInitialCenteringDone = true; 
    } catch (e) {
      debugPrint("Map Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.orderId.isEmpty) return const Scaffold(body: Center(child: Text("طلب غير موجود")));

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('specialRequests').doc(widget.orderId).snapshots(),
      builder: (context, orderSnapshot) {
        if (!orderSnapshot.hasData || !orderSnapshot.data!.exists) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        var orderData = orderSnapshot.data!.data() as Map<String, dynamic>;
        String status = orderData['status'] ?? "pending";
        String? driverId = orderData['driverId'];
        
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
              if (driverData.containsKey('location')) {
                GeoPoint dLoc = driverData['location'];
                driverLatLng = LatLng(dLoc.latitude, dLoc.longitude);
              } else if (driverData.containsKey('lat')) {
                driverLatLng = LatLng(driverData['lat'], driverData['lng']);
              }

              if (driverLatLng != null) {
                if (_lastDriverPosition != null && _lastDriverPosition != driverLatLng) {
                  _driverRotation = _calculateRotation(_lastDriverPosition!, driverLatLng!);
                }
                _lastDriverPosition = driverLatLng;
                _animateCameraOnce(driverLatLng!);

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
                  backgroundColor: Colors.white.withOpacity(0.8),
                  elevation: 0,
                  title: Text("تتبع رابية أحلى", style: TextStyle(fontFamily: 'Cairo', fontSize: 13.sp, fontWeight: FontWeight.bold)),
                  centerTitle: true,
                  shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(bottom: Radius.circular(20))),
                ),
                body: Stack(
                  children: [
                    GoogleMap(
                      initialCameraPosition: CameraPosition(target: pickupLatLng, zoom: 15),
                      onMapCreated: (c) {
                        if (!_mapController.isCompleted) _mapController.complete(c);
                        setState(() => _isMapCreated = true);
                      },
                      polylines: _polylines,
                      zoomControlsEnabled: false,
                      myLocationButtonEnabled: false,
                      scrollGesturesEnabled: true, // تفعيل التحريك الحر
                      rotateGesturesEnabled: true,
                      markers: {
                        Marker(
                          markerId: const MarkerId('pickup'),
                          position: pickupLatLng,
                          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
                        ),
                        Marker(
                          markerId: const MarkerId('dropoff'),
                          position: dropoffLatLng,
                          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
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

                    // الكارت العلوي المحسن في منطقة آمنة
                    if (_estimatedTime.isNotEmpty && status != 'delivered')
                      Positioned(
                        top: MediaQuery.of(context).padding.top + 70, // أسفل الـ AppBar مباشرة
                        left: 12,
                        right: 12,
                        child: _buildEnhancedEtaCard(),
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

  Widget _buildEnhancedEtaCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 10))],
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 10),
            child: Row(
              children: [
                Expanded(child: _buildInfoColumn("الوصول خلال", _estimatedTime, Icons.timer_outlined, Colors.blue)),
                Container(width: 1, height: 40, color: Colors.grey[200]),
                Expanded(child: _buildInfoColumn("المسافة", _distanceRemaining, Icons.straighten_outlined, Colors.orange)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoColumn(String title, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(title, style: TextStyle(fontFamily: 'Cairo', fontSize: 8.sp, color: Colors.grey[600])),
        Text(value, style: TextStyle(fontFamily: 'Cairo', fontSize: 11.sp, fontWeight: FontWeight.bold, color: Colors.black87)),
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
      statusDesc = "المندوب يقوم باستلام الطلب";
      statusColor = Colors.indigo;
    } else if (status == 'picked_up') {
      progress = 0.8;
      statusDesc = "الطلب في عهدة المندوب";
      statusColor = Colors.green;
    } else if (status == 'delivered') {
      progress = 1.0;
      statusDesc = "تم تأكيد استلام الأمانات";
      statusColor = Colors.teal;
    }

    return Container(
      margin: const EdgeInsets.only(left: 15, right: 15, bottom: 25),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 20)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          LinearProgressIndicator(value: progress, backgroundColor: Colors.grey[100], color: statusColor, minHeight: 8),
          const SizedBox(height: 15),

          if (status != 'delivered' && order.containsKey('verificationCode'))
            _buildVerificationCard(order['verificationCode'].toString()),

          Text(statusDesc, style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 12.5.sp, color: statusColor)),
          const Divider(height: 30),
          
          Row(
            children: [
              CircleAvatar(backgroundColor: Colors.blue[50], radius: 25, child: Icon(Icons.person, color: Colors.blue[900], size: 30)),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(order['driverName'] ?? "جاري البحث...", style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                    if (order.containsKey('insurance_points'))
                      Text("تأمين العهدة: ${order['insurance_points']} ج.م", style: TextStyle(fontFamily: 'Cairo', fontSize: 9.sp, color: Colors.grey[600])),
                  ],
                ),
              ),
              if (driver != null && driver.containsKey('phone'))
                Material(
                  color: Colors.green[50],
                  shape: const CircleBorder(),
                  child: IconButton(
                    onPressed: () => launchUrl(Uri.parse("tel:${driver['phone']}")),
                    icon: const Icon(Icons.phone, color: Colors.green),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVerificationCard(String code) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 15),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [Colors.blue[900]!, Colors.blue[700]!]),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text("كود تأمين العهدة", style: TextStyle(fontFamily: 'Cairo', color: Colors.white70, fontSize: 10.sp)),
          Text(code, style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16.sp, color: Colors.white, letterSpacing: 2)),
        ],
      ),
    );
  }
}

