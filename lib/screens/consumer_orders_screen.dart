import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';
import 'package:sizer/sizer.dart';

import '../providers/customer_orders_provider.dart';
import '../providers/buyer_data_provider.dart';
import '../models/consumer_order_model.dart';
import '../constants/constants.dart';
import '../helpers/order_printer_helper.dart';
import 'retailer_dispatch_screen.dart';
import 'buyer/retailer_tracking_screen.dart';

class ConsumerOrdersScreen extends StatelessWidget {
  const ConsumerOrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ordersProvider = Provider.of<CustomerOrdersProvider>(context);
    
    return Scaffold(
      backgroundColor: Colors.white,
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
                    padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 2.h),
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

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final buyerProvider = Provider.of<BuyerDataProvider>(context);
    
    Color borderColor = order.status == OrderStatuses.NEW_ORDER
        ? const Color(0xFFFFC107)
        : const Color(0xFF4CAF50);
    
    if (order.returnRequested == true) {
      borderColor = Colors.redAccent;
    }

    final bool isLockedByRadar = order.status == OrderStatuses.SHIPPED && 
                                (order.specialRequestId != null && order.specialRequestId!.isNotEmpty);

    final bool isDisabled = order.status == OrderStatuses.DELIVERED || 
                           order.status == OrderStatuses.CANCELLED ||
                           isLockedByRadar;

    return Container(
      margin: EdgeInsets.only(bottom: 2.5.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: borderColor.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 8),
          )
        ],
        border: Border.all(color: borderColor.withOpacity(0.6), width: 2.5),
      ),
      child: ExpansionTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        onExpansionChanged: (val) => setState(() => _isExpanded = val),
        trailing: Icon(_isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: borderColor, size: 25.sp),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('سجل عهدة: #${order.orderId}', 
                style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w900, color: Colors.black87, fontFamily: 'Cairo')),
            SizedBox(height: 0.5.h),
            Text(order.customerName, 
                style: TextStyle(fontSize: 13.sp, color: Colors.grey[800], fontWeight: FontWeight.w600, fontFamily: 'Cairo')),
          ],
        ),
        subtitle: Padding(
          padding: EdgeInsets.only(top: 1.h),
          child: Text('قيمة العهدة: ${order.finalAmount.toStringAsFixed(2)} ج.م', 
              style: TextStyle(color: borderColor, fontWeight: FontWeight.w800, fontSize: 13.sp)),
        ),
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (order.returnRequested == true) ...[
                   Container(
                     width: double.infinity,
                     padding: const EdgeInsets.all(12),
                     decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(10)),
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
                // ✅ تم إصلاح مشكلة toLocaleString ببديل أصلي متوافق مع الـ Build
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
                  // ✅ تم إصلاح مشكلة OrderStatusesHelpers
                  items: [
                    OrderStatuses.NEW_ORDER,
                    OrderStatuses.PROCESSING,
                    OrderStatuses.SHIPPED,
                    OrderStatuses.DELIVERED,
                    OrderStatuses.CANCELLED,
                  ].map((status) {
                    return DropdownMenuItem(
                      value: status, 
                      child: Text(getStatusDisplayName(status), style: TextStyle(fontFamily: 'Cairo', fontSize: 12.sp, fontWeight: FontWeight.bold))
                    );
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
                
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: isDisabled ? null : () => widget.provider.updateOrderStatus(order.id, _selectedStatus),
                        icon: const Icon(Icons.save_as_outlined),
                        label: Text('تثبيت الحالة', style: TextStyle(fontFamily: 'Cairo', fontSize: 12.sp, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4CAF50),
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 1.8.h),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    SizedBox(width: 3.w),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async => await OrderPrinterHelper.printOrderReceipt(order),
                        icon: const Icon(Icons.print),
                        label: Text('طباعة السند', style: TextStyle(fontFamily: 'Cairo', fontSize: 12.sp, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2c3e50),
                          foregroundColor: Colors.white,
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
                    String radarStatus = radarData['status'] ?? 'pending';

                    if (radarStatus == 'pending') {
                      return _buildActionButton(
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => RetailerTrackingScreen(orderId: order.specialRequestId!))),
                        label: 'جاري البحث عن مندوب...',
                        icon: Icons.hourglass_empty,
                        color: Colors.grey[700]!,
                        isProcessing: true,
                      );
                    }

                    if (['accepted', 'at_pickup', 'picked_up', 'returning_to_seller'].contains(radarStatus)) {
                      return _buildActionButton(
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => RetailerTrackingScreen(orderId: order.specialRequestId!))),
                        label: (order.returnRequested == true) ? 'تتبع عودة العهدة (مرتجع)' : 'تتبع مسار نقل العهدة',
                        icon: Icons.location_on_outlined,
                        color: (order.returnRequested == true) ? Colors.red[800]! : Colors.blue[800]!,
                      );
                    }

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
          ? SizedBox(width: 22, height: 22, child: const CircularProgressIndicator(strokeWidth: 3, color: Colors.white))
          : Icon(icon, size: 24.sp),
        label: Text(label, style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w900, fontFamily: 'Cairo')),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(vertical: 2.h),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          elevation: 5,
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

// ✅ إضافة الدوال المساعدة خارج الكلاس لضمان عمل الـ Build
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
