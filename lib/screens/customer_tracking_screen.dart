// lib/screens/customer_tracking_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:sizer/sizer.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';
import 'dart:ui' as ui;
import 'dart:math' show cos, sqrt, asin, atan2, pi;
import 'package:flutter/services.dart';

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
  String _estimatedTime = "جاري الحساب...";
  String _distanceRemaining = "";
  bool _isMapCreated = false;
  bool _hasInitialCenteringDone = false;
  final Set<Polyline> _polylines = {};

  @override
  void initState() {
    super.initState();
    _loadCustomMarker();
  }

  // إنشاء ماركر مخصص (أيقونة الموتوسيكل) برمجياً
  Future<void> _loadCustomMarker() async {
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);
    const double size = 120.0;

    final Paint circlePaint = Paint()..color = const Color(0xFF2D9E68).withOpacity(0.9);
    canvas.drawCircle(const Offset(size / 2, size / 2), size / 2.2, circlePaint);

    final Paint borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    canvas.drawCircle(const Offset(size / 2, size / 2), size / 2.2, borderPaint);

    TextPainter textPainter = TextPainter(textDirection: TextDirection.rtl);
    textPainter.text = TextSpan(
      text: String.fromCharCode(Icons.motorcycle.codePoint),
      style: TextStyle(
        fontSize: 80.0,
        fontFamily: Icons.motorcycle.fontFamily,
        color: Colors.white,
      ),
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset((size - textPainter.width) / 2, (size - textPainter.height) / 2));

    final ui.Image image = await pictureRecorder.endRecording().toImage(size.toInt(), size.toInt());
    final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);

    if (mounted) {
      setState(() {
        _driverIcon = BitmapDescriptor.fromBytes(byteData!.buffer.asUint8List());
      });
    }
  }

  // حساب المسافة والوقت المتوقع وزاوية الدوران
  void _updateDriverMetrics(LatLng currentPos, LatLng destination) {
    // 1. حساب زاوية الدوران (Rotation) ليكون اتجاه الموتوسيكل صحيحاً
    if (_lastDriverPosition != null) {
      double latRes = currentPos.latitude - _lastDriverPosition!.latitude;
      double lngRes = currentPos.longitude - _lastDriverPosition!.longitude;
      double angle = (atan2(lngRes, latRes) * 180 / pi);
      if (mounted) setState(() => _driverRotation = angle);
    }
    _lastDriverPosition = currentPos;

    // 2. حساب المسافة (Haversine formula)
    var p = 0.017453292519943295;
    var c = cos;
    var a = 0.5 -
        c((destination.latitude - currentPos.latitude) * p) / 2 +
        c(currentPos.latitude * p) *
            c(destination.latitude * p) *
            (1 - c((destination.longitude - currentPos.longitude) * p)) / 2;
    double dist = 12742 * asin(sqrt(a));

    if (mounted) {
      setState(() {
        _distanceRemaining = dist < 1 ? "${(dist * 1000).toInt()} متر" : "${dist.toStringAsFixed(1)} كم";
        // افتراض سرعة متوسطة 30 كم/ساعة + وقت ثابت للتوقفات
        _estimatedTime = "${((dist / 30) * 60).round() + 2} دقيقة";
        
        _polylines.clear();
        _polylines.add(Polyline(
          polylineId: const PolylineId("route"),
          points: [currentPos, destination],
          color: const Color(0xFF2D9E68).withOpacity(0.6),
          width: 5,
        ));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('specialRequests').doc(widget.orderId).snapshots(),
      builder: (context, orderSnapshot) {
        if (orderSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator(color: Color(0xFF2D9E68))));
        }
        if (!orderSnapshot.hasData || !orderSnapshot.data!.exists) {
          return const Scaffold(body: Center(child: Text("جاري تحديث بيانات الطلب...", style: TextStyle(fontFamily: 'Cairo'))));
        }

        var oData = orderSnapshot.data!.data() as Map<String, dynamic>;
        String status = oData['status'] ?? "pending";
        String? driverId = oData['driverId'];

        GeoPoint p = oData['pickupLocation'] ?? const GeoPoint(31.2001, 29.9187);
        GeoPoint d = oData['dropoffLocation'] ?? const GeoPoint(31.2001, 29.9187);
        LatLng pickup = LatLng(p.latitude, p.longitude);
        LatLng dropoff = LatLng(d.latitude, d.longitude);

        return StreamBuilder<DocumentSnapshot>(
          stream: (driverId != null && driverId.isNotEmpty)
              ? FirebaseFirestore.instance.collection('freeDrivers').doc(driverId).snapshots()
              : const Stream.empty(),
          builder: (context, driverSnapshot) {
            LatLng? dLoc;
            if (driverSnapshot.hasData && driverSnapshot.data!.exists) {
              var dd = driverSnapshot.data!.data() as Map<String, dynamic>;
              // دعم كلاً من نوع GeoPoint أو الحقول المنفصلة lat/lng
              if (dd['location'] != null) {
                GeoPoint loc = dd['location'];
                dLoc = LatLng(loc.latitude, loc.longitude);
              } else if (dd['lat'] != null && dd['lng'] != null) {
                dLoc = LatLng(dd['lat'], dd['lng']);
              }

              if (dLoc != null) {
                if (!_hasInitialCenteringDone) {
                  _mapController.future.then((c) => c.animateCamera(CameraUpdate.newLatLngZoom(dLoc!, 15)));
                  _hasInitialCenteringDone = true;
                }
                // تحديث القياسات في الإطار القادم لضمان استقرار الـ State
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) _updateDriverMetrics(dLoc!, status.contains('pickup') ? pickup : dropoff);
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
                  title: const Text(
                    "تتبع رابية أحلى",
                    style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                  centerTitle: true,
                  iconTheme: const IconThemeData(color: Colors.black87),
                ),
                body: Stack(
                  children: [
                    GoogleMap(
                      initialCameraPosition: CameraPosition(target: pickup, zoom: 14),
                      onMapCreated: (c) {
                        if (!_mapController.isCompleted) _mapController.complete(c);
                        setState(() => _isMapCreated = true);
                      },
                      polylines: _polylines,
                      myLocationButtonEnabled: false,
                      mapToolbarEnabled: false,
                      markers: {
                        Marker(
                          markerId: const MarkerId('p'),
                          position: pickup,
                          infoWindow: const InfoWindow(title: "نقطة الاستلام"),
                          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
                        ),
                        Marker(
                          markerId: const MarkerId('d'),
                          position: dropoff,
                          infoWindow: const InfoWindow(title: "نقطة التسليم"),
                          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
                        ),
                        if (dLoc != null)
                          Marker(
                            markerId: const MarkerId('dr'),
                            position: dLoc,
                            rotation: _driverRotation,
                            icon: _driverIcon ?? BitmapDescriptor.defaultMarker, // تصحيح: تم حذف الأقواس الزائدة
                            flat: true,
                            anchor: const Offset(0.5, 0.5),
                          ),
                      },
                    ),
                    if (_isMapCreated)
                      Align(
                        alignment: Alignment.bottomCenter,
                        child: Container(
                          margin: const EdgeInsets.all(20),
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(25),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, spreadRadius: 2)],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: const Color(0xFF2D9E68).withOpacity(0.1),
                                    child: const Icon(Icons.delivery_dining, color: Color(0xFF2D9E68)),
                                  ),
                                  const SizedBox(width: 15),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          oData['driverName'] ?? "جاري البحث عن مندوب...",
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo', fontSize: 16),
                                        ),
                                        Text(
                                          "المسافة المتبقية: $_distanceRemaining",
                                          style: TextStyle(color: Colors.grey[600], fontSize: 12, fontFamily: 'Cairo'),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    children: [
                                      const Text("يصل خلال", style: TextStyle(fontSize: 10, fontFamily: 'Cairo')),
                                      Text(
                                        _estimatedTime,
                                        style: const TextStyle(color: Color(0xFF2D9E68), fontWeight: FontWeight.bold, fontSize: 16, fontFamily: 'Cairo'),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              if (oData['driverPhone'] != null) ...[
                                const Divider(height: 30),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: () => launchUrl(Uri.parse("tel:${oData['driverPhone']}")),
                                    icon: const Icon(Icons.phone_forwarded),
                                    label: const Text("اتصال بالمندوب", style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF2D9E68),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                                    ),
                                  ),
                                ),
                              ]
                            ],
                          ),
                        ),
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
}

