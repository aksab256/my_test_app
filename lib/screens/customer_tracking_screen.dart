import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart'; // محرك الخرائط الجديد
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
  final Completer<GoogleMapController> _googleMapController = Completer<GoogleMapController>();
  BitmapDescriptor? _driverIcon;
  double _driverRotation = 0;
  LatLng? _lastDriverPosition;
  String _estimatedTime = "جاري الحساب...";
  String _distanceRemaining = "";
  bool _isMapCreated = false;
  bool _hasInitialCenteringDone = false;

  // ✅ إصلاح: حالات نهائية صريحة بدل الاعتماد على substring matching
  // (كان status.contains('cancelled') يمسك 'driver_cancelled_reseeking' غلط،
  // وكانت rejected_by_system مش متغطية خالص)
  static const Set<String> _finalExitStatuses = {
    'cancelled_by_user_before_accept',
    'cancelled_by_user_after_accept',
    'cancelled',
    'no_drivers_available',
    'rejected_by_system',
  };

  // الحالات اللي المندوب لسه رايح فيها لمكان الاستلام (قبل أخد الشحنة)
  static const Set<String> _headingToPickupStatuses = {'accepted', 'at_pickup'};

  @override
  void initState() {
    super.initState();
    _loadCustomMarker();
  }

  // إنشاء ماركر المندوب المخصص (الموتوسيكل)
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

  // ✅ سرعة متوسطة تقديرية لكل نوع مركبة (كم/س) - بديل عن الرقم الثابت 30
  // اتحسبت بشكل واقعي: الموتوسيكل أسرع في الزحمة والشوارع الضيقة،
  // الجامبو أبطأ بسبب الحجم والحمولة
  static double _averageSpeedFor(String? vehicleType) {
    switch (vehicleType) {
      case 'motorcycle':
        return 35.0;
      case 'pickup':
        return 28.0;
      case 'jumbo':
        return 22.0;
      default:
        return 30.0;
    }
  }

  // دالة حساب المسافة والوقت والتدوير (المنطق المحسن)
  // ✅ إصلاح: بقت بتستقبل الوجهة الصحيحة من الخارج بدل ما تحددها بنفسها بـ substring
  // ✅ إصلاح: السرعة بقت مرتبطة بنوع المركبة بدل رقم ثابت لكل الأنواع
  void _calculateMetrics(LatLng currentPos, LatLng destination, String? vehicleType) {
    if (_lastDriverPosition != null && _lastDriverPosition != currentPos) {
      double latRes = currentPos.latitude - _lastDriverPosition!.latitude;
      double lngRes = currentPos.longitude - _lastDriverPosition!.longitude;
      _driverRotation = (atan2(lngRes, latRes) * 180 / pi);
    }
    _lastDriverPosition = currentPos;

    var p = 0.017453292519943295;
    var c = cos;
    var a = 0.5 - c((destination.latitude - currentPos.latitude) * p) / 2 +
        c(currentPos.latitude * p) * c(destination.latitude * p) *
            (1 - c((destination.longitude - currentPos.longitude) * p)) / 2;
    double dist = 12742 * asin(sqrt(a));

    double speed = _averageSpeedFor(vehicleType);

    _distanceRemaining = dist < 1 ? "${(dist * 1000).toInt()} م" : "${dist.toStringAsFixed(1)} كم";
    _estimatedTime = "${((dist / speed) * 60).round() + 2} د";
  }

  // نافذة التقييم (من الكود الأصلي 2048e61)
  void _showRatingDialog(BuildContext context, String driverId) {
    double selectedRating = 5;
    TextEditingController commentController = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text("تقييم تجربة التوصيل", textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("لقد تم تسليم طلبك بنجاح! قيم المندوب للمساعدة في تحسين الخدمة.", style: TextStyle(fontFamily: 'Cairo')),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) {
                    return IconButton(
                      icon: Icon(index < selectedRating ? Icons.star_rounded : Icons.star_outline_rounded, color: Colors.amber, size: 35),
                      onPressed: () => setState(() => selectedRating = index + 1.0),
                    );
                  }),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: commentController,
                  decoration: InputDecoration(
                    hintText: "ملاحظاتك (اختياري)...",
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: Colors.grey[50],
                  ),
                  maxLines: 2,
                ),
              ],
            ),
            actions: [
              Center(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2D9E68),
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                  onPressed: () async {
                    await FirebaseFirestore.instance.collection('specialRequests').doc(widget.orderId).update({
                      'rating': selectedRating,
                      'customerComment': commentController.text,
                      'status': 'delivered'
                    });
                    if (driverId.isNotEmpty) {
                      await FirebaseFirestore.instance.collection('freeDrivers').doc(driverId).update({
                        'totalStars': FieldValue.increment(selectedRating),
                        'reviewsCount': FieldValue.increment(1),
                      });
                    }
                    if (context.mounted) Navigator.of(context).popUntil((route) => route.isFirst);
                  },
                  child: const Text("تأكيد التقييم", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // الإلغاء الذكي (من الكود الأصلي 2048e61)
  Future<void> _handleSmartCancel(BuildContext context, String currentStatus) async {
    bool isAccepted = currentStatus != 'pending';
    String targetStatus = isAccepted ? 'cancelled_by_user_after_accept' : 'cancelled_by_user_before_accept';

    if (isAccepted) {
      bool confirm = await showDialog(
        context: context,
        builder: (ctx) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text("تنبيه هام", style: TextStyle(fontFamily: 'Cairo')),
            content: const Text("المندوب في طريقه إليك الآن. إلغاء الطلب الآن سيؤدي لخصم تعويض للمندوب من نقاطك. هل تريد الاستمرار؟", style: TextStyle(fontFamily: 'Cairo')),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("تراجع")),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text("تأكيد وإلغاء", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ) ?? false;
      if (!confirm) return;
    }
    try {
      await FirebaseFirestore.instance.collection('specialRequests').doc(widget.orderId).update({
        'status': targetStatus,
        'cancelledAt': FieldValue.serverTimestamp(),
        'cancelledBy': 'customer'
      });
      if (context.mounted) Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      debugPrint("Cancel Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.orderId.isEmpty) return const Scaffold(body: Center(child: Text("طلب غير موجود")));

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('specialRequests').doc(widget.orderId).snapshots(),
      builder: (context, orderSnapshot) {
        if (!orderSnapshot.hasData || !orderSnapshot.data!.exists) {
          return const Scaffold(body: Center(child: CircularProgressIndicator(color: Color(0xFF2D9E68))));
        }

        var orderData = orderSnapshot.data!.data() as Map<String, dynamic>;
        String status = orderData['status'] ?? "pending";
        bool isRated = orderData.containsKey('rating');

        // ✅ إصلاح: التعامل مع الحالات النهائية بشكل صريح (بدل .contains('cancelled')
        // اللي كان بيمسك 'driver_cancelled_reseeking' غلط ويخرج العميل من الشاشة
        // رغم إن النظام لسه بيدور على مندوب تاني، وكان مش بيغطي rejected_by_system خالص)
        bool isFinalExit = _finalExitStatuses.contains(status) || (status == 'delivered' && isRated);
        if (isFinalExit) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) {
              String? message;
              if (status == 'no_drivers_available') {
                message = "عذراً، لم نجد مناديب متاحة حالياً لطلبك.";
              } else if (status == 'rejected_by_system') {
                message = "تعذر تنفيذ الطلب، برجاء مراجعة تفاصيل الشحنة.";
              }
              if (message != null) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.redAccent));
              }
              Navigator.of(context).popUntil((route) => route.isFirst);
            }
          });
        }

        if (status == 'delivered' && !isRated) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _showRatingDialog(context, orderData['driverId'] ?? "");
          });
        }

        String? driverId = orderData['driverId'];
        String verificationCode = orderData['verificationCode'] ?? "----";
        GeoPoint pickup = orderData['pickupLocation'];
        GeoPoint dropoff = orderData['dropoffLocation'];
        LatLng pickupLatLng = LatLng(pickup.latitude, pickup.longitude);
        LatLng dropoffLatLng = LatLng(dropoff.latitude, dropoff.longitude);

        // ✅ إصلاح: تحديد الوجهة بشكل صريح - المندوب رايح لمكان الاستلام لسه
        // في accepted و at_pickup، وبعدها يبقى رايح للتسليم
        bool headedToPickup = _headingToPickupStatuses.contains(status);
        LatLng navigationTarget = headedToPickup ? pickupLatLng : dropoffLatLng;

        return StreamBuilder<DocumentSnapshot>(
          stream: (driverId != null && driverId.isNotEmpty)
              ? FirebaseFirestore.instance.collection('freeDrivers').doc(driverId).snapshots()
              : const Stream.empty(),
          builder: (context, driverSnapshot) {
            LatLng? driverLatLng;
            Map<String, dynamic>? driverData;

            if (driverSnapshot.hasData && driverSnapshot.data!.exists) {
              driverData = driverSnapshot.data!.data() as Map<String, dynamic>;
              if (driverData != null) {
                if (driverData['location'] != null) {
                  GeoPoint dLoc = driverData['location'];
                  driverLatLng = LatLng(dLoc.latitude, dLoc.longitude);
                } else if (driverData['lat'] != null) {
                  driverLatLng = LatLng(driverData['lat'], driverData['lng']);
                }

                if (driverLatLng != null) {
                  _calculateMetrics(driverLatLng, navigationTarget, orderData['vehicleType'] as String?);
                  if (!_hasInitialCenteringDone) {
                    _googleMapController.future.then((c) => c.animateCamera(CameraUpdate.newLatLngZoom(driverLatLng!, 15)));
                    _hasInitialCenteringDone = true;
                  }
                }
              }
            }

            return Directionality(
              textDirection: TextDirection.rtl,
              child: Scaffold(
                extendBodyBehindAppBar: true,
                appBar: AppBar(
                  backgroundColor: Colors.white.withOpacity(0.9),
                  elevation: 0,
                  iconTheme: const IconThemeData(color: Colors.black),
                  title: Text("تتبع الرحلة", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16.sp, color: Colors.black, fontFamily: 'Cairo')),
                  centerTitle: true,
                ),
                body: Stack(
                  children: [
                    GoogleMap(
                      initialCameraPosition: CameraPosition(target: driverLatLng ?? pickupLatLng, zoom: 14.5),
                      onMapCreated: (c) {
                        if (!_googleMapController.isCompleted) _googleMapController.complete(c);
                        if (!_isMapCreated) setState(() => _isMapCreated = true);
                      },
                      polylines: {
                        if (driverLatLng != null)
                          Polyline(
                            polylineId: const PolylineId("route"),
                            points: [driverLatLng, navigationTarget],
                            color: const Color(0xFF2D9E68).withOpacity(0.6),
                            width: 5,
                          ),
                      },
                      markers: {
                        Marker(markerId: const MarkerId('p'), position: pickupLatLng, icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen)),
                        Marker(markerId: const MarkerId('d'), position: dropoffLatLng, icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed)),
                        if (driverLatLng != null)
                          Marker(
                            markerId: const MarkerId('dr'),
                            position: driverLatLng,
                            rotation: _driverRotation,
                            icon: _driverIcon ?? BitmapDescriptor.defaultMarker,
                            flat: true,
                            anchor: const Offset(0.5, 0.5),
                          ),
                      },
                    ),
                    if (_isMapCreated)
                      Align(
                        alignment: Alignment.bottomCenter,
                        child: SafeArea(
                          child: _buildUnifiedBottomPanel(context, status, orderData, driverData, verificationCode),
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

  Widget _buildUnifiedBottomPanel(BuildContext context, String status, Map<String, dynamic> order, Map<String, dynamic>? driver, String code) {
    double progress = 0.1;
    String statusDesc = "بانتظار قبول مندوب...";
    Color mainColor = Colors.orange;

    if (status == 'accepted') {
      progress = 0.4;
      statusDesc = "المندوب وافق وفي طريقه إليك";
      mainColor = Colors.blue;
    } else if (status == 'at_pickup') {
      progress = 0.6;
      statusDesc = "المندوب وصل لموقع الاستلام";
      mainColor = Colors.indigo;
    } else if (status == 'picked_up') {
      progress = 0.8;
      statusDesc = "جاري التوصيل الآن";
      mainColor = Colors.green;
    } else if (status == 'driver_cancelled_reseeking') {
      // ✅ حالة نشطة (مش نهائية) - النظام بيدور على مندوب تاني
      progress = 0.2;
      statusDesc = "المندوب السابق ألغى، جاري البحث عن مندوب آخر...";
      mainColor = Colors.deepOrange;
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(10, 0, 10, 15),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 15)]
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(child: LinearProgressIndicator(value: progress, minHeight: 6, backgroundColor: Colors.grey[200], color: mainColor)),
              const SizedBox(width: 10),
              Text("${(progress * 100).toInt()}%", style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          Text(statusDesc, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13.sp, color: mainColor, fontFamily: 'Cairo')),

          if (status == 'accepted' || status == 'at_pickup' || status == 'picked_up') ...[
            const Divider(height: 25),
            Container(
              margin: const EdgeInsets.only(bottom: 15),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.amber[50], borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.amber)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.security, color: Colors.amber),
                  const SizedBox(width: 10),
                  const Text("كود التسليم: ", style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
                  Text(code, style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w900, color: Colors.red[900])),
                ],
              ),
            ),
          ],

          // خلال إعادة البحث عن مندوب، لا يوجد مندوب حالي لعرضه
          if (status != 'driver_cancelled_reseeking' && status != 'pending')
            Row(
              children: [
                CircleAvatar(radius: 25, backgroundColor: Colors.blue[50], child: const Icon(Icons.person, color: Colors.blue)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(driver != null ? (driver['fullname'] ?? driver['driverName'] ?? "مندوب رابية") : "جاري البحث...", style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          _MetricPill(icon: Icons.access_time_filled, label: _estimatedTime, color: mainColor),
                          const SizedBox(width: 6),
                          _MetricPill(icon: Icons.route, label: _distanceRemaining, color: Colors.grey[600]!),
                        ],
                      ),
                    ],
                  ),
                ),
                if (driver != null && (driver['phone'] != null || order['driverPhone'] != null))
                  IconButton(
                    onPressed: () async => await launchUrl(Uri.parse("tel:${driver['phone'] ?? order['driverPhone']}")),
                    icon: const Icon(Icons.phone_in_talk, color: Colors.green, size: 30),
                  ),
              ],
            )
          else if (status == 'pending')
            const Row(
              children: [
                CircleAvatar(radius: 25, backgroundColor: Color(0xFFE3F2FD), child: Icon(Icons.person_search, color: Colors.blue)),
                SizedBox(width: 12),
                Expanded(
                  child: Text("جاري البحث عن مندوب متاح...", style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
                ),
              ],
            ),

          // ✅ إصلاح: تفعيل زرار الإلغاء أثناء البحث عن مندوب تاني بعد إلغاء المندوب السابق
          if (status == 'pending' || status == 'accepted' || status == 'at_pickup' || status == 'driver_cancelled_reseeking')
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: TextButton(
                onPressed: () => _handleSmartCancel(context, status),
                child: const Text("إلغاء الطلب", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
              ),
            ),
        ],
      ),
    );
  }
}

/// مؤشر صغير (Pill) لعرض قيمة مقاسة (وقت أو مسافة) مع أيقونة
class _MetricPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _MetricPill({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    if (label.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color, fontFamily: 'Cairo')),
        ],
      ),
    );
  }
}