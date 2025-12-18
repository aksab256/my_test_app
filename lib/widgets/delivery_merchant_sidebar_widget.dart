// lib/widgets/delivery_merchant_sidebar_widget.dart

import 'package:flutter/material.dart';
// 🗑️ تم حذف import 'delivery_prices_menu_tile.dart'

class DeliveryMerchantSidebarWidget extends StatelessWidget {
  const DeliveryMerchantSidebarWidget({super.key});  

  static const Color activeColor = Color(0xFF4CAF50);
  static const Color primaryTextColor = Color(0xFF2c3e50);                                                
  
  void _navigateTo(BuildContext context, String route) {
    Navigator.pop(context);
    Navigator.of(context).pushNamed(route);
  }

  final List<Map<String, dynamic>> navItems = const [
    {'title': 'لوحة القيادة', 'icon': Icons.dashboard_rounded, 'route': '/deliveryMerchantDashboard'},
    {'title': 'اضافة المنتجات', 'icon': Icons.add_box_rounded, 'route': '/product_management'},
    {'title': 'تحديث معلومات التوصيل', 'icon': Icons.local_shipping_rounded, 'route': '/updatsupermarket'},
    {'title': 'إدارة الطلبات', 'icon': Icons.assignment_rounded, 'route': '/con-orders'},
  ];

  Widget _buildNavTile(BuildContext context, Map<String, dynamic> item) {
    final bool isActive = ModalRoute.of(context)?.settings.name == item['route'];

    return Padding(                                  
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: ListTile(
        leading: Icon(                               
          item['icon'] as IconData,
          size: 22,                                  
          color: isActive ? Colors.white : primaryTextColor,
        ),                                           
        title: Text(                                 
          item['title'] as String,                   
          style: TextStyle(                          
            fontSize: 17,                            
            fontWeight: FontWeight.w500,             
            color: isActive ? Colors.white : primaryTextColor,
          ),
        ),                                           
        onTap: () => _navigateTo(context, item['route']),
        selected: isActive,                          
        selectedTileColor: activeColor,              
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(                                   
      child: Column(                                 
        children: [
          Container(                                 
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
            decoration: BoxDecoration(               
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),                            
            ),
            child: Row(                              
              mainAxisAlignment: MainAxisAlignment.end,                                                   
              children: [
                const Column(                        
                  crossAxisAlignment: CrossAxisAlignment.end,                                             
                  children: [                        
                    Text('لوحة تحكم التوصيل', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: primaryTextColor)),
                  ],                                 
                ),                                   
                const SizedBox(width: 10),           
                Icon(Icons.store_rounded, size: 36, color: activeColor),                                  
              ],                                     
            ),
          ),
          Expanded(                                  
            child: ListView(
              padding: const EdgeInsets.all(10),
              children: [                            
                ...navItems.map((item) => _buildNavTile(context, item)),
                                                     
                // 🗑️ تم حذف استدعاء DeliveryPricesMenuTile من هنا
                                                     
                _buildNavTile(context, {'title': 'المنتجات المعروضة', 'icon': Icons.handshake_rounded, 'route': '/delivery-offers'}),                          
              ],
            ),                                       
          ),
                                                     
          Container(
            padding: const EdgeInsets.all(20),       
            decoration: BoxDecoration(               
              border: Border(top: BorderSide(color: Colors.grey.shade200)),                               
            ),                                       
            child: Column(                           
              children: [                            
                ElevatedButton.icon(
                  onPressed: () {                    
                    Navigator.pop(context);
                    Navigator.of(context).pushNamedAndRemoveUntil('/constore', (route) => false);                                                              
                  },                                 
                  icon: const Icon(Icons.shopping_basket_rounded),                                        
                  label: const Text('العودة للتسوق', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  style: ElevatedButton.styleFrom(                                                        
                    backgroundColor: const Color(0xFF007bff),                                             
                    foregroundColor: Colors.white,                                                        
                    minimumSize: const Size(double.infinity, 50),                                         
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),                                   
                const SizedBox(height: 10),
                ListTile(                            
                  leading: const Icon(Icons.dark_mode_rounded, color: primaryTextColor),
                  title: const Text('الوضع الداكن', style: TextStyle(fontSize: 16)),                      
                  onTap: () {
                    // منطق تبديل الثيم              
                  },                                 
                ),                                   
              ],                                     
            ),                                       
          ),
        ],                                           
      ),
    );
  }
}
