import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:sizer/sizer.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:latlong2/latlong.dart'; 

import 'package:my_test_app/firebase_options.dart';
import 'package:my_test_app/theme/app_theme.dart';
import 'package:my_test_app/providers/theme_notifier.dart';
import 'package:my_test_app/providers/buyer_data_provider.dart';
import 'package:my_test_app/providers/manufacturers_provider.dart';
import 'package:my_test_app/providers/cart_provider.dart';
import 'package:my_test_app/providers/customer_orders_provider.dart';
import 'package:my_test_app/providers/product_offer_provider.dart';
import 'package:my_test_app/providers/cashback_provider.dart';
import 'package:my_test_app/controllers/seller_dashboard_controller.dart';
import 'package:my_test_app/models/logged_user.dart';
import 'package:my_test_app/services/user_session.dart';
import 'package:my_test_app/models/user_role.dart';

// استيراد الشاشات
import 'package:my_test_app/screens/login_screen.dart';
import 'package:my_test_app/screens/seller_screen.dart';
import 'package:my_test_app/screens/buyer/buyer_home_screen.dart';
import 'package:my_test_app/screens/consumer/consumer_home_screen.dart';
import 'package:my_test_app/screens/auth/new_client_screen.dart';
import 'package:my_test_app/screens/buyer/cart_screen.dart';
import 'package:my_test_app/screens/checkout/checkout_screen.dart';
import 'package:my_test_app/screens/buyer/my_orders_screen.dart';
import 'package:my_test_app/screens/buyer/traders_screen.dart';
import 'package:my_test_app/screens/buyer/wallet_screen.dart';
import 'package:my_test_app/screens/buyer/buyer_category_screen.dart';
import 'package:my_test_app/screens/buyer/buyer_product_list_screen.dart';
import 'package:my_test_app/screens/buyer/trader_offers_screen.dart';
import 'package:my_test_app/screens/my_details_screen.dart';
import 'package:my_test_app/screens/about_screen.dart';
import 'package:my_test_app/screens/product_details_screen.dart';
import 'package:my_test_app/screens/consumer/consumer_sub_category_screen.dart';
import 'package:my_test_app/screens/consumer/ConsumerProductListScreen.dart';
import 'package:my_test_app/screens/consumer/consumer_store_search_screen.dart';
import 'package:my_test_app/screens/consumer/MarketplaceHomeScreen.dart';
import 'package:my_test_app/screens/consumer/consumer_purchase_history_screen.dart';
import 'package:my_test_app/screens/consumer/points_loyalty_screen.dart';
import 'package:my_test_app/screens/delivery_merchant_dashboard_screen.dart';
import 'package:my_test_app/screens/delivery_settings_screen.dart';
import 'package:my_test_app/screens/update_delivery_settings_screen.dart';
import 'package:my_test_app/screens/consumer_orders_screen.dart';
import 'package:my_test_app/screens/delivery/product_offer_screen.dart';
import 'package:my_test_app/screens/delivery/delivery_offers_screen.dart';
import 'package:my_test_app/screens/seller/add_offer_screen.dart';
import 'package:my_test_app/screens/seller/create_gift_promo_screen.dart';
import 'package:my_test_app/screens/delivery_area_screen.dart';
import 'package:my_test_app/screens/search/search_screen.dart';
import 'package:my_test_app/screens/special_requests/abaatly_had_pro_screen.dart';
import 'package:my_test_app/screens/customer_tracking_screen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ar', null);
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('notif_icon');
  const InitializationSettings initializationSettings = InitializationSettings(android: initializationSettingsAndroid);
  await flutterLocalNotificationsPlugin.initialize(initializationSettings);

  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'high_importance_channel',
    'إشعارات هامة',
    description: 'هذه القناة مخصصة لإشعارات الطلبات الهامة.',
    importance: Importance.max,
    playSound: true,
  );

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

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
          update: (_, buyerData, __) => CustomerOrdersProvider(buyerData),
        ),
        ChangeNotifierProxyProvider<BuyerDataProvider, ProductOfferProvider>(
          create: (context) => ProductOfferProvider(Provider.of<BuyerDataProvider>(context, listen: false)),
          update: (_, buyerData, __) => ProductOfferProvider(buyerData),
        ),
        ChangeNotifierProxyProvider<BuyerDataProvider, CashbackProvider>(
          create: (context) => CashbackProvider(Provider.of<BuyerDataProvider>(context, listen: false)),
          update: (_, buyerData, __) => CashbackProvider(buyerData),
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
    final themeNotifier = Provider.of<ThemeNotifier>(context);

    return Sizer(
      builder: (context, orientation, deviceType) {
        return MaterialApp(
          navigatorKey: navigatorKey,
          title: 'أسواق أكسب',
          debugShowCheckedModeBanner: false,
          locale: const Locale('ar', 'EG'),
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('ar', 'EG')],
          themeMode: themeNotifier.themeMode,
          theme: ThemeData(
            brightness: Brightness.light,
            primaryColor: AppTheme.primaryGreen,
            colorScheme: ColorScheme.light(primary: AppTheme.primaryGreen),
            textTheme: GoogleFonts.cairoTextTheme(ThemeData.light().textTheme),
          ),
          darkTheme: ThemeData(
            brightness: Brightness.dark,
            primaryColor: AppTheme.primaryGreen,
            colorScheme: ColorScheme.dark(primary: AppTheme.primaryGreen),
            textTheme: GoogleFonts.cairoTextTheme(ThemeData.dark().textTheme),
          ),
          initialRoute: '/',
          routes: {
            '/': (context) => const AuthWrapper(),
            '/sellerhome': (context) => const SellerScreen(),
            LoginScreen.routeName: (context) => const LoginScreen(),
            SellerScreen.routeName: (context) => const SellerScreen(),
            BuyerHomeScreen.routeName: (context) => const BuyerHomeScreen(),
            ConsumerHomeScreen.routeName: (context) => const ConsumerHomeScreen(),
            CartScreen.routeName: (context) => const CartScreen(),
            CheckoutScreen.routeName: (context) => const CheckoutScreen(),
            MyOrdersScreen.routeName: (context) => const MyOrdersScreen(),
            SearchScreen.routeName: (context) => SearchScreen(
              userRole: Provider.of<BuyerDataProvider>(context, listen: false).userRole == 'consumer' 
                  ? UserRole.consumer 
                  : UserRole.buyer
            ),
            '/register': (context) => const NewClientScreen(),
            '/traders': (context) => const TradersScreen(),
            '/wallet': (context) => const WalletScreen(),
            '/myDetails': (context) => const MyDetailsScreen(),
            '/about': (context) => const AboutScreen(),
            '/post-reg': (context) => const PostRegistrationMessageScreen(),
            ConsumerStoreSearchScreen.routeName: (context) => const ConsumerStoreSearchScreen(),
            '/consumer-purchases': (context) => const ConsumerPurchaseHistoryScreen(),
            PointsLoyaltyScreen.routeName: (context) => const PointsLoyaltyScreen(),
            '/deliverySettings': (context) => const DeliverySettingsScreen(),
            '/deliveryPrices': (context) => const DeliveryMerchantDashboardScreen(),
            '/deliveryMerchantDashboard': (context) => const DeliveryMerchantDashboardScreen(),
            '/product_management': (context) => const ProductOfferScreen(),
            '/delivery-offers': (context) => const DeliveryOffersScreen(),
            '/updatsupermarket': (context) => const UpdateDeliverySettingsScreen(),
            '/con-orders': (context) => const ConsumerOrdersScreen(),
            '/constore': (context) => const BuyerHomeScreen(),
            '/add-offer': (context) => const AddOfferScreen(),
            '/create-gift': (context) => const CreateGiftPromoScreen(currentSellerId: ''),
            '/delivery-areas': (context) => const DeliveryAreaScreen(currentSellerId: ''),
            '/abaatly-had': (context) {
              final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
              return AbaatlyHadProScreen(
                userCurrentLocation: args?['location'] ?? const LatLng(30.0444, 31.2357),
                isStoreOwner: args?['isStoreOwner'] ?? false,
              );
            },
            '/customerTracking': (context) {
              final orderId = ModalRoute.of(context)?.settings.arguments as String? ?? '';
              return CustomerTrackingScreen(orderId: orderId);
            },
          },
          onGenerateRoute: _onGenerateRoute,
        );
      },
    );
  }

  Route? _onGenerateRoute(RouteSettings settings) {
    if (settings.name == MarketplaceHomeScreen.routeName) {
      final args = settings.arguments as Map<String, dynamic>?;
      return MaterialPageRoute(builder: (context) => MarketplaceHomeScreen(currentStoreId: args?['storeId'] ?? '', currentStoreName: args?['storeName'] ?? 'المتجر'));
    }
    if (settings.name == '/subcategories') {
      final args = settings.arguments as Map<String, dynamic>?;
      return MaterialPageRoute(builder: (context) => ConsumerSubCategoryScreen(mainCategoryId: args?['mainId'] ?? '', ownerId: args?['ownerId'] ?? '', mainCategoryName: args?['mainCategoryName'] ?? ''));
    }
    if (settings.name == ConsumerProductListScreen.routeName) {
      final args = settings.arguments as Map<String, dynamic>?;
      return MaterialPageRoute(builder: (context) => ConsumerProductListScreen(ownerId: args?['ownerId'] ?? '', mainId: args?['mainId'] ?? '', subId: args?['subId'] ?? '', subCategoryName: args?['subCategoryName'] ?? 'المنتجات'));
    }
    if (settings.name == '/productDetails') {
      final args = settings.arguments as Map<String, dynamic>?;
      return MaterialPageRoute(builder: (context) => ProductDetailsScreen(productId: args?['productId'] ?? '', offerId: args?['offerId']));
    }
    if (settings.name == TraderOffersScreen.routeName) {
      final sellerId = settings.arguments as String? ?? '';
      return MaterialPageRoute(builder: (context) => TraderOffersScreen(sellerId: sellerId));
    }
    if (settings.name == '/category') {
      final mainId = settings.arguments as String? ?? '';
      return MaterialPageRoute(builder: (context) => BuyerCategoryScreen(mainCategoryId: mainId));
    }
    if (settings.name == '/products') {
      final args = settings.arguments as Map<String, dynamic>? ?? {};
      return MaterialPageRoute(builder: (context) => BuyerProductListScreen(mainCategoryId: args['mainId'] ?? '', subCategoryId: args['subId'] ?? ''));
    }
    return null;
  }
}

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
    final userJson = prefs.getString('loggedUser');
    if (userJson != null) {
      try {
        await UserSession.loadSession();
        final user = LoggedInUser.fromJson(jsonDecode(userJson));
        // 🚀 التأمين العام: انتظر تحميل البيانات بالكامل قبل الدخول
        final buyerProvider = Provider.of<BuyerDataProvider>(context, listen: false);
        await buyerProvider.initializeData(user.id, user.id, user.fullname);
        return user;
      } catch (e) {
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
          return const Scaffold(body: Center(child: CircularProgressIndicator(color: Color(0xFF43A047))));
        }
        if (snapshot.hasData && snapshot.data != null) {
          final user = snapshot.data!;
          if (user.role == "seller") return const SellerScreen();
          if (user.role == "consumer") return const ConsumerHomeScreen();
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
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(isSeller ? Icons.pending_actions : Icons.check_circle, color: isSeller ? Colors.orange : Colors.green, size: 80),
            const SizedBox(height: 20),
            Text(isSeller ? 'حسابك قيد المراجعة' : 'تم التسجيل بنجاح', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 40),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
