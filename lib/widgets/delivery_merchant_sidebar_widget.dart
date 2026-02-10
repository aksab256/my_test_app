// المسار: lib/widgets/delivery_merchant_sidebar_widget.dart

import 'package:flutter/material.dart';
// استيراد الشاشات لضمان الوصول للمسارات الصحيحة
import '../screens/delivery/product_offer_screen.dart';
import '../screens/delivery/delivery_offers_screen.dart';

class DeliveryMerchantSidebarWidget extends StatelessWidget {
  const DeliveryMerchantSidebarWidget({super.key});

  static const Color activeColor = Color(0xFF4CAF50);
  static const Color primaryTextColor = Color(0xFF2c3e50);

  void _navigateTo(BuildContext context, String route) {
    Navigator.pop(context); // إغلاق الدرج الجانبي
    Navigator.of(context).pushNamed(route);
  }

  @override
  Widget build(BuildContext context) {
    // جلب اسم المسار الحالي لتحديد الأيقونة النشطة
    final String? currentRoute = ModalRoute.of(context)?.settings.name;

    return Drawer(
      child: SafeArea( 
        // 🛡️ SafeArea هنا بتعمل حماية من فوق (الساعة) ومن تحت (شريط التنقل)
        top: true,
        bottom: true, 
        child: Column(
          children: [
            // رأس القائمة (Header)
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
                      Text('لوحة تحكم التوصيل', 
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: primaryTextColor)),
                    ],
                  ),
                  const SizedBox(width: 10),
                  Icon(Icons.store_rounded, size: 36, color: activeColor),
                ],
              ),
            ),

            // العناصر القابلة للتنقل
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(10),
                children: [
                  // 1. لوحة القيادة
                  _buildNavTile(context, 'لوحة القيادة', Icons.dashboard_rounded, '/deliveryMerchantDashboard', currentRoute),
                  
                  // 2. إضافة المنتجات (تفتح ProductOfferScreen)
                  _buildNavTile(context, 'اضافة المنتجات', Icons.add_box_rounded, ProductOfferScreen.routeName, currentRoute),
                  
                  // 3. المنتجات المعروضة (تفتح DeliveryOffersScreen)
                  _buildNavTile(context, 'المنتجات المعروضة', Icons.handshake_rounded, DeliveryOffersScreen.routeName, currentRoute),
                  
                  // 4. تحديث المعلومات
                  _buildNavTile(context, 'تحديث معلومات التوصيل', Icons.local_shipping_rounded, '/updatsupermarket', currentRoute),
                  
                  // 5. إدارة الطلبات
                  _buildNavTile(context, 'إدارة الطلبات', Icons.assignment_rounded, '/con-orders', currentRoute),
                ],
              ),
            ),

            // الجزء السفلي (العودة للمتجر)
            // 💡 هنا يتم التأكد من أن الزر بعيد عن حافة الشاشة السفلية
            Container(
              padding: const EdgeInsets.only(left: 20, right: 20, top: 20, bottom: 10), 
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.of(context).pushNamedAndRemoveUntil('/constore', (route) => false);
                    },
                    icon: const Icon(Icons.shopping_basket_rounded),
                    label: const Text('العودة للتسوق', 
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF007bff),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ويدجت مساعد لبناء العناصر لتقليل تكرار الكود
  Widget _buildNavTile(BuildContext context, String title, IconData icon, String route, String? currentRoute) {
    final bool isActive = currentRoute == route;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: ListTile(
        leading: Icon(icon, size: 22, color: isActive ? Colors.white : primaryTextColor),
        title: Text(title,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w500,
            color: isActive ? Colors.white : primaryTextColor,
          ),
        ),
        onTap: () => _navigateTo(context, route),
        selected: isActive,
        selectedTileColor: activeColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
      ),
    );
  }
}
