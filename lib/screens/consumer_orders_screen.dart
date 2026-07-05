import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// تم حذف latlong2 هنا نهائياً
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:sizer/sizer.dart';

import '../providers/customer_orders_provider.dart';
import '../providers/buyer_data_provider.dart';
import '../models/consumer_order_model.dart';
import '../constants/constants.dart';
import '../helpers/order_printer_helper.dart';
import 'retailer_dispatch_screen.dart';
import 'buyer/retailer_tracking_screen.dart';

// ---------------------------------------------------------------------
// ✅ خريطة موحّدة لحالات "الراديار" (specialRequests) القادمة من الباك إند
// نفس الحالات المستخدمة فعليًا في financialSettlementEngine / orderSecurityMonitor
// ---------------------------------------------------------------------
class _RadarStatuses {
  static const pending = 'pending';
  static const accepted = 'accepted';
  static const atPickup = 'at_pickup';
  static const pickedUp = 'picked_up';
  static const delivered = 'delivered';
  static const noDrivers = 'no_drivers_available';
  static const rejectedBySystem = 'rejected_by_system';
  static const cancelled = 'cancelled';
  static const cancelledBeforeAccept = 'cancelled_by_user_before_accept';
  static const cancelledAfterAccept = 'cancelled_by_user_after_accept';
  static const driverCancelledReseeking = 'driver_cancelled_reseeking';
  static const returnedSuccessfully = 'returned_successfully';

  // حالات نشطة فعليًا بيتحرك فيها المندوب أو النظام بيدور على بديل
  static const Set<String> activeTracking = {
    accepted,
    atPickup,
    pickedUp,
    driverCancelledReseeking,
  };

  // حالات نهائية - العهدة رجعت أو اتلغت أو مفيش مندوب
  static const Set<String> terminal = {
    noDrivers,
    rejectedBySystem,
    cancelled,
    cancelledBeforeAccept,
    cancelledAfterAccept,
    returnedSuccessfully,
  };
}

class ConsumerOrdersScreen extends StatelessWidget {
  const ConsumerOrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ordersProvider = Provider.of<CustomerOrdersProvider>(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F9),
      appBar: AppBar(
        title: Text('إدارة عهدة الطلبات',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18.sp, fontFamily: 'Cairo')),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF4CAF50),
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: Colors.grey[200], height: 1),
        ),
      ),
      body: SafeArea(
        child: ordersProvider.isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF4CAF50)))
            : ordersProvider.orders.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inventory_2_outlined, size: 60.sp, color: Colors.grey[300]),
                        SizedBox(height: 2.h),
                        Text(ordersProvider.message ?? 'لا توجد سجلات عهدة حالية.',
                            style: TextStyle(color: Colors.grey[600], fontSize: 14.sp, fontFamily: 'Cairo')),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
                    physics: const BouncingScrollPhysics(),
                    itemCount: ordersProvider.orders.length,
                    itemBuilder: (context, index) {
                      final order = ordersProvider.orders[index];
                      return OrderCard(order: order, provider: ordersProvider);
                    },
                  ),
      ),
    );
  }
}

class OrderCard extends StatefulWidget {
  final ConsumerOrderModel order;
  final CustomerOrdersProvider provider;

  const OrderCard({super.key, required this.order, required this.provider});

  @override
  State<OrderCard> createState() => _OrderCardState();
}

class _OrderCardState extends State<OrderCard> {
  bool _isExpanded = false;
  late String _selectedStatus;

  @override
  void initState() {
    super.initState();
    _selectedStatus = widget.order.status;
  }

  @override
  void didUpdateWidget(covariant OrderCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.order.status != oldWidget.order.status) {
      _selectedStatus = widget.order.status;
    }
  }

  void _openDispatchScreen(BuyerDataProvider buyerProvider) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RetailerDispatchScreen(
          order: widget.order,
          storeLocation: LatLng(
            buyerProvider.userLat ?? 31.2001,
            buyerProvider.userLng ?? 29.9187,
          ),
        ),
      ),
    );
  }

  // ✅ تمييز بصري كامل بين كل حالة - بدل ما PROCESSING/SHIPPED/DELIVERED/CANCELLED
  // كانوا كلهم بنفس اللون الأخضر
  Color _statusColor(String status, bool returnRequested) {
    if (returnRequested) return const Color(0xFFE53935);
    switch (status) {
      case OrderStatuses.NEW_ORDER:
        return const Color(0xFFFFA000);
      case OrderStatuses.PROCESSING:
        return const Color(0xFF1E88E5);
      case OrderStatuses.SHIPPED:
        return const Color(0xFF5E35B1);
      case OrderStatuses.DELIVERED:
        return const Color(0xFF2E7D32);
      case OrderStatuses.CANCELLED:
        return const Color(0xFF757575);
      default:
        return const Color(0xFF4CAF50);
    }
  }

  IconData _statusIcon(String status, bool returnRequested) {
    if (returnRequested) return Icons.assignment_return_rounded;
    switch (status) {
      case OrderStatuses.NEW_ORDER:
        return Icons.fiber_new_rounded;
      case OrderStatuses.PROCESSING:
        return Icons.inventory_rounded;
      case OrderStatuses.SHIPPED:
        return Icons.local_shipping_rounded;
      case OrderStatuses.DELIVERED:
        return Icons.check_circle_rounded;
      case OrderStatuses.CANCELLED:
        return Icons.cancel_rounded;
      default:
        return Icons.receipt_long_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final buyerProvider = Provider.of<BuyerDataProvider>(context);
    final bool returnRequested = order.returnRequested == true;

    final Color statusColor = _statusColor(order.status, returnRequested);

    final bool isLockedByRadar = order.status == OrderStatuses.SHIPPED &&
        (order.specialRequestId != null && order.specialRequestId!.isNotEmpty);

    final bool isDisabled = order.status == OrderStatuses.DELIVERED ||
        order.status == OrderStatuses.CANCELLED ||
        isLockedByRadar;

    return Container(
      margin: EdgeInsets.only(bottom: 2.2.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 16, offset: const Offset(0, 6)),
        ],
        border: Border.all(color: statusColor.withOpacity(0.35), width: 1.4),
      ),
      child: ExpansionTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        onExpansionChanged: (val) => setState(() => _isExpanded = val),
        tilePadding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
        trailing: Icon(_isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: statusColor, size: 25.sp),
        title: Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(color: statusColor.withOpacity(0.12), borderRadius: BorderRadius.circular(14)),
                child: Icon(_statusIcon(order.status, returnRequested), color: statusColor, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text('#${order.orderId}',
                              style: TextStyle(fontSize: 13.5.sp, fontWeight: FontWeight.w900, color: Colors.black87, fontFamily: 'Cairo')),
                        ),
                        _StatusBadge(
                          label: returnRequested ? 'مرتجع' : getStatusDisplayName(order.status),
                          color: statusColor,
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(order.customerName,
                        style: TextStyle(fontSize: 12.5.sp, color: Colors.grey[700], fontWeight: FontWeight.w600, fontFamily: 'Cairo')),
                    const SizedBox(height: 4),
                    Text('${order.finalAmount.toStringAsFixed(2)} ج.م',
                        style: TextStyle(color: statusColor, fontWeight: FontWeight.w900, fontSize: 13.sp, fontFamily: 'Cairo')),
                  ],
                ),
              ),
            ],
          ),
        ),
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 1.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (returnRequested) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(12)),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: Colors.red),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text("تنبيه: العميل رفض الاستلام، العهدة في طريق العودة.",
                              style: TextStyle(color: Colors.red[900], fontWeight: FontWeight.bold, fontSize: 11.sp, fontFamily: 'Cairo')),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 2.h),
                ],
                const Divider(),
                _buildInfoRow(Icons.phone, 'تواصل الوجهة', order.customerPhone),
                _buildInfoRow(Icons.location_on, 'موقع التسليم', order.customerAddress),
                _buildInfoRow(Icons.calendar_today, 'توقيت الإنشاء', order.orderDate?.toString().split('.')[0] ?? 'غير متوفر'),

                Padding(
                  padding: EdgeInsets.symmetric(vertical: 2.h),
                  child: Text('تفاصيل محتويات العهدة:',
                      style: TextStyle(fontWeight: FontWeight.w900, color: const Color(0xFF4CAF50), fontSize: 13.sp, fontFamily: 'Cairo')),
                ),
                _buildItemsList(order),

                const Divider(height: 40),
                Text(isLockedByRadar ? 'الحالة (بعهدة المندوب):' : 'إدارة حالة العهدة:',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13.sp, fontFamily: 'Cairo')),
                SizedBox(height: 1.5.h),

                DropdownButtonFormField<String>(
                  value: _selectedStatus,
                  items: [
                    OrderStatuses.NEW_ORDER,
                    OrderStatuses.PROCESSING,
                    OrderStatuses.SHIPPED,
                    OrderStatuses.DELIVERED,
                    OrderStatuses.CANCELLED,
                  ].map((status) {
                    return DropdownMenuItem(
                        value: status,
                        child: Text(getStatusDisplayName(status), style: TextStyle(fontFamily: 'Cairo', fontSize: 12.sp, fontWeight: FontWeight.bold)));
                  }).toList(),
                  onChanged: isDisabled ? null : (newValue) => setState(() => _selectedStatus = newValue!),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: isDisabled ? Colors.grey[100] : Colors.grey[50],
                    contentPadding: EdgeInsets.symmetric(horizontal: 15, vertical: 1.5.h),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                  ),
                ),
                SizedBox(height: 2.h),

                // ✅ تمييز بصري بين الإجراء الأساسي (تثبيت) والثانوي (طباعة)
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: isDisabled ? null : () => widget.provider.updateOrderStatus(order.id, _selectedStatus),
                        icon: const Icon(Icons.save_as_outlined, size: 18),
                        label: Text('تثبيت الحالة', style: TextStyle(fontFamily: 'Cairo', fontSize: 12.sp, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4CAF50),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: EdgeInsets.symmetric(vertical: 1.8.h),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    SizedBox(width: 3.w),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async => await OrderPrinterHelper.printOrderReceipt(order),
                        icon: const Icon(Icons.print, size: 18),
                        label: Text('طباعة السند', style: TextStyle(fontFamily: 'Cairo', fontSize: 12.sp, fontWeight: FontWeight.bold)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF2c3e50),
                          side: const BorderSide(color: Color(0xFF2c3e50), width: 1.4),
                          padding: EdgeInsets.symmetric(vertical: 1.8.h),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 2.h),

                StreamBuilder<DocumentSnapshot>(
                  stream: (order.specialRequestId != null && order.specialRequestId!.isNotEmpty)
                      ? FirebaseFirestore.instance.collection('specialRequests').doc(order.specialRequestId).snapshots()
                      : const Stream.empty(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData || !snapshot.data!.exists) {
                      return _buildActionButton(
                        onPressed: isDisabled ? null : () => _openDispatchScreen(buyerProvider),
                        label: 'طلب مندوب استلام عهدة',
                        icon: Icons.delivery_dining,
                        color: Colors.orange[800]!,
                      );
                    }
                    var radarData = snapshot.data!.data() as Map<String, dynamic>;
                    String radarStatus = radarData['status'] ?? _RadarStatuses.pending;

                    // 1) لسه بيدور على مندوب أول مرة
                    if (radarStatus == _RadarStatuses.pending) {
                      return _buildActionButton(
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => RetailerTrackingScreen(orderId: order.specialRequestId!))),
                        label: 'جاري البحث عن مندوب...',
                        icon: Icons.hourglass_empty,
                        color: Colors.grey[700]!,
                        isProcessing: true,
                      );
                    }

                    // 2) حالات نشطة: المندوب في طريقه، أو النظام بيدور على بديل بعد إلغاء
                    // ✅ إصلاح: driver_cancelled_reseeking بقت هنا بدل ما توقع في حالة
                    // "طلب مندوب جديد" وتعمل طلب مكرر لنفس العهدة
                    if (_RadarStatuses.activeTracking.contains(radarStatus)) {
                      final bool isReseeking = radarStatus == _RadarStatuses.driverCancelledReseeking;
                      return _buildActionButton(
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => RetailerTrackingScreen(orderId: order.specialRequestId!))),
                        label: isReseeking
                            ? 'المندوب ألغى - جاري البحث عن بديل'
                            : (returnRequested ? 'تتبع عودة العهدة (مرتجع)' : 'تتبع مسار نقل العهدة'),
                        icon: isReseeking ? Icons.sync_problem_rounded : Icons.location_on_outlined,
                        color: isReseeking
                            ? Colors.deepOrange
                            : (returnRequested ? Colors.red[800]! : Colors.blue[800]!),
                        isProcessing: isReseeking,
                      );
                    }

                    // 3) حالات نهائية (اتلغى / رفض النظام / مفيش مناديب / رجع بنجاح)
                    // ✅ إصلاح: returned_successfully بقت متعرّفة، وبقى فيه نص توضيحي
                    // فوق زرار "طلب مندوب جديد" يوضح السبب بدل ما يظهر الزرار من غير سياق
                    if (_RadarStatuses.terminal.contains(radarStatus)) {
                      String note;
                      if (radarStatus == _RadarStatuses.returnedSuccessfully) {
                        note = "✅ تم إرجاع العهدة بنجاح للمتجر";
                      } else if (radarStatus == _RadarStatuses.noDrivers) {
                        note = "⚠️ لم يتم إيجاد مندوب متاح في المحاولة السابقة";
                      } else if (radarStatus == _RadarStatuses.rejectedBySystem) {
                        note = "⚠️ تم رفض الطلب السابق تلقائيًا، برجاء مراجعة تفاصيل الشحنة";
                      } else {
                        note = "ℹ️ الطلب السابق للمندوب تم إلغاؤه";
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(note, style: TextStyle(fontSize: 11.sp, color: Colors.grey[700], fontFamily: 'Cairo', fontWeight: FontWeight.w600)),
                          ),
                          _buildActionButton(
                            onPressed: isDisabled ? null : () => _openDispatchScreen(buyerProvider),
                            label: 'طلب مندوب استلام عهدة',
                            icon: Icons.delivery_dining,
                            color: Colors.orange[800]!,
                          ),
                        ],
                      );
                    }

                    // 4) fallback لأي حالة غير متوقعة (لتفادي انهيار الواجهة لو ظهرت حالة جديدة من الباك إند)
                    return _buildActionButton(
                      onPressed: isDisabled ? null : () => _openDispatchScreen(buyerProvider),
                      label: 'طلب مندوب استلام عهدة',
                      icon: Icons.delivery_dining,
                      color: Colors.orange[800]!,
                    );
                  },
                ),
                SizedBox(height: 2.h),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildActionButton({required VoidCallback? onPressed, required String label, required IconData icon, required Color color, bool isProcessing = false}) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: isProcessing
            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white))
            : Icon(icon, size: 24.sp),
        label: Text(label, style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w900, fontFamily: 'Cairo')),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(vertical: 2.h),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          elevation: 3,
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 0.8.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18.sp, color: Colors.grey[600]),
          SizedBox(width: 4.w),
          Text('$label: ', style: TextStyle(fontSize: 12.sp, color: Colors.grey[600], fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
          Expanded(child: Text(value, style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w600, fontFamily: 'Cairo', color: Colors.black87))),
        ],
      ),
    );
  }

  Widget _buildItemsList(ConsumerOrderModel order) {
    if (order.items.isEmpty) return Text('لا توجد عناصر.', style: TextStyle(fontSize: 12.sp));
    return Column(
      children: order.items.map((item) {
        return Container(
          margin: EdgeInsets.only(bottom: 1.5.h),
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.grey[200]!)),
          child: Row(
            children: [
              if (item.imageUrl != null && item.imageUrl!.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(item.imageUrl!, width: 55, height: 55, fit: BoxFit.cover),
                )
              else
                Container(
                  width: 55,
                  height: 55,
                  decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(10)),
                  child: Icon(Icons.inventory_2_outlined, color: Colors.grey[400]),
                ),
              SizedBox(width: 5.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.name ?? 'عنصر غير محدد', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.sp, fontFamily: 'Cairo')),
                    SizedBox(height: 0.5.h),
                    Text('الكمية المطلوبة: ${item.quantity ?? 1}', style: TextStyle(color: Colors.grey[700], fontSize: 11.sp, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

/// شارة صغيرة توضح حالة الطلب بشكل بصري واضح داخل رأس الكارت
class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
      child: Text(
        label,
        style: TextStyle(fontSize: 10.5.sp, fontWeight: FontWeight.w900, color: color, fontFamily: 'Cairo'),
      ),
    );
  }
}

String getStatusDisplayName(String status) {
  switch (status) {
    case OrderStatuses.NEW_ORDER: return 'طلب جديد';
    case OrderStatuses.PROCESSING: return 'قيد التجهيز';
    case OrderStatuses.SHIPPED: return 'تم الشحن/عهدة';
    case OrderStatuses.DELIVERED: return 'تم التسليم';
    case OrderStatuses.CANCELLED: return 'ملغي/مرتجع';
    default: return status;
  }
}