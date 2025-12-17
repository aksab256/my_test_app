// lib/screens/seller/orders_screen.dart

import 'package:flutter/material.dart';
import 'package:my_test_app/data_sources/order_data_source.dart';
import 'package:my_test_app/models/order_model.dart';
import 'package:my_test_app/services/excel_exporter.dart';
import 'package:my_test_app/screens/invoice_screen.dart';
import 'package:sizer/sizer.dart';

class OrdersScreen extends StatefulWidget {
  final String userId;
  final String userRole;

  const OrdersScreen({super.key, required this.userId, required this.userRole});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  late Future<List<OrderModel>> _ordersFuture;
  final OrderDataSource _dataSource = OrderDataSource();
  List<OrderModel> _loadedOrders = [];
  bool _isLoading = false;
  String _selectedFilter = 'all'; 

  @override
  void initState() {
    super.initState();
    _ordersFuture = _fetchOrders();
  }

  Future<List<OrderModel>> _fetchOrders() async {
    return await _dataSource.loadOrders(widget.userId, widget.userRole);
  }

  Color _getStatusColor(String status) {
    if (status == 'new-order') return Colors.red.shade600;
    if (status == 'processing') return Colors.orange.shade700;
    if (status == 'delivered' || status == 'completed') return Colors.green.shade700;
    return Colors.blue.shade700;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: Text(widget.userRole == 'seller' ? 'الطلبات الواردة' : 'طلباتي', 
               style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w900, color: Colors.white)),
        backgroundColor: Theme.of(context).primaryColor,
        centerTitle: true,
        actions: [
          IconButton(icon: Icon(Icons.share, color: Colors.white, size: 22.sp), onPressed: _exportToExcel),
        ],
      ),
      body: Column(
        children: [
          _buildFilterBar(),
          Expanded(
            child: FutureBuilder<List<OrderModel>>(
              future: _ordersFuture,
              builder: (context, snapshot) {
                // ✅ حل الومضة الحمراء: التأكد من حالة البيانات قبل البناء
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) return _buildErrorState(snapshot.error.toString());
                
                _loadedOrders = snapshot.data ?? [];
                final filteredList = _selectedFilter == 'all' 
                    ? _loadedOrders 
                    : _loadedOrders.where((o) => o.status == _selectedFilter).toList();

                if (filteredList.isEmpty) return _buildEmptyState();

                return ListView.builder(
                  padding: EdgeInsets.all(3.w),
                  itemCount: filteredList.length,
                  itemBuilder: (context, index) => _buildOrderCard(filteredList[index]),
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
      padding: EdgeInsets.symmetric(vertical: 1.2.h),
      color: Colors.white,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 2.w),
        children: [
          _buildFilterChip('الكل', 'all'),
          _buildFilterChip('جديد', 'new-order'),
          _buildFilterChip('تجهيز', 'processing'),
          _buildFilterChip('تسليم', 'delivered'),
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
        selectedColor: Theme.of(context).primaryColor,
        onSelected: (val) => setState(() => _selectedFilter = value),
      ),
    );
  }

  Widget _buildOrderCard(OrderModel order) {
    final color = _getStatusColor(order.status);
    return Card(
      margin: EdgeInsets.only(bottom: 1.5.h),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: ExpansionTile(
        tilePadding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 0.5.h),
        leading: Icon(Icons.store_rounded, color: color, size: 28.sp),
        title: Text(order.buyerDetails.name, style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w900)),
        subtitle: Text("${order.totalAmount.toStringAsFixed(2)} ج.م", 
                  style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.bold, color: color)),
        children: [
          Padding(
            padding: EdgeInsets.all(4.w),
            child: Column(
              children: [
                const Divider(),
                _buildInfoRow(Icons.phone, "هاتف: ${order.buyerDetails.phone ?? 'نقص'}", Colors.green),
                _buildInfoRow(Icons.location_pin, "عنوان: ${order.buyerDetails.address ?? 'نقص'}", Colors.red),
                SizedBox(height: 2.h),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(padding: EdgeInsets.symmetric(vertical: 1.5.h)),
                        onPressed: () => _showOrderDetails(order),
                        icon: const Icon(Icons.list),
                        label: Text("المنتجات", style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    if (widget.userRole == 'seller' && order.status != 'delivered') ...[
                      SizedBox(width: 2.w),
                      Expanded(child: _buildStatusDropdown(order)),
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

  Widget _buildInfoRow(IconData icon, String text, Color col) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 0.5.h),
      child: Row(children: [
        Icon(icon, size: 16.sp, color: col),
        SizedBox(width: 2.w),
        Expanded(child: Text(text, style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w600))),
      ]),
    );
  }

  // ... (تتمة الدوال المساعدة مثل _showOrderDetails و _buildStatusDropdown بنفس منطق تكبير الخطوط)
  // تم تحسين الأحجام في ModalBottomSheet لتصل إلى 15.sp و 18.sp للوضوح
  
  void _showOrderDetails(OrderModel order) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: 80.h,
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
        padding: EdgeInsets.all(5.w),
        child: Column(children: [
          Text("تفاصيل المنتجات", style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w900)),
          const Divider(),
          Expanded(
            child: ListView.builder(
              itemCount: order.items.length,
              itemBuilder: (context, i) => ListTile(
                title: Text(order.items[i].name, style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold)),
                subtitle: Text("${order.items[i].quantity} وحدة", style: TextStyle(fontSize: 12.sp)),
                trailing: Text("${order.items[i].unitPrice} ج.م", style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.bold)),
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(minimumSize: Size(double.infinity, 7.h)),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => InvoiceScreen(order: order))),
            child: Text("فتح الفاتورة للطباعة", style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.bold)),
          )
        ]),
      ),
    );
  }

  Widget _buildStatusDropdown(OrderModel order) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 2.w),
      decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(10)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: order.status,
          isExpanded: true,
          items: const [
            DropdownMenuItem(value: 'new-order', child: Text('جديد')),
            DropdownMenuItem(value: 'processing', child: Text('تجهيز')),
            DropdownMenuItem(value: 'delivered', child: Text('تسليم')),
          ],
          onChanged: (val) async {
             if (val != null) {
               await _dataSource.updateOrderStatus(order.id, val);
               setState(() { _ordersFuture = _fetchOrders(); });
             }
          },
        ),
      ),
    );
  }

  void _exportToExcel() async {
    try {
      await ExcelExporter.exportOrders(_loadedOrders, widget.userRole);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("تم التصدير بنجاح")));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("خطأ في التصدير: $e")));
    }
  }

  Widget _buildEmptyState() => const Center(child: Text("لا توجد طلبات"));
  Widget _buildErrorState(String error) => Center(child: Text("خطأ: $error"));
}
