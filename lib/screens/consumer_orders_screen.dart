// lib/screens/consumer_orders_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../providers/customer_orders_provider.dart';
import '../models/consumer_order_model.dart';
import '../constants/constants.dart';
import '../helpers/order_printer_helper.dart';

// --- شاشة مؤقتة لاستقبال البيانات (ستقوم ببرمجتها لاحقاً) ---
class DispatchMapScreen extends StatelessWidget {
  final ConsumerOrderModel order;
  final dynamic storeLocation; // مكان السوبر ماركت
  final dynamic customerLocation; // مكان العميل

  const DispatchMapScreen({
    super.key,
    required this.order,
    required this.storeLocation,
    required this.customerLocation,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('خريطة التوصيل الحر')),
      body: Center(
        child: Text('جاري إرسال طلب رقم: ${order.orderId}\nمن المتجر إلى العميل'),
      ),
    );
  }
}

class ConsumerOrdersScreen extends StatelessWidget {
  const ConsumerOrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ordersProvider = Provider.of<CustomerOrdersProvider>(context);
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('طلبات العملاء', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF4CAF50),
        elevation: 1,
      ),
      body: SafeArea(
        child: ordersProvider.isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF4CAF50)))
            : ordersProvider.orders.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inventory_2_outlined, size: 60, color: Colors.grey[400]),
                        const SizedBox(height: 10),
                        Text(ordersProvider.message ?? 'لا توجد طلبات لعرضها حاليًا.',
                            style: TextStyle(color: Colors.grey[600])),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(15),
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

  // دالة إظهار نافذة التأكيد قبل طلب المندوب
  void _confirmFreelanceDispatch(BuildContext context, ConsumerOrderModel order) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange),
            SizedBox(width: 10),
            Text('تأكيد طلب مندوب'),
          ],
        ),
        content: Text('هل تود إرسال الطلب رقم ${order.orderId} للمناديب الأحرار؟\n\nسيتم تحديد موقعك الحالي كمقطة استلام وموقع العميل كوجهة نهائية.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              // الانتقال للصفحة وتمرير الإحداثيات
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => DispatchMapScreen(
                    order: order,
                    storeLocation: "LOCATION_DATA_HERE", // سيتم استبدالها لاحقاً بإحداثيات المتجر
                    customerLocation: "CUSTOMER_DATA_HERE", // سيتم استبدالها لاحقاً بإحداثيات العميل
                  ),
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4CAF50)),
            child: const Text('تأكيد الإرسال'),
          ),
        ],
      ),
    );
  }

  Widget _buildItemsList(ConsumerOrderModel order) {
    if (order.items.isEmpty) {
      return const Text('لا توجد منتجات في هذا الطلب.');
    }
    return Column(
      children: order.items.map((item) {
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              if (item.imageUrl != null && item.imageUrl!.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    item.imageUrl!,
                    width: 50,
                    height: 50,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => const Icon(Icons.image_not_supported),
                  ),
                ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.name ?? 'منتج غير معروف', style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text('الكمية: ${item.quantity ?? 1}', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final borderColor = order.status == OrderStatuses.NEW_ORDER
        ? const Color(0xFFFFC107)
        : const Color(0xFF4CAF50);
    final bool isDisabled = order.status == OrderStatuses.DELIVERED || order.status == OrderStatuses.CANCELLED;

    return Card(
      margin: const EdgeInsets.only(bottom: 15),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: BorderSide(color: borderColor, width: 2),
      ),
      elevation: 3,
      child: ExpansionTile(
        onExpansionChanged: (val) => setState(() => _isExpanded = val),
        trailing: Icon(_isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: borderColor),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('طلب رقم: ${order.orderId}', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: borderColor)),
            const SizedBox(height: 4),
            Text(order.customerName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          ],
        ),
        subtitle: Text('${order.finalAmount.toStringAsFixed(2)} EGP', style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(),
                _buildInfoRow(Icons.phone, 'رقم الهاتف', order.customerPhone),
                _buildInfoRow(Icons.location_on, 'العنوان', order.customerAddress),
                _buildInfoRow(Icons.calendar_today, 'التاريخ', order.orderDate?.toLocaleString() ?? 'غير متوفر'),
                _buildInfoRow(Icons.delivery_dining, 'رسوم التوصيل', '${order.deliveryFee.toStringAsFixed(2)} EGP'),
                _buildInfoRow(Icons.stars, 'نقاط مستخدمة', '${order.pointsUsed} نقطة'),
                
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: Text('المنتجات المطلوبة:', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF4CAF50))),
                ),
                _buildItemsList(order),
                
                const Divider(height: 30),
                const Text('إدارة الطلب:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: _selectedStatus,
                  items: OrderStatusesHelpers.allStatuses.map((status) {
                    return DropdownMenuItem(value: status, child: Text(getStatusDisplayName(status)));
                  }).toList(),
                  onChanged: isDisabled ? null : (newValue) => setState(() => _selectedStatus = newValue!),
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    enabled: !isDisabled,
                  ),
                ),
                const SizedBox(height: 15),
                
                // --- الصف الأول من الأزرار (حفظ وطباعة) ---
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: isDisabled ? null : () => widget.provider.updateOrderStatus(order.id, _selectedStatus),
                        icon: const Icon(Icons.check_circle_outline, size: 18),
                        label: const Text('حفظ الحالة'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4CAF50),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async => await OrderPrinterHelper.printOrderReceipt(order),
                        icon: const Icon(Icons.print, size: 18),
                        label: const Text('طباعة'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2c3e50),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 10),

                // --- الصف الثاني (زر طلب المندوب الحر) ---
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: isDisabled ? null : () => _confirmFreelanceDispatch(context, order),
                    icon: const Icon(Icons.delivery_dining_outlined, size: 20),
                    label: const Text('إرسال للمندوب الحر (الرادار)', style: TextStyle(fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange[800],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      elevation: 2,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey),
          const SizedBox(width: 8),
          Text('$label: ', style: const TextStyle(fontSize: 13, color: Colors.grey)),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
        ],
      ),
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
