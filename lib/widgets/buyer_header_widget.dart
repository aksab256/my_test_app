// المسار: lib/widgets/buyer_header_widget.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_fonts/google_fonts.dart'; // 💡 إضافة الخطوط لتحسين المظهر

// تعريفات Firebase (مضمنة هنا لجعله وحدة مستقلة)
final FirebaseAuth _auth = FirebaseAuth.instance;

// 🚨 [التعديل النهائي الصحيح]: استخدام رابط الجذر فقط (بدون index.html)
const String _privacyPolicyUrl = 'https://aksab.shop/privacy';

// 💡 الدالة المساعدة لفتح الرابط الخارجي (باستخدام url_launcher)
void _launchUrlExternal(BuildContext context, String url) async {
  final Uri uri = Uri.parse(url);
  if (await canLaunchUrl(uri)) {
    // نستخدم وضع خارجي (externalApplication) لفتح متصفح النظام
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } else {
    // رسالة خطأ للمستخدم في حالة فشل فتح الرابط
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('عذراً، لا يمكن فتح رابط السياسة حالياً.')),
    );
  }
}

class BuyerHeaderWidget extends StatelessWidget {
  final VoidCallback onMenuToggle;
  final String userName;
  final bool menuNotificationDotActive;
  final VoidCallback onLogout;

  const BuyerHeaderWidget({
    super.key,
    required this.onMenuToggle,
    required this.userName,
    this.menuNotificationDotActive = false,
    required this.onLogout,
  });

  // --- بناء المودال المؤقتة ---
  static void _showNewOrdersModal(BuildContext context) {
    Navigator.pop(context); // إغلاق الـ Drawer أولاً
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: const Text('طلبات دليفري جديدة (مودال مؤقت)'),
            content: const Text('هنا ستظهر قائمة مختصرة بطلبات الدليفري الجديدة.'),
            actions: [
              TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('إغلاق')),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  // توجيه لصفحة افتراضية
                  Navigator.of(context).pushNamed('/con-orders');
                },
                child: const Text('عرض كل الطلبات'),
              ),
            ],
          ),
        );
      },
    );
  }

  // --- دالة مساعدة لـ ListTile (تحسين M3) ---
  static Widget _buildDrawerTile(Function(String) navigate, Map<String, dynamic> item, Color color, BuildContext context) {
    // 💡 استخدام GoogleFonts و FontWeight.w600 لاسم العنصر
    final textStyle = GoogleFonts.notoSansArabic(fontSize: 16, fontWeight: FontWeight.w600, color: color);

    return ListTile(
      leading: Icon(item['icon'] as IconData, color: color),
      title: Text(item['title'] as String, style: textStyle),
      trailing: (item['notificationCount'] is int && item['notificationCount'] > 0)
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              // 💡 تصميم M3 للنوتيفيكيشن (حواف مستديرة أكثر وخط سميك)
              decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(16)),
              child: Text(
                '${item['notificationCount']}',
                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
              ),
            )
          : null,
      onTap: () {
        if (item['onTap'] != null) {
          // 🚨 استدعاء onTap المعرف في navItems
          item['onTap']();
        } else if (item['route'] != null) {
          navigate(item['route'] as String);
        }
      },
    );
  }

  // --- بناء القائمة الجانبية (Sidebar / Drawer) --- (تحسين M3 وترتيب الأيقونات)
  static Widget buildSidebar({
    required BuildContext context,
    required VoidCallback onLogout,
    int newOrdersCount = 0,
    bool deliveryIsActive = true,
    bool deliverySettingsAvailable = false,
    bool deliveryPricesAvailable = true,
  }) {
    void navigateTo(String route) {
      Navigator.pop(context);
      Navigator.of(context).pushNamed(route);
    }

    const Color primaryColor = Color(0xFF2c3e50);
    const Color accentColor = Color(0xFF4CAF50); // الأخضر
    const Color highlightColor = Color(0xFFC62828); // أحمر غامق

    // 🟢 [إعادة ترتيب الأيقونات - الجزء العلوي]
    final List<Map<String, dynamic>> mainNavItems = [
      {'title': 'التجار', 'icon': Icons.storefront_rounded, 'route': '/traders'},
      {'title': 'محفظتى', 'icon': Icons.account_balance_wallet_rounded, 'route': '/wallet'},
      {'title': 'من نحن', 'icon': Icons.info_outline_rounded, 'route': '/about'},
    ];

    final List<Map<String, dynamic>> deliveryItems = [];

    if (deliverySettingsAvailable) {
      deliveryItems.add({'title': 'خدمة الدليفري', 'icon': Icons.local_shipping_rounded, 'route': '/deliverySettings'});
    }
    if (deliveryPricesAvailable) {
      deliveryItems.add({'title': 'إدارة أسعار الدليفري', 'icon': Icons.price_change_rounded, 'route': '/deliveryPrices'});
    }
    if (deliveryIsActive) {
      deliveryItems.add({
        'title': 'طلبات الدليفري',
        'icon': Icons.shopping_bag_rounded,
        'onTap': () => _showNewOrdersModal(context),
        'notificationCount': newOrdersCount,
      });
    }

    // 🟢 [إعادة ترتيب الأيقونات - الجزء السفلي]
    final List<Map<String, dynamic>> bottomNavItems = [
      {'title': 'حسابي', 'icon': Icons.account_circle_rounded, 'route': '/myDetails'},
      {'title': 'الخصوصية وشروط الاستخدام',
        'icon': Icons.description_rounded,
        'onTap': () {
          Navigator.pop(context); // إغلاق الـ Drawer
          // استخدام الدالة المساعدة لفتح الرابط الثابت المصحح
          _launchUrlExternal(context, _privacyPolicyUrl);
        }
      },
    ];

    return Drawer(
      child: Column(
        children: [
          // 💡 الـ DrawerHeader (تحسين M3)
          DrawerHeader(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [primaryColor, accentColor],
                begin: Alignment.centerRight,
                end: Alignment.centerLeft,
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.store_rounded, size: 40, color: Colors.white),
                const SizedBox(height: 8),
                Text(
                  'أسواق أكسب',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.notoSansArabic(fontSize: 24, color: Colors.white, fontWeight: FontWeight.bold),
                ),
                Text(
                  'تسوق بسهولة وأمان',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.notoSansArabic(color: Colors.white70, fontSize: 14),
                ),
              ],
            ),
          ),

          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                // --- المجموعة الأولى: المشتري الأساسي ---
                for (var item in mainNavItems) _buildDrawerTile(navigateTo, item, primaryColor, context),

                // --- فاصل M3 للتنظيم ---
                const SizedBox(height: 10),
                const Divider(height: 1, thickness: 1, indent: 16, endIndent: 16),
                const SizedBox(height: 10),

                // --- المجموعة الثانية: وظائف الدليفري/التاجر (المنطق محفوظ) ---
                if (deliveryItems.isNotEmpty) ...[
                  for (var item in deliveryItems)
                    _buildDrawerTile(
                      navigateTo,
                      item,
                      // تمييز طلبات الدليفري بلون مختلف للفت الانتباه
                      item['title'] == 'طلبات الدليفري' ? highlightColor : primaryColor,
                      context
                    ),
                  // فاصل M3 بعد مجموعة الدليفري
                  const SizedBox(height: 10),
                  const Divider(height: 1, thickness: 1, indent: 16, endIndent: 16),
                  const SizedBox(height: 10),
                ],

                // --- المجموعة الثالثة: المعلومات الشخصية والخصوصية (تم نقلها للأسفل) ---
                for (var item in bottomNavItems) _buildDrawerTile(navigateTo, item, primaryColor, context),
              ],
            ),
          ),

          // --- تسجيل الخروج (مفصول في الأسفل) ---
          Padding(
            padding: const EdgeInsets.only(bottom: 24.0, top: 10.0), // زيادة الـ Padding السفلي
            child: ListTile(
              leading: const Icon(Icons.logout_rounded, color: highlightColor),
              title: Text('تسجيل الخروج', style: GoogleFonts.notoSansArabic(fontSize: 16, color: highlightColor, fontWeight: FontWeight.w700)), // خط سميك للتأكيد
              onTap: onLogout,
            ),
          ),

          // 💡 الروابط الاجتماعية
          Padding(
            padding: const EdgeInsets.only(bottom: 24.0), // زيادة الـ Padding السفلي
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.message_rounded, size: 28, color: accentColor), // استخدام اللون الأخضر
                SizedBox(width: 24),
                Icon(Icons.facebook, size: 28, color: accentColor),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- بناء الرأس العلوي (Top Header) --- (التصحيح النهائي للتنسيق والألوان)
  @override
  Widget build(BuildContext context) {
    // 💡 الألوان الأصلية
    const Color primaryColor = Color(0xFF2c3e50);
    const Color accentColor = Color(0xFF4CAF50);
    
    return Container(
      // 🚀 التعديل: تقليص الارتفاع والحواف المنحنية (تم الحفاظ عليها)
      padding: const EdgeInsets.only(top: 45, bottom: 10, right: 15, left: 15), 
      decoration: const BoxDecoration(
        // ✅ التصحيح: العودة إلى التدرج اللوني بين primaryColor و accentColor فقط
        gradient: LinearGradient(
          colors: [primaryColor, accentColor], // الأخضر الغامق -> الأخضر الفاتح
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,   
        ),
        boxShadow: [BoxShadow(color: Colors.black38, blurRadius: 4, offset: Offset(0, 2))],
        // ✅ الحواف المنحنية في الأسفل (تم الحفاظ عليها)
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(25), // حواف منحنية أنيقة
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // 1. زر القائمة (Menu Toggle)
              InkWell(
                onTap: onMenuToggle,
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.all(6.0), 
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      const Icon(Icons.menu_rounded, size: 28, color: Colors.white), 
                      if (menuNotificationDotActive)
                        Positioned(
                          top: -1,
                          right: -1,
                          child: Container(
                            width: 10,
                            height: 10,
                            decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // 2. اسم التطبيق
              const Row(
                mainAxisSize: MainAxisSize.min, 
                children: [
                  Icon(Icons.store_rounded, size: 24, color: Colors.white), 
                  SizedBox(width: 6),
                  Text('أسواق أكسب', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)), 
                ],
              ),

              // 3. مساحة احتياطية
              const SizedBox(width: 40),
            ],
          ),

          // 4. رسالة الترحيب
          Padding(
            padding: const EdgeInsets.only(right: 5.0, top: 5.0),
            child: Text(
              userName,
              textAlign: TextAlign.right,
              style: GoogleFonts.notoSansArabic(fontSize: 15, color: Colors.white, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
