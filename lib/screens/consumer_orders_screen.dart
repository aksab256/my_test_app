// lib/screens/consumer_orders_screen.dart           
import 'package:flutter/material.dart';              
import 'package:provider/provider.dart';             
import 'package:cloud_firestore/cloud_firestore.dart';                                                    
import '../providers/customer_orders_provider.dart';
import '../models/consumer_order_model.dart';        
import '../constants/constants.dart';                                                                     

class ConsumerOrdersScreen extends StatelessWidget {   
  const ConsumerOrdersScreen({super.key});                                                                  
  
  @override                                            
  Widget build(BuildContext context) {
    final ordersProvider = Provider.of<CustomerOrdersProvider>(context);                                                                                           
    return Scaffold(                                       
      appBar: AppBar(                                        
        title: const Text('طلبات العملاء'),
        centerTitle: true,                                   
        backgroundColor: Colors.white,                       
        foregroundColor: const Color(0xFF4CAF50),            
        elevation: 1,
      ),
      body: ordersProvider.isLoading                           
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF4CAF50)))                                
          : ordersProvider.orders.isEmpty
              ? Center(child: Text(ordersProvider.message ?? 'لا توجد طلبات لعرضها حاليًا.'))                            
              : ListView.builder(                                      
                  padding: const EdgeInsets.all(15),
                  itemCount: ordersProvider.orders.length,
                  itemBuilder: (context, index) {                        
                    final order = ordersProvider.orders[index];
                    return OrderCard(order: order, provider: ordersProvider);
                  },                                                 
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

  Widget _buildItemsList(ConsumerOrderModel order) {     
    if (order.items.isEmpty) {                             
      return const Text('لا توجد منتجات في هذا الطلب.');
    }                                                    
    return Column(                                         
      crossAxisAlignment: CrossAxisAlignment.start,        
      children: order.items.map((item) {                     
        return Padding(
          padding: const EdgeInsets.only(bottom: 8.0),                                                              
          child: Row(                                            
            children: [
              if (item.imageUrl != null && item.imageUrl!.isNotEmpty)                                                     
                Image.network(                                         
                  item.imageUrl!,
                  width: 50,                                           
                  height: 50,                                          
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => const Icon(Icons.image_not_supported),                    
                ),                                                 
              const SizedBox(width: 10),
              Expanded(                                              
                child: Text(                                           
                  '${item.name ?? 'منتج غير معروف'} (الكمية: ${item.quantity ?? 1})',
                  style: const TextStyle(fontSize: 14),                                                                   
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
      margin: const EdgeInsets.only(bottom: 20),           
      shape: RoundedRectangleBorder(                         
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: borderColor, width: 5),                                                         
      ),                                                   
      elevation: 5,                                        
      child: InkWell(
        onTap: () {                                            
          setState(() {                                          
            _isExpanded = !_isExpanded;
          });                                                
        },
        child: Padding(                                        
          padding: const EdgeInsets.all(20.0),
          child: Column(                                         
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [                                            
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(                                              
                    child: Column(                                         
                      crossAxisAlignment: CrossAxisAlignment.start,                                                             
                      children: [                                            
                        Text('طلب رقم: ${order.orderId}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF4CAF50))),
                        const SizedBox(height: 5),                           
                        Text('العميل: ${order.customerName}', style: const TextStyle(fontSize: 15)),                              
                        Text('المبلغ الإجمالي: ${order.finalAmount.toStringAsFixed(2)} EGP', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),                                                                            
                        Text('الحالة: ${getStatusDisplayName(order.status)}', style: TextStyle(fontSize: 15, color: borderColor)),                                                   
                      ],                                                 
                    ),
                  ),                                                   
                  Icon(                                                  
                    _isExpanded ? Icons.keyboard_arrow_down : Icons.chevron_left,                                             
                    color: Colors.grey,
                  ),                                                 
                ],
              ),                                                                                                        
              if (_isExpanded) ...[                                  
                const Divider(height: 30),                                                                                
                Text('تفاصيل الطلب الكاملة:', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF4CAF50))),                                    
                const SizedBox(height: 10),
                Text('رقم الهاتف: ${order.customerPhone}'),
                Text('العنوان: ${order.customerAddress}'),                                                                
                // 🟢 استخدام التنسيق الجديد
                Text('تاريخ الطلب: ${order.orderDate?.toLocaleString() ?? 'غير متوفر'}'),                 
                Text('مصاريف التوصيل: ${order.deliveryFee.toStringAsFixed(2)} EGP'),                                      
                Text('النقاط المستخدمة: ${order.pointsUsed}'),
                const Divider(height: 30),
                Text('المنتجات:', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF4CAF50))),                                                
                const SizedBox(height: 10),
                _buildItemsList(order),              
                const Divider(height: 30),                                                                                
                Column(                                                
                  crossAxisAlignment: CrossAxisAlignment.stretch,                                                           
                  children: [                                            
                    const Text('تغيير الحالة:', style: TextStyle(fontSize: 14, color: Color(0xFF555555))),                    
                    const SizedBox(height: 8),                           
                    DropdownButtonFormField<String>(
                      value: _selectedStatus,                              
                      items: OrderStatusesHelpers.allStatuses.map((status) {                                                      
                        return DropdownMenuItem(
                          value: status,                                       
                          child: Text(getStatusDisplayName(status)),                                                              
                        );                                                 
                      }).toList(),                                         
                      onChanged: isDisabled ? null : (newValue) {                                                                 
                        setState(() {                                          
                          _selectedStatus = newValue!;                                                                            
                        });                                                
                      },                                                   
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        enabled: !isDisabled,                              
                      ),
                    ),                                                   
                    const SizedBox(height: 10),                          
                    ElevatedButton.icon(                                   
                      onPressed: isDisabled ? null : () {                                                                         
                        widget.provider.updateOrderStatus(order.id, _selectedStatus);                                           
                      },                                                   
                      icon: const Icon(Icons.sync_alt, size: 20),                                                               
                      label: Text(isDisabled ? 'لا يمكن التحديث' : 'تحديث الحالة'),                                             
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4CAF50),                                                                 
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),                                                        
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),                                  
                      ),                                                 
                    ),
                    const SizedBox(height: 10),                          
                    ElevatedButton.icon(                                   
                      onPressed: () {                                        
                        widget.provider.showNotification('لم يتم تنفيذ منطق الطباعة بعد.', false);                              
                      },                                                   
                      icon: const Icon(Icons.print, size: 20),                                                                  
                      label: const Text('طباعة الإيصال'),                                                                       
                      style: ElevatedButton.styleFrom(                                                                            
                        backgroundColor: const Color(0xFF007bff),                                                                 
                        foregroundColor: Colors.white,                                                                            
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),                                  
                      ),
                    ),
                  ],                                                 
                ),                                                 
              ],                                                 
            ],                                                 
          ),                                                 
        ),                                                 
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

// 🟢 تعديل الـ Extension ليعمل مع DateTime الخاص بالموديل الجديد
extension DateParsing on DateTime {
  String toLocaleString() {                              
    return this.toString().split('.')[0];
  }                                                  
}
