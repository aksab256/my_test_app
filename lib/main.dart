// lib/main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:my_test_app/firebase_options.dart';
import 'package:sizer/sizer.dart';
import 'package:intl/date_symbol_data_local.dart';

// استيراد الشاشات
import 'package:my_test_app/screens/buyer/my_orders_screen.dart';
import 'package:my_test_app/screens/login_screen.dart';
import 'package:my_test_app/screens/auth/new_client_screen.dart';
import 'package:my_test_app/screens/buyer/buyer_home_screen.dart';
import 'package:my_test_app/screens/seller_screen.dart';
import 'package:my_test_app/screens/consumer/consumer_home_screen.dart';
import 'package:my_test_app/screens/consumer/consumer_store_search_screen.dart';
import 'package:my_test_app/screens/buyer/buyer_category_screen.dart';
import 'package:my_test_app/screens/buyer/buyer_product_list_screen.dart';
import 'package:my_test_app/screens/buyer/cart_screen.dart';
import 'package:my_test_app/screens/my_details_screen.dart';
import 'package:my_test_app/screens/about_screen.dart';
import 'package:my_test_app/screens/checkout/checkout_screen.dart';
import 'package:my_test_app/screens/delivery_settings_screen.dart';
import 'package:my_test_app/screens/update_delivery_settings_screen.dart';
import 'package:my_test_app/screens/delivery_merchant_dashboard_screen.dart';
import 'package:my_test_app/screens/consumer_orders_screen.dart';
import 'package:my_test_app/screens/buyer/traders_screen.dart';
import 'package:my_test_app/screens/buyer/trader_offers_screen.dart';
import 'package:my_test_app/screens/product_details_screen.dart';
import 'package:my_test_app/screens/consumer/consumer_sub_category_screen.dart';
import 'package:my_test_app/screens/consumer/ConsumerProductListScreen.dart';
import 'package:my_test_app/screens/consumer/MarketplaceHomeScreen.dart';
import 'package:my_test_app/screens/consumer/points_loyalty_screen.dart';
import 'package:my_test_app/screens/consumer/consumer_purchase_history_screen.dart';

// استيراد المزودات والثيم
import 'package:my_test_app/theme/app_theme.dart';
import 'package:my_test_app/providers/theme_notifier.dart';
import 'package:my_test_app/providers/buyer_data_provider.dart';
import 'package:my_test_app/providers/manufacturers_provider.dart';
import 'package:my_test_app/providers/cart_provider.dart';
import 'package:my_test_app/models/logged_user.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:my_test_app/controllers/seller_dashboard_controller.dart';
import 'package:my_test_app/screens/delivery/product_offer_screen.dart';
import 'package:my_test_app/providers/product_offer_provider.dart';
import 'package:my_test_app/providers/customer_orders_provider.dart';
import 'package:my_test_app/screens/delivery/delivery_offers_screen.dart';
import 'package:my_test_app/screens/buyer/wallet_screen.dart';
import 'package:my_test_app/providers/cashback_provider.dart';
import 'package:my_test_app/screens/search/search_screen.dart';
import 'package:my_test_app/models/user_role.dart';

void main() async {
  // 1. ضمان استقرار المحرك قبل أي عملية
  WidgetsFlutterBinding.ensureInitialized();

  // 2. معالجة أخطاء فلاتر العالمية
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('🚨 FATAL ERROR: ${details.exception}');
  };

  try {
    // 3. تهيئة اللغات والفايربيس بترتيب صحيح
    await initializeDateFormatting('ar', null);
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } catch (e) {
    debugPrint('🚨 INIT ERROR: $e');
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeNotifier(ThemeMode.system)),
        ChangeNotifierProvider(create: (_) => BuyerDataProvider()),
        ChangeNotifierProvider(create: (_) => ManufacturersProvider()),
        ChangeNotifierProvider(create: (_) => CartProvider()),
        ChangeNotifierProvider(create: (_) => SellerDashboardController()),
        ChangeNotifierProxyProvider<BuyerDataProvider, CustomerOrdersProvider>(
          create: (context) => CustomerOrdersProvider(Provider.of<BuyerDataProvider>(context, listen: false)),
          update: (context, buyerData, previous) => CustomerOrdersProvider(buyerData),
        ),
        ChangeNotifierProxyProvider<BuyerDataProvider, ProductOfferProvider>(
          create: (context) => ProductOfferProvider(Provider.of<BuyerDataProvider>(context, listen: false)),
          update: (context, buyerData, previous) => ProductOfferProvider(buyerData),
        ),
        ChangeNotifierProxyProvider<BuyerDataProvider, CashbackProvider>(
          create: (context) => CashbackProvider(Provider.of<BuyerDataProvider>(context, listen: false)),
          update: (context, buyerData, previous) => CashbackProvider(buyerData),
        ),
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
          title: 'Delivery Supermarkets',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            primaryColor: AppTheme.primaryGreen,
            colorScheme: ColorScheme.light(primary: AppTheme.primaryGreen, secondary: AppTheme.accentBlueLight),
            scaffoldBackgroundColor: AppTheme.scaffoldLight,
            cardColor: Colors.white,
            textTheme: GoogleFonts.notoSansArabicTextTheme(const TextTheme(bodyLarge: TextStyle(color: Color(0xff343a40)))),
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
            textTheme: GoogleFonts.notoSansArabicTextTheme(const TextTheme(bodyLarge: TextStyle(color: Color(0xffe0e0e0)))),
          ),
          builder: (context, child) {
            return Directionality(textDirection: TextDirection.rtl, child: child!);
          },
          initialRoute: '/',
          routes: {
            '/': (context) => const AuthWrapper(),
            LoginScreen.routeName: (context) => const LoginScreen(),
            BuyerHomeScreen.routeName: (context) => const BuyerHomeScreen(),
            ConsumerHomeScreen.routeName: (context) => ConsumerHomeScreen(),
            ConsumerStoreSearchScreen.routeName: (context) => const ConsumerStoreSearchScreen(),
            SellerScreen.routeName: (context) => const SellerScreen(),
            CartScreen.routeName: (context) => const CartScreen(),
            CheckoutScreen.routeName: (context) => const CheckoutScreen(),
            MyOrdersScreen.routeName: (context) => const MyOrdersScreen(),
            '/con-orders': (context) => const ConsumerOrdersScreen(),
            ConsumerPurchaseHistoryScreen.routeName: (context) => const ConsumerPurchaseHistoryScreen(),
            '/deliverySettings': (context) => const DeliverySettingsScreen(),
            '/updatsupermarket': (context) => const UpdateDeliverySettingsScreen(),
            '/deliveryPrices': (context) => const DeliveryMerchantDashboardScreen(),
            DeliveryOffersScreen.routeName: (context) => const DeliveryOffersScreen(),
            '/myDetails': (context) => const MyDetailsScreen(),
            '/about': (context) => const AboutScreen(),
            TradersScreen.routeName: (context) => const TradersScreen(),
            '/register': (context) => const NewClientScreen(),
            '/post_registration_message': (context) => const PostRegistrationMessageScreen(),
            '/wallet': (context) => const WalletScreen(),
            PointsLoyaltyScreen.routeName: (context) => const PointsLoyaltyScreen(),
            SearchScreen.routeName: (context) {
              final buyerData = Provider.of<BuyerDataProvider>(context, listen: false);
              final role = buyerData.userClassification == 'seller' ? UserRole.buyer : UserRole.consumer;
              return SearchScreen(userRole: role);
            },
          },
          onGenerateRoute: (settings) {
            // منطق المسارات الديناميكية (بدون تغيير)
            if (settings.name == '/productDetails') {
              String? productId;
              String? offerId;
              if (settings.arguments is String) {
                productId = settings.arguments as String;
              } else if (settings.arguments is Map<String, dynamic>) {
                final args = settings.arguments as Map<String, dynamic>;
                productId = args['productId'] as String?;
                offerId = args['offerId'] as String?;
              }
              if (productId != null && productId.isNotEmpty) {
                return MaterialPageRoute(builder: (context) => ProductDetailsScreen(productId: productId!, offerId: offerId));
              }
            }
            if (settings.name == MarketplaceHomeScreen.routeName) {
              final args = settings.arguments as Map<String, dynamic>?;
              final storeId = args?['storeId'] as String?;
              final storeName = args?['storeName'] as String?;
              if (storeId != null && storeName != null) {
                return MaterialPageRoute(builder: (context) => MarketplaceHomeScreen(currentStoreId: storeId, currentStoreName: storeName));
              }
            }
            if (settings.name == '/subcategories') {
              final args = settings.arguments as Map<String, dynamic>?;
              final mainCategoryId = args?['mainId'] as String?;
              final ownerId = args?['ownerId'] as String?;
              final mainCategoryName = args?['mainCategoryName'] as String?;
              if (mainCategoryId != null && ownerId != null) {
                return MaterialPageRoute(builder: (context) => ConsumerSubCategoryScreen(mainCategoryId: mainCategoryId, ownerId: ownerId, mainCategoryName: mainCategoryName ?? 'الأقسام الفرعية'));
              }
            }
            if (settings.name == ConsumerProductListScreen.routeName) {
              final args = settings.arguments as Map<String, dynamic>?;
              final ownerId = args?['ownerId'] as String?;
              final mainId = args?['mainId'] as String?;
              final subId = args?['subId'] as String?;
              final subCategoryName = args?['subCategoryName'] as String?;
              if (ownerId != null && mainId != null && subId != null) {
                return MaterialPageRoute(builder: (context) => ConsumerProductListScreen(ownerId: ownerId, mainId: mainId, subId: subId, subCategoryName: subCategoryName ?? 'المنتجات'));
              }
            }
            if (settings.name == TraderOffersScreen.routeName) {
              final sellerId = settings.arguments as String? ?? '';
              return MaterialPageRoute(builder: (context) => TraderOffersScreen(sellerId: sellerId));
            }
            if (settings.name == '/products') {
              final args = settings.arguments as Map<String, String>? ?? {};
              return MaterialPageRoute(builder: (context) => BuyerProductListScreen(mainCategoryId: args['mainId'] ?? '', subCategoryId: args['subId'] ?? ''));
            }
            if (settings.name == '/category') {
              final mainCategoryId = settings.arguments as String? ?? 'default_id';
              return MaterialPageRoute(builder: (context) => BuyerCategoryScreen(mainCategoryId: mainCategoryId));
            }
            return null;
          },
        );
      },
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  Future<LoggedInUser?> _checkUserLoginStatus(BuildContext context) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userJsonString = prefs.getString('loggedUser');
      if (userJsonString != null) {
        final userData = LoggedInUser.fromJson(jsonDecode(userJsonString));
        // تهيئة البيانات من خلال البروفايدر بشكل آمن
        final buyerProvider = Provider.of<BuyerDataProvider>(context, listen: false);
        await buyerProvider.initializeData(userData.id, userData.id, userData.fullname);
        return userData;
      }
    } catch (e) {
      debugPrint('🚨 Auth Error: $e');
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<LoggedInUser?>(
      future: _checkUserLoginStatus(context),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasData && snapshot.data != null) {
          final user = snapshot.data!;
          if (user.role == "seller") return const SellerScreen();
          if (user.role == "consumer") return ConsumerHomeScreen();
          return const BuyerHomeScreen();
        }
        return const LoginScreen();
      },
    );
  }
}

class PostRegistrationMessageScreen extends StatelessWidget {
  const PostRegistrationMessageScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final isSeller = args?['isSeller'] ?? false;
    Future.delayed(const Duration(seconds: 3), () {
      Navigator.of(context).pushReplacementNamed(LoginScreen.routeName);
    });
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(30.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(isSeller ? Icons.pending_actions : Icons.check_circle_outline, 
                   color: isSeller ? Colors.orange : Colors.green, size: 80),
              const SizedBox(height: 20),
              Text(isSeller ? 'تم تسجيل حساب التاجر بنجاح.\nحسابك قيد المراجعة.' : 'تم تسجيل بياناتك بنجاح.',
                   textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              const SizedBox(height: 40),
              const CircularProgressIndicator(),
            ],
          ),
        ),
      ),
    );
  }
}
