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
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text('إدارة عهدة الطلبات', 
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16.sp, fontFamily: 'Cairo')),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF4CAF50),
        elevation: 0.5,
      ),
      body: SafeArea(
        child: ordersProvider.isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF4CAF50)))
            : ordersProvider.orders.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inventory_2_outlined, size: 50.sp, color: Colors.grey[300]),
                        const SizedBox(height: 15),
                        Text(ordersProvider.message ?? 'لا توجد سجلات عهدة حالية.',
                            style: TextStyle(color: Colors.grey[600], fontFamily: 'Cairo')),
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

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final buyerProvider = Provider.of<BuyerDataProvider>(context);
    
    final borderColor = order.status == OrderStatuses.NEW_ORDER
        ? const Color(0xFFFFC107)
        : const Color(0xFF4CAF50);

    // 🛡️ القفل الذكي: يُغلق الزرار في الحالات النهائية أو إذا كان الشحن بواسطة مندوب الرادار
    final bool isLockedByRadar = order.status == OrderStatuses.SHIPPED && 
                                (order.specialRequestId != null && order.specialRequestId!.isNotEmpty);

    final bool isDisabled = order.status == OrderStatuses.DELIVERED || 
                           order.status == OrderStatuses.CANCELLED ||
                           isLockedByRadar;

    return Container(
      margin: EdgeInsets.only(bottom: 2.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
        border: Border.all(color: borderColor.withOpacity(0.4), width: 1.5),
      ),
      child: ExpansionTile(
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(15))),
        collapsedShape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(15))),
        onExpansionChanged: (val) => setState(() => _isExpanded = val),
        trailing: Icon(_isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: borderColor),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('سجل عهدة رقم: ${order.orderId}', 
                style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.bold, color: Colors.black87, fontFamily: 'Cairo')),
            Text(order.customerName, style: TextStyle(fontSize: 11.sp, color: Colors.grey[700], fontFamily: 'Cairo')),
          ],
        ),
        subtitle: Text('قيمة العهدة: ${order.finalAmount.toStringAsFixed(2)} ج.م', 
            style: TextStyle(color: Colors.green[700], fontWeight: FontWeight.bold, fontSize: 10.sp)),
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 1.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(),
                _buildInfoRow(Icons.phone, 'تواصل الوجهة', order.customerPhone),
                _buildInfoRow(Icons.location_on, 'موقع التسليم', order.customerAddress),
                _buildInfoRow(Icons.calendar_today, 'توقيت الإنشاء', order.orderDate?.toLocaleString() ?? 'غير متوفر'),
                
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: Text('تفاصيل محتويات العهدة:', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF4CAF50), fontFamily: 'Cairo')),
                ),
                _buildItemsList(order),
                
                const Divider(height: 30),
                Text(isLockedByRadar ? 'الحالة (مُدارة بواسطة المندوب):' : 'إدارة حالة العهدة:', 
                    style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
                const SizedBox(height: 10),
                
                DropdownButtonFormField<String>(
                  value: _selectedStatus,
                  items: OrderStatusesHelpers.allStatuses.map((status) {
                    return DropdownMenuItem(value: status, child: Text(getStatusDisplayName(status), style: const TextStyle(fontFamily: 'Cairo')));
                  }).toList(),
                  onChanged: isDisabled ? null : (newValue) => setState(() => _selectedStatus = newValue!),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: isDisabled ? Colors.grey[100] : Colors.grey[50],
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 15),
                
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: isDisabled ? null : () => widget.provider.updateOrderStatus(order.id, _selectedStatus),
                        icon: const Icon(Icons.save_as_outlined, size: 18),
                        label: const Text('تثبيت الحالة', style: TextStyle(fontFamily: 'Cairo')),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4CAF50),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async => await OrderPrinterHelper.printOrderReceipt(order),
                        icon: const Icon(Icons.print, size: 18),
                        label: const Text('طباعة السند', style: TextStyle(fontFamily: 'Cairo')),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2c3e50),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 15),
                
                // 🔄 المستمع لطلب الرادار (اللوجيستيات)
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
                        color: Colors.grey[600]!,
                        isProcessing: true,
                      );
                    }

                    if (['accepted', 'at_pickup', 'picked_up'].contains(radarStatus)) {
                      return _buildActionButton(
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => RetailerTrackingScreen(orderId: order.specialRequestId!))),
                        label: 'تتبع مسار نقل العهدة',
                        icon: Icons.location_on_outlined,
                        color: Colors.blue[800]!,
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
                const SizedBox(height: 10),
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
          ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white.withOpacity(0.7)))
          : Icon(icon, size: 22),
        label: Text(label, style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(vertical: 1.8.h),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 10),
          Text('$label: ', style: TextStyle(fontSize: 10.sp, color: Colors.grey[600], fontFamily: 'Cairo')),
          Expanded(child: Text(value, style: TextStyle(fontSize: 10.sp, fontWeight: FontWeight.w500, fontFamily: 'Cairo'))),
        ],
      ),
    );
  }

  Widget _buildItemsList(ConsumerOrderModel order) {
    if (order.items.isEmpty) return const Text('لا توجد عناصر مسجلة.');
    return Column(
      children: order.items.map((item) {
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(10)),
          child: Row(
            children: [
              if (item.imageUrl != null && item.imageUrl!.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(item.imageUrl!, width: 45, height: 45, fit: BoxFit.cover),
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.name ?? 'عنصر غير محدد', style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
                    Text('الكمية: ${item.quantity ?? 1}', style: TextStyle(color: Colors.grey[600], fontSize: 11)),
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

extension OrderStatusesHelpers on OrderStatuses {
  static List<String> get allStatuses => [
    OrderStatuses.NEW_ORDER,
    OrderStatuses.PROCESSING,
    OrderStatuses.SHIPPED,
    OrderStatuses.DELIVERED,
    OrderStatuses.CANCELLED,
  ];
}

extension DateParsing on DateTime {
  String toLocaleString() {
    return this.toString().split('.')[0];
  }
}
