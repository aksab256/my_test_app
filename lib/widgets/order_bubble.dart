// lib/widgets/order_bubble.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sizer/sizer.dart';
import '../screens/customer_tracking_screen.dart';
import '../services/bubble_service.dart';
import '../main.dart'; 

class OrderBubble extends StatefulWidget {
  final String orderId;
  const OrderBubble({super.key, required this.orderId});

  @override
  State<OrderBubble> createState() => _OrderBubbleState();
}

class _OrderBubbleState extends State<OrderBubble> with SingleTickerProviderStateMixin {
  Offset position = Offset(80.w, 70.h);
  late AnimationController _pulseController;
  bool _ratingShown = false; // لمنع تكرار ظهور ديالوج التقييم

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _clearOrder() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('active_special_order_id');
    BubbleService.hide();
  }

  // 🛡️ الترتيب الصحيح للإلغاء لمنع الشاشة السوداء
  Future<void> _handleSmartCancelFromBubble(String currentStatus) async {
    bool isAccepted = currentStatus != 'pending';
    String targetStatus = isAccepted 
        ? 'cancelled_by_user_after_accept' 
        : 'cancelled_by_user_before_accept';

    try {
      await FirebaseFirestore.instance.collection('specialRequests').doc(widget.orderId).update({
        'status': targetStatus,
        'cancelledAt': FieldValue.serverTimestamp(),
        'cancelledBy': 'customer'
      });
      
      if (mounted) {
        navigatorKey.currentState?.pushNamedAndRemoveUntil('/', (route) => false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isAccepted ? "تم الإلغاء (سيتم مراجعة نقاطك)" : "تم إلغاء الطلب بنجاح"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
      await _clearOrder();
    } catch (e) {
      debugPrint("Bubble Cancel Error: $e");
    }
  }

  // ⭐ نظام التقييم الاحترافي
  void _showRatingDialog(String? driverId, String driverName) {
    double selectedRating = 5.0;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
            title: Column(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.green, size: 45.sp),
                const SizedBox(height: 10),
                const Text("وصل طلبك!", style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("كيف كانت تجربتك مع $driverName؟", textAlign: TextAlign.center, style: const TextStyle(fontFamily: 'Cairo')),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) {
                    return GestureDetector(
                      onTap: () => setDialogState(() => selectedRating = index + 1.0),
                      child: Icon(
                        index < selectedRating ? Icons.star_rounded : Icons.star_outline_rounded,
                        color: Colors.amber,
                        size: 32.sp,
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 10),
                Text(_getRatingText(selectedRating), style: TextStyle(color: Colors.orange[900], fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
              ],
            ),
            actions: [
              Column(
                children: [
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange[900],
                      minimumSize: Size(60.w, 45),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    ),
                    onPressed: () async {
                      if (driverId != null) await _submitRating(driverId, selectedRating);
                      Navigator.pop(ctx);
                      _clearOrder();
                    },
                    child: const Text("إرسال التقييم", style: TextStyle(color: Colors.white, fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _clearOrder();
                    },
                    child: const Text("تخطي", style: TextStyle(color: Colors.grey, fontFamily: 'Cairo')),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getRatingText(double rating) {
    if (rating == 5) return "ممتاز جداً 🔥";
    if (rating >= 4) return "جيد جداً 👍";
    if (rating >= 3) return "مقبول 🙂";
    return "ضعيف 😞";
  }

  Future<void> _submitRating(String driverId, double rating) async {
    await FirebaseFirestore.instance.collection('freeDrivers').doc(driverId).update({
      'totalStars': FieldValue.increment(rating),
      'reviewsCount': FieldValue.increment(1),
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('specialRequests').doc(widget.orderId).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) return const SizedBox.shrink();

        var data = snapshot.data!.data() as Map<String, dynamic>;
        String status = data['status'] ?? 'pending';
        String? vehicleType = data['vehicleType'];

        // إذا تم التوصيل: اظهر التقييم بدل الإخفاء المباشر
        if (status == 'delivered' && !_ratingShown) {
          _ratingShown = true;
          Future.microtask(() => _showRatingDialog(data['driverId'], data['driverName'] ?? "المندوب"));
          return const SizedBox.shrink();
        }

        // الحالات الأخرى التي تتطلب الإخفاء الفوري
        if (status.contains('cancelled') || status == 'rejected' || status == 'expired') {
          Future.microtask(() => _clearOrder());
          return const SizedBox.shrink();
        }

        bool isAccepted = status != 'pending';

        return Positioned(
          left: position.dx,
          top: position.dy,
          child: Material(
            type: MaterialType.transparency,
            child: Draggable(
              feedback: _buildBubbleUI(isAccepted, true, vehicleType),
              childWhenDragging: const SizedBox.shrink(),
              onDragEnd: (details) {
                setState(() {
                  position = Offset(details.offset.dx.clamp(5.w, 82.w), details.offset.dy.clamp(10.h, 85.h));
                });
              },
              child: GestureDetector(
                onTap: () => _handleBubbleTap(context),
                onLongPress: () => _showOptionsDialog(context, status),
                child: isAccepted
                    ? _buildBubbleUI(isAccepted, false, vehicleType)
                    : ScaleTransition(
                        scale: Tween(begin: 1.0, end: 1.1).animate(_pulseController),
                        child: _buildBubbleUI(isAccepted, false, vehicleType),
                      ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _handleBubbleTap(BuildContext context) {
    final navState = navigatorKey.currentState;
    if (navState == null) return;

    bool isTrackingOpen = false;
    navState.popUntil((route) {
      if (route.settings.name == '/customerTracking') isTrackingOpen = true;
      return true; 
    });

    if (isTrackingOpen) {
      navState.pushNamedAndRemoveUntil('/', (route) => false);
    } else {
      navState.push(MaterialPageRoute(
        settings: const RouteSettings(name: '/customerTracking'),
        builder: (context) => CustomerTrackingScreen(orderId: widget.orderId),
      ));
    }
  }

  void _showOptionsDialog(BuildContext context, String status) {
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text("إدارة الطلب", style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
          content: Text(status != 'pending'
            ? "⚠️ المندوب قبل الطلب. إلغاء الطلب الآن قد يخصم من نقاطك." 
            : "هل تريد إلغاء الطلب نهائياً أم إخفاء الفقاعة؟", style: const TextStyle(fontFamily: 'Cairo')),
          actions: [
            TextButton(onPressed: () { Navigator.pop(ctx); _handleSmartCancelFromBubble(status); },
              child: const Text("إلغاء نهائي", style: TextStyle(color: Colors.red, fontFamily: 'Cairo'))),
            TextButton(onPressed: () { Navigator.pop(ctx); _clearOrder(); },
              child: const Text("إخفاء فقط", style: TextStyle(fontFamily: 'Cairo'))),
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("رجوع", style: TextStyle(fontFamily: 'Cairo'))),
          ],
        ),
      ),
    );
  }

  Widget _buildBubbleUI(bool isAccepted, bool isDragging, String? vehicleType) {
    return Container(
      width: 16.w, height: 16.w,
      decoration: BoxDecoration(
        gradient: isAccepted ? null : RadialGradient(colors: [Colors.orange[800]!, Colors.orange[900]!], radius: 0.8),
        color: isAccepted ? Colors.green[700] : null,
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: (isAccepted ? Colors.green : Colors.orange).withOpacity(0.5), blurRadius: 15, spreadRadius: 2)],
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (!isAccepted) const SizedBox(width: 50, height: 50, child: CircularProgressIndicator(strokeWidth: 1.5, valueColor: AlwaysStoppedAnimation(Colors.white30))),
          Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(isAccepted ? _getVehicleIcon(vehicleType) : Icons.radar, color: Colors.white, size: 20.sp),
            if (!isAccepted) Text("جاري البحث", style: TextStyle(color: Colors.white, fontSize: 6.5.sp, fontWeight: FontWeight.bold, decoration: TextDecoration.none, fontFamily: 'Cairo')),
          ]),
        ],
      ),
    );
  }

  IconData _getVehicleIcon(String? vehicleType) {
    if (vehicleType == 'pickup') return Icons.local_shipping;
    if (vehicleType == 'jumbo') return Icons.fire_truck;
    return Icons.delivery_dining;
  }
}
