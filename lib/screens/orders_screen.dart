import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:my_test_app/data_sources/order_data_source.dart';
import 'package:my_test_app/models/order_model.dart';
import 'package:my_test_app/services/excel_exporter.dart';
import 'package:my_test_app/screens/invoice_screen.dart';
import 'package:sizer/sizer.dart';

class OrdersScreen extends StatefulWidget {
  final String sellerId;
  const OrdersScreen({super.key, required this.sellerId});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  late Future<List<OrderModel>> _ordersFuture;
  final OrderDataSource _dataSource = OrderDataSource();
  List<OrderModel> _loadedOrders = [];
  String _selectedFilter = 'all';

  @override
  void initState() {
    super.initState();
    _refreshOrders();
  }

  void _refreshOrders() {
    setState(() {
      _ordersFuture = _dataSource.loadOrders(widget.sellerId, 'seller');
    });
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'new-order': return Colors.blue.shade600;
      case 'processing': return Colors.orange.shade600;
      case 'shipped': return Colors.deepPurple.shade400;
      case 'delivered': return Colors.green.shade600;
      case 'cancelled': return Colors.red.shade400;
      default: return Colors.grey.shade600;
    }
  }

  // ✅ تم التصحيح هنا: تغيير الفتحة الكبيرة للصغيرة في fiber_new_outlined
  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'new-order': return Icons.fiber_new_outlined; 
      case 'processing': return Icons.inventory_2_outlined;
      case 'shipped': return Icons.local_shipping_outlined;
      case 'delivered': return Icons.check_circle_outline;
      case 'cancelled': return Icons.cancel_outlined;
      default: return Icons.receipt_long;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        title: Text('إدارة الطلبات الواردة',
            style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: const Color(0xFF1B5E20),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.file_download_outlined, color: Colors.white, size: 22.sp),
            onPressed: _exportToExcel,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilterBar(),
          Expanded(
            child: FutureBuilder<List<OrderModel>>(
              future: _ordersFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) return _buildErrorState(snapshot.error.toString());

                _loadedOrders = snapshot.data ?? [];
                final filteredList = _selectedFilter == 'all'
                    ? _loadedOrders
                    : _loadedOrders.where((o) => o.status == _selectedFilter).toList();

                if (filteredList.isEmpty) return _buildEmptyState();

                return RefreshIndicator(
                  onRefresh: () async => _refreshOrders(),
                  child: ListView.builder(
                    padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
                    itemCount: filteredList.length,
                    itemBuilder: (context, index) => _buildOrderCard(filteredList[index]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      height: 8.h,
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 2.w),
        children: [
          _buildFilterChip('الكل', 'all'),
          _buildFilterChip('جديد', 'new-order'),
          _buildFilterChip('تجهيز', 'processing'),
          _buildFilterChip('شحن', 'shipped'),
          _buildFilterChip('تسليم', 'delivered'),
          _buildFilterChip('ملغى', 'cancelled'),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    bool isSelected = _selectedFilter == value;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 1.w),
      child: ChoiceChip(
        label: Text(label, style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.bold, color: isSelected ? Colors.white : Colors.black87)),
        selected: isSelected,
        selectedColor: const Color(0xFF2E7D32),
        onSelected: (val) => setState(() => _selectedFilter = value),
      ),
    );
  }

  Widget _buildOrderCard(OrderModel order) {
    final statusColor = _getStatusColor(order.status);

    return Container(
      margin: EdgeInsets.only(bottom: 2.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border(right: BorderSide(color: statusColor, width: 6)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 4))],
      ),
      child: ExpansionTile(
        shape: const RoundedRectangleBorder(side: BorderSide.none),
        leading: Icon(_getStatusIcon(order.status), color: statusColor, size: 24.sp),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(order.buyerDetails.name, style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold)),
            Text("#${order.id.substring(0, 5).toUpperCase()}", style: TextStyle(fontSize: 10.sp, color: Colors.grey)),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 0.5.h),
            Text("المطلوب: ${order.totalAmount} ج.م",
                style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 13.sp)),
            Text(DateFormat('MMM dd, hh:mm a').format(order.orderDate), style: TextStyle(fontSize: 9.sp, color: Colors.grey.shade600)),
          ],
        ),
        children: [
          Container(
            padding: EdgeInsets.all(4.w),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(15)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(child: _buildInfoItem(Icons.phone, order.buyerDetails.phone, Colors.blue)),
                    IconButton(onPressed: () {}, icon: const Icon(Icons.call, color: Colors.green)),
                  ],
                ),
                _buildInfoItem(Icons.location_on, order.buyerDetails.address, Colors.redAccent),
                SizedBox(height: 2.h),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: () => _showOrderDetails(order),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.green.shade800,
                          side: BorderSide(color: Colors.green.shade800),
                          elevation: 0,
                          padding: EdgeInsets.symmetric(vertical: 1.5.h),
                        ),
                        icon: const Icon(Icons.inventory_2_outlined),
                        label: Text("📦 الأصناف", style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    if (order.status != 'delivered' && order.status != 'cancelled') ...[
                      SizedBox(width: 3.w),
                      Expanded(flex: 3, child: _buildStatusDropdown(order)),
                    ]
                  ],
                )
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String text, Color col) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 0.5.h),
      child: Row(children: [
        Icon(icon, size: 14.sp, color: col),
        SizedBox(width: 2.w),
        Expanded(child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w500))),
      ]),
    );
  }

  Widget _buildStatusDropdown(OrderModel order) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 2.w),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade300, width: 1.5)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: order.status,
          isExpanded: true,
          style: TextStyle(fontSize: 11.sp, color: Colors.black87, fontWeight: FontWeight.bold),
          items: const [
            DropdownMenuItem(value: 'new-order', child: Text('طلب جديد')),
            DropdownMenuItem(value: 'processing', child: Text('قيد التجهيز')),
            DropdownMenuItem(value: 'shipped', child: Text('تم الشحن')),
            DropdownMenuItem(value: 'delivered', child: Text('تم التسليم ✅')),
            DropdownMenuItem(value: 'cancelled', child: Text('ملغى ❌')),
          ],
          onChanged: (val) => _handleStatusChange(order, val),
        ),
      ),
    );
  }

  void _handleStatusChange(OrderModel order, String? newVal) async {
    if (newVal == null || newVal == order.status) return;

    bool confirm = true;
    if (newVal == 'delivered' || newVal == 'cancelled') {
      confirm = await showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Text("تأكيد الحالة", style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.bold)),
              content: Text(
                newVal == 'delivered'
                    ? "هل تم تسليم الطلب وتحصيل المبلغ فعلاً؟"
                    : "هل تريد إلغاء الطلب؟ سيتم استرداد الكاش باك للعميل.",
                style: TextStyle(fontSize: 12.sp),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("تراجع")),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: newVal == 'delivered' ? Colors.green : Colors.red),
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text("تأكيد", style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ) ?? false;
    }

    if (confirm) {
      await _dataSource.updateOrderStatus(order.id, newVal);
      _refreshOrders();
    }
  }

  void _showOrderDetails(OrderModel order) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => Container(
        height: 70.h,
        padding: EdgeInsets.all(5.w),
        child: Column(
          children: [
            Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10))),
            SizedBox(height: 2.h),
            Text("أصناف الطلب #${order.id.substring(0, 5)}", style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold)),
            const Divider(),
            Expanded(
              child: ListView.builder(
                itemCount: order.items.length,
                itemBuilder: (context, i) => ListTile(
                  leading: CircleAvatar(backgroundColor: Colors.green.shade50, child: Text("${i + 1}", style: TextStyle(color: Colors.green.shade800))),
                  title: Text(order.items[i].name, style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.bold)),
                  subtitle: Text("الكمية: ${order.items[i].quantity}", style: TextStyle(fontSize: 11.sp)),
                  trailing: Text("${(order.items[i].unitPrice * order.items[i].quantity).toStringAsFixed(2)} ج.م",
                      style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.bold, color: Colors.green.shade700)),
                ),
              ),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                  minimumSize: Size(double.infinity, 7.h),
                  backgroundColor: const Color(0xFF1B5E20),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => InvoiceScreen(order: order))),
              icon: const Icon(Icons.print, color: Colors.white),
              label: Text("معاينة الفاتورة والطباعة", style: TextStyle(fontSize: 13.sp, color: Colors.white, fontWeight: FontWeight.bold)),
            )
          ],
        ),
      ),
    );
  }

  void _exportToExcel() async {
    try {
      await ExcelExporter.exportOrders(_loadedOrders, 'seller');
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("تم تصدير ملف الإكسيل بنجاح ✅")));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("حدث خطأ: $e ❌")));
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'new-order': return 'انتظار المراجعة';
      case 'processing': return 'جاري التجهيز';
      case 'shipped': return 'في الطريق';
      case 'delivered': return 'تم الاستلام';
      case 'cancelled': return 'ملغى من المورد';
      default: return status;
    }
  }

  Widget _buildEmptyState() => Center(
          child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_outlined, size: 50.sp, color: Colors.grey),
          Text("لا توجد طلبات في قسم ${_getStatusText(_selectedFilter)}", style: TextStyle(fontSize: 13.sp, color: Colors.grey)),
        ],
      ));

  Widget _buildErrorState(String error) => Center(child: Text("خطأ في الاتصال: $error", style: TextStyle(fontSize: 12.sp, color: Colors.red)));
}

