// المسار: lib/widgets/buyer_header_widget.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_fonts/google_fonts.dart'; 

// تعريفات Firebase
final FirebaseAuth _auth = FirebaseAuth.instance;

// [الروابط الرسمية المعتمدة]
const String _privacyPolicyUrl = 'https://aksab.shop/';
const String _facebookUrl = 'https://www.facebook.com/share/1APHYGD7m6/';
const String _whatsappUrl = 'https://wa.me/201021070462'; // رقم الواتساب الجديد
const String _supportEmail = 'Support@aksab.shop'; // إيميل الدومين الرسمي

// الدالة المساعدة لفتح الروابط الخارجية
void _launchUrlExternal(BuildContext context, String url) async {
  final Uri uri = Uri.parse(url);
  try {
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('عذراً، لا يمكن فتح الرابط حالياً.')),
        );
      }
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('خطأ في الاتصال بالرابط الخارجي')),
      );
    }
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
    final textStyle = GoogleFonts.notoSansArabic(fontSize: 16, fontWeight: FontWeight.w600, color: color);

    return ListTile(
      leading: Icon(item['icon'] as IconData, color: color),
      title: Text(item['title'] as String, style: textStyle),
      trailing: (item['notificationCount'] is int && item['notificationCount'] > 0)
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(16)),
              child: Text(
                '${item['notificationCount']}',
                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
              ),
            )
          : null,
      onTap: () {
        if (item['onTap'] != null) {
          item['onTap']();
        } else if (item['route'] != null) {
          navigate(item['route'] as String);
        }
      },
    );
  }

  // --- بناء القائمة الجانبية (Sidebar / Drawer) ---
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
    const Color accentColor = Color(0xFF4CAF50); 
    const Color highlightColor = Color(0xFFC62828);

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

    final List<Map<String, dynamic>> bottomNavItems = [
      {'title': 'حسابي', 'icon': Icons.account_circle_rounded, 'route': '/myDetails'},
      {'title': 'الخصوصية وشروط الاستخدام',
        'icon': Icons.description_rounded,
        'onTap': () {
          Navigator.pop(context);
          _launchUrlExternal(context, _privacyPolicyUrl);
        }
      },
    ];

    return Drawer(
      child: Column(
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(
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
                for (var item in mainNavItems) _buildDrawerTile(navigateTo, item, primaryColor, context),
                const SizedBox(height: 10),
                const Divider(height: 1, thickness: 1, indent: 16, endIndent: 16),
                const SizedBox(height: 10),

                if (deliveryItems.isNotEmpty) ...[
                  for (var item in deliveryItems)
                    _buildDrawerTile(
                      navigateTo,
                      item,
                      item['title'] == 'طلبات الدليفري' ? highlightColor : primaryColor,
                      context
                    ),
                  const SizedBox(height: 10),
                  const Divider(height: 1, thickness: 1, indent: 16, endIndent: 16),
                  const SizedBox(height: 10),
                ],

                for (var item in bottomNavItems) _buildDrawerTile(navigateTo, item, primaryColor, context),
              ],
            ),
          ),

          // تسجيل الخروج
          ListTile(
            leading: const Icon(Icons.logout_rounded, color: highlightColor),
            title: Text('تسجيل الخروج', style: GoogleFonts.notoSansArabic(fontSize: 16, color: highlightColor, fontWeight: FontWeight.w700)),
            onTap: onLogout,
          ),

          // 💡 الروابط الاجتماعية والدعم الفني (تم التفعيل والربط)
          Padding(
            padding: const EdgeInsets.only(bottom: 24.0, top: 10.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // واتساب
                    IconButton(
                      icon: const Icon(Icons.message_rounded, size: 28, color: Color(0xFF25D366)),
                      onPressed: () => _launchUrlExternal(context, _whatsappUrl),
                    ),
                    const SizedBox(width: 24),
                    // فيسبوك
                    IconButton(
                      icon: const Icon(Icons.facebook, size: 28, color: Color(0xFF1877F2)),
                      onPressed: () => _launchUrlExternal(context, _facebookUrl),
                    ),
                    const SizedBox(width: 24),
                    // إيميل الدعم
                    IconButton(
                      icon: const Icon(Icons.email_rounded, size: 28, color: primaryColor),
                      onPressed: () => _launchUrlExternal(context, 'mailto:$_supportEmail'),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'الدعم: $_supportEmail',
                  style: GoogleFonts.notoSansArabic(fontSize: 10, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFF2c3e50);
    const Color accentColor = Color(0xFF4CAF50);
    
    return Container(
      padding: const EdgeInsets.only(top: 45, bottom: 10, right: 15, left: 15), 
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [primaryColor, accentColor],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,   
        ),
        boxShadow: [BoxShadow(color: Colors.black38, blurRadius: 4, offset: Offset(0, 2))],
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
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
              const Row(
                mainAxisSize: MainAxisSize.min, 
                children: [
                  Icon(Icons.store_rounded, size: 24, color: Colors.white), 
                  SizedBox(width: 6),
                  Text('أسواق أكسب', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)), 
                ],
              ),
              const SizedBox(width: 40),
            ],
          ),
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
