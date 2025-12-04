// lib/main.dart

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:my_test_app/firebase_options.dart';
import 'package:sizer/sizer.dart';
// 💡 استيراد جديد لتهيئة بيانات اللغة
import 'package:intl/date_symbol_data_local.dart'; 

// 💡 استيراد شاشات التوجيه 💡
import 'package:my_test_app/screens/login_screen.dart';
import 'package:my_test_app/screens/auth/new_client_screen.dart';
import 'package:my_test_app/screens/buyer/buyer_home_screen.dart';
import 'package:my_test_app/screens/seller_screen.dart';
import 'package:my_test_app/screens/buyer/buyer_category_screen.dart';
import 'package:my_test_app/screens/buyer/buyer_product_list_screen.dart';
import 'package:my_test_app/screens/buyer/cart_screen.dart';
// 🟢🟢 سطر مضاف: استيراد شاشة إتمام الطلب 🟢🟢
import 'package:my_test_app/screens/checkout/checkout_screen.dart';

// 🎯🎯 استيرادات شاشات الدليفري المخصصة 🎯🎯
// ✅ 1. إعادة استيراد الشاشة القديمة (الإعدادات الأولية)
import 'package:my_test_app/screens/delivery_settings_screen.dart';
// ✅ 2. إضافة استيراد شاشة التحديث الجديدة
import 'package:my_test_app/screens/update_delivery_settings_screen.dart';
import 'package:my_test_app/screens/delivery_merchant_dashboard_screen.dart';

// 💡💡 إضافة استيراد شاشة طلبات العملاء الجديدة 💡💡
import 'package:my_test_app/screens/consumer_orders_screen.dart';

// 🆕🆕 استيرادات شاشات التجار الجديدة 🆕🆕
import 'package:my_test_app/screens/buyer/traders_screen.dart';
// 🎯 الاستيراد الحقيقي:
import 'package:my_test_app/screens/buyer/trader_offers_screen.dart';
// 🆕🆕 نهاية استيرادات شاشات التجار الجديدة 🆕 🆕

// 💡 استيرادات الثيم والمزودات (تم نقلها للأعلى لتجنب الخطأ) 💡
import 'package:my_test_app/theme/app_theme.dart';
import 'package:my_test_app/providers/buyer_data_provider.dart';
import 'package:my_test_app/providers/manufacturers_provider.dart';
import 'package:my_test_app/providers/cart_provider.dart';
import 'package:my_test_app/models/logged_user.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:my_test_app/controllers/seller_dashboard_controller.dart';

// 🚀 التعديلات الجديدة: استيراد الشاشة والـ Provider الخاص بإضافة المنتج 🚀
import 'package:my_test_app/screens/delivery/product_offer_screen.dart';
import 'package:my_test_app/providers/product_offer_provider.dart';

// 💡 يجب استيراد الـ Provider الذي سبب المشكلة:
import 'package:my_test_app/providers/customer_orders_provider.dart';
// 🚀🚀 إضافة استيراد شاشة إدارة عروض الدليفري الجديدة 🚀🚀
import 'package:my_test_app/screens/delivery/delivery_offers_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 🚀🚀 التصحيح الجديد: تهيئة بيانات اللغة العربية لحل خطأ LocaleDataException 🚀🚀
  try {
    await initializeDateFormatting('ar', null); 
  } catch (e) {
    // يمكن تجاهل الخطأ في حالة عدم توفر البيانات، لكن من الأفضل رؤيته في وضع التطوير
    debugPrint('🚨 Error initializing Date Formatting for Arabic: $e');
  }
  
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('🚨 FATAL FIREBASE INIT ERROR: $e');
  }

  runApp(
    MultiProvider(
      providers: [

        ChangeNotifierProvider(
          create: (context) => BuyerDataProvider(),
        ),
        ChangeNotifierProvider(
          create: (context) => ManufacturersProvider(),
        ),
        ChangeNotifierProvider(
          create: (context) => CartProvider(),
        ),
        ChangeNotifierProvider(
          create: (context) => SellerDashboardController(),
        ),

        // 🟢🟢 التصحيح: تم إلغاء تعليق وإضافة CustomerOrdersProvider 🟢🟢
        ChangeNotifierProxyProvider<BuyerDataProvider, CustomerOrdersProvider>(
          create: (context) => CustomerOrdersProvider(Provider.of<BuyerDataProvider>(context, listen: false)),
          update: (context, buyerData, previous) => CustomerOrdersProvider(buyerData),
        ),
        
        // 🚀🚀 التصحيح الجديد: إضافة ProductOfferProvider لحل مشكلة ProviderNotFoundException 🚀🚀
        ChangeNotifierProxyProvider<BuyerDataProvider, ProductOfferProvider>(
          // نستخدم BuyerDataProvider لتهيئة المنتج في الـ Provider
          create: (context) => ProductOfferProvider(Provider.of<BuyerDataProvider>(context, listen: false)),
          update: (context, buyerData, previous) => ProductOfferProvider(buyerData),
        ),
        
        // -----------------------------------------------------------------
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Sizer(
      builder: (context, orientation, deviceType) {

        return MaterialApp(
          title: 'My Test App',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            primaryColor: AppTheme.primaryGreen,
            colorScheme: ColorScheme.light(
              primary: AppTheme.primaryGreen,
              secondary: AppTheme.accentBlueLight,
            ),
            scaffoldBackgroundColor: AppTheme.scaffoldLight,
            cardColor: Colors.white,
            textTheme: GoogleFonts.notoSansArabicTextTheme(
              const TextTheme(
                bodyLarge: TextStyle(color: Color(0xff343a40)),
              ),
            ),
          ),
          darkTheme: ThemeData.dark().copyWith(
            primaryColor: AppTheme.primaryGreen,
            colorScheme: ColorScheme.dark(
              primary: AppTheme.primaryGreen,
              secondary: const Color(0xff64B5F6),
              surface: const Color(0xff121212),
              onSurface: const Color(0xffe0e0e0),
            ),
            scaffoldBackgroundColor: const Color(0xff121212),
            cardColor: AppTheme.cardDark,
            drawerTheme: DrawerThemeData(backgroundColor: AppTheme.darkSidebarBg),
            textTheme: GoogleFonts.notoSansArabicTextTheme(
              const TextTheme(
                bodyLarge: TextStyle(color: Color(0xffe0e0e0)),
              ),
            ),
          ),
          builder: (context, child) {
            return Directionality(
              textDirection: TextDirection.rtl,
              child: child!,
            );
          },

          // ⭐️⭐️ تعريف المسارات المُسمّاة 'routes' ⭐️⭐️

          initialRoute: '/',
          routes: {
            '/': (context) => const AuthWrapper(),
            LoginScreen.routeName: (context) => const LoginScreen(),
            BuyerHomeScreen.routeName: (context) => const BuyerHomeScreen(),
            SellerScreen.routeName: (context) => const SellerScreen(),
            CartScreen.routeName: (context) => const CartScreen(),
            CheckoutScreen.routeName: (context) => const CheckoutScreen(),

            // ✅ المسار القديم: يحافظ على فتح شاشة الإعدادات الأولية
            '/deliverySettings': (context) => const DeliverySettingsScreen(),
            // ✅ التعديل المطلوب: المسار '/updatsupermarket' يفتح شاشة التحديث الجديدة
            '/updatsupermarket': (context) => const UpdateDeliverySettingsScreen(),
            // 🎯🎯 مسار لوحة القيادة (القديم): يفتح الشاشة المخصصة (للمستخدمين الآخرين)
            '/deliveryPrices': (context) => const DeliveryMerchantDashboardScreen(),
            // 🟢🟢 إضافة المسار الجديد: '/con-orders' يفتح شاشة طلبات العملاء 🟢🟢
            '/con-orders': (context) => const ConsumerOrdersScreen(),
            // 🚀🚀 إضافة مسار شاشة إدارة عروض الدليفري الجديدة 🚀🚀
            DeliveryOffersScreen.routeName: (context) => const DeliveryOffersScreen(),
            
            TradersScreen.routeName: (context) => const TradersScreen(),
            '/register': (context) => const NewClientScreen(),
            '/post_registration_message': (context) => const PostRegistrationMessageScreen(),
          },
          // 🆕 استخدام onGenerateRoute لفك الـ Map الخاص بـ '/products' و '/traderOffers'
          onGenerateRoute: (settings) {
            // 🚀 التعديل الجديد 1: إضافة مسار إضافة المنتجات مع الـ Provider 🚀
            if (settings.name == ProductOfferScreen.routeName) {
              return MaterialPageRoute(
                builder: (context) {
                  // 💡 يستخدم الـ Provider المتاح عالميًا الآن
                  return const ProductOfferScreen();
                },
              );
            }
            
            // 2. المسارات القديمة في onGenerateRoute
            if (settings.name == TraderOffersScreen.routeName) {
              final sellerId = settings.arguments as String? ?? '';
              return MaterialPageRoute(
                builder: (context) {
                  return TraderOffersScreen(sellerId: sellerId);
                },
              );
            }
            if (settings.name == '/products') {
              final args = settings.arguments as Map<String, String>? ?? {};
              return MaterialPageRoute(
                builder: (context) {
                  return BuyerProductListScreen(
                    mainCategoryId: args['mainId'] ?? '',
                    subCategoryId: args['subId'] ?? '',
                  );
                },
              );
            }
            if (settings.name == '/category') {
              final mainCategoryId = settings.arguments as String? ?? 'default_id';
              return MaterialPageRoute(
                builder: (context) => BuyerCategoryScreen(mainCategoryId: mainCategoryId),
              );
            }

            return null;
          },
        );
      },
    );
  }
}

// ⭐️⭐️ الـ Wrapper الذي يعكس منطق onAuthStateChanged في Flutter ⭐️⭐️
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  Future<LoggedInUser?>? _userFuture;
  @override
  void initState() {
    super.initState();
    _userFuture = _checkUserLoginStatus();
  }

  Future<LoggedInUser?> _checkUserLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final userJsonString = prefs.getString('loggedUser');

    if (userJsonString != null) {
      try {
        final userData = LoggedInUser.fromJson(jsonDecode(userJsonString));
        await Provider.of<BuyerDataProvider>(context, listen: false)
            .initializeData(userData.id, userData.id, userData.fullname);
        return userData;
      } catch (e) {
        debugPrint('🚨 AuthWrapper User Load/Init Error: $e');
        await prefs.remove('loggedUser');
        return null;
      }
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<LoggedInUser?>(
      future: _userFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasData && snapshot.data != null) {
          final user = snapshot.data!;
          if (user.role == "seller") {
            return const SellerScreen();
          } else {
            return const BuyerHomeScreen();
          }
        } else {
          return const LoginScreen();
        }
      },
    );
  }
}

// 💡 شاشة رسالة ما بعد التسجيل (لإظهار النجاح أو حالة الانتظار)
class PostRegistrationMessageScreen extends StatelessWidget {
  
  const PostRegistrationMessageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final isSeller = args?['isSeller'] ?? false;
    Future.delayed(const Duration(seconds: 3), () {
      Navigator.of(context).pushReplacementNamed(LoginScreen.routeName);
    });
  
    final String message;
    final IconData icon;
    final Color color;

    if (isSeller) {
      message = 'تم تسجيل حساب التاجر بنجاح.\nحسابك قيد المراجعة في انتظار النقل إلى التجار النشطين.';
      icon = Icons.pending_actions;
      color = Colors.orange;
    } else {
      message = 'تم تسجيل بياناتك بنجاح.\nسيتم نقلك الآن لتسجيل الدخول والمصادقة.';
      icon = Icons.check_circle_outline;
      color = Colors.green;
    }

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(30.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 80),
              const SizedBox(height: 20),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 40),
              const CircularProgressIndicator(),
            ],
          ),
        ),
      ),
    );
  }
}
