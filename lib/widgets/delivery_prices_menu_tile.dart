// lib/widgets/delivery_prices_menu_tile.dart
import 'package:flutter/material.dart';

class DeliveryPricesMenuTile extends StatefulWidget {
  const DeliveryPricesMenuTile({super.key});

  @override
  State<DeliveryPricesMenuTile> createState() => _DeliveryPricesMenuTileState();
}

class _DeliveryPricesMenuTileState extends State<DeliveryPricesMenuTile> {
  bool _isExpanded = false;
  // 💡 لون الأيقونة النشط والمميز (كما في التصميم: الأخضر #4CAF50)
  static const Color activeColor = Color(0xFF4CAF50); 
  // 💡 لون النص الافتراضي (Blue Gray #2c3e50)
  static const Color primaryTextColor = Color(0xFF2c3e50); 
  // 💡 لون الخلفية عند التوسيع
  static const Color expandBgColor = Color(0xFFf0f0f0); 

  // تعريف العناصر الداخلية (الفرعية)
  final List<Map<String, dynamic>> subItems = const [
    {'title': 'إدارة مناطق الدليفري', 'icon': Icons.pin_drop_rounded, 'route': '/delivery_zones'},
    {'title': 'إدارة رسوم الدليفري', 'icon': Icons.monetization_on_rounded, 'route': '/delivery_fees'},
    {'title': 'إعدادات الدليفري العامة', 'icon': Icons.settings_rounded, 'route': '/delivery_settings'},
  ];

  void _navigateTo(BuildContext context, String route) {
    Navigator.pop(context); // إغلاق الـ Drawer
    Navigator.of(context).pushNamed(route);
  }

  // تصميم عنصر القائمة الفرعية
  Widget _buildSubTile(BuildContext context, Map<String, dynamic> item) {
    return InkWell(
      onTap: () => _navigateTo(context, item['route']),
      child: Padding(
        padding: const EdgeInsets.only(right: 45.0, top: 10.0, bottom: 10.0), // إزاحة للداخل
        child: Row(
          children: [
            Icon(item['icon'] as IconData, size: 20, color: primaryTextColor),
            const SizedBox(width: 10),
            Text(item['title'] as String, style: const TextStyle(fontSize: 15, color: primaryTextColor)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // الـ Tile الرئيسي (أسعار الدليفري)
        ListTile(
          // 💡 الأيقونة المستخدمة في HTML هي fa-hand-holding-usd، سنستخدم أيقونة مشابهة: price_change
          leading: Icon(Icons.price_change_rounded, size: 22, color: _isExpanded ? activeColor : primaryTextColor), 
          title: const Text(
            'أسعار الدليفري',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w500),
          ),
          trailing: Icon(
            _isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
            color: primaryTextColor,
          ),
          onTap: () {
            setState(() {
              _isExpanded = !_isExpanded;
            });
          },
          // 💡 تلوين الخلفية عند التوسيع لمطابقة الـ hover في HTML
          tileColor: _isExpanded ? expandBgColor : null, 
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
        ),
        
        // الأيقونات الفرعية التي تظهر عند التوسيع
        if (_isExpanded)
          Container(
            padding: const EdgeInsets.only(right: 15.0),
            decoration: const BoxDecoration(
              // 💡 تحديد لون الخلفية للعناصر الفرعية
              color: expandBgColor, 
              borderRadius: BorderRadius.only(
                bottomRight: Radius.circular(8),
                bottomLeft: Radius.circular(8),
              ),
            ),
            child: Column(
              children: subItems.map((item) => _buildSubTile(context, item)).toList(),
            ),
          ),
      ],
    );
  }
}
