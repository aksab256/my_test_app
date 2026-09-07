// lib/widgets/trader_sidebar_widget.dart
import 'package:flutter/material.dart';
import 'delivery_prices_menu_tile.dart';

class TraderSidebarWidget extends StatelessWidget {
  const TraderSidebarWidget({super.key});

  // 💡 لون الأيقونة النشط والمميز (كما في التصميم: الأخضر #4CAF50)
  static const Color activeColor = Color(0xFF4CAF50); 
  // 💡 لون النص الافتراضي (Blue Gray #2c3e50)
  static const Color primaryTextColor = Color(0xFF2c3e50); 

  void _navigateTo(BuildContext context, String route) {
    Navigator.pop(context); // إغلاق الـ Drawer
    Navigator.of(context).pushNamed(route);
  }

  // تعريف عناصر القائمة الرئيسية (باستثناء "أسعار الدليفري")
  final List<Map<String, dynamic>> navItems = const [
    {'title': 'لوحة القيادة', 'icon': Icons.dashboard_rounded, 'route': '/'},
    {'title': 'اضافة المنتجات', 'icon': Icons.add_box_rounded, 'route': '/product_management'},
    {'title': 'تحديث معلومات التوصيل', 'icon': Icons.local_shipping_rounded, 'route': '/updatsupermarket'},
    {'title': 'إدارة الطلبات', 'icon': Icons.assignment_rounded, 'route': '/con-orders'},
    // ** تم حذف 'المنتجات المعروضة' هنا ليتم وضعها بعد قائمة 'أسعار الدليفري'
  ];

  // بناء عنصر قائمة عادي
  Widget _buildNavTile(BuildContext context, Map<String, dynamic> item) {
    // تحديد ما إذا كان العنصر هو الصفحة الحالية (لتطبيق الكلاس 'active' من HTML)
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
        // 💡 تطبيق خلفية اللون النشط (#4CAF50) عند التفعيل
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
          // 💡 Header: يحاكي تصميم sidebar-header في HTML
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end, // Align to right (RTL)
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: const [
                    Text('لوحة تحكم التاجر', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: primaryTextColor)),
                  ],
                ),
                const SizedBox(width: 10),
                Icon(Icons.store_rounded, size: 36, color: activeColor),
              ],
            ),
          ),
          
          // 💡 Nav Items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(10),
              children: [
                // 1. العناصر العادية قبل قائمة الدليفري
                ...navItems.map((item) => _buildNavTile(context, item)),
                
                // 2. عنصر أسعار الدليفري القابل للتوسيع
                const DeliveryPricesMenuTile(), 
                
                // 3. عنصر 'المنتجات المعروضة'
                _buildNavTile(context, {'title': 'المنتجات المعروضة', 'icon': Icons.handshake_rounded, 'route': '/view-offer'}),
              ],
            ),
          ),

          // 💡 Footer: يحاكي تصميم sidebar-footer في HTML
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Column(
              children: [
                // زر "العودة للتسوق"
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context); 
                    // 💡 التوجيه لصفحة المتجر الرئيسية (constore.html)
                    Navigator.of(context).pushNamedAndRemoveUntil('/constore', (route) => false); 
                  },
                  icon: const Icon(Icons.shopping_basket_rounded),
                  label: const Text('العودة للتسوق', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF007bff), // Blue color: var(--return-btn-bg)
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(height: 10),
                // تبديل الثيم (مثال تخيلي في Flutter)
                ListTile(
                  leading: const Icon(Icons.dark_mode_rounded, color: primaryTextColor),
                  title: const Text('الوضع الداكن', style: TextStyle(fontSize: 16)),
                  onTap: () {
                    // 💡 هنا يتم تطبيق منطق تبديل الثيم الفعلي (إذا كان موجوداً في التطبيق)
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

