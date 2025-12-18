import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:sizer/sizer.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:google_fonts/google_fonts.dart';

// Imports - Firebase & Theme
import 'package:my_test_app/firebase_options.dart';
import 'package:my_test_app/theme/app_theme.dart';
import 'package:my_test_app/providers/theme_notifier.dart';

// Providers
import 'package:my_test_app/providers/buyer_data_provider.dart';
import 'package:my_test_app/providers/manufacturers_provider.dart';
import 'package:my_test_app/providers/cart_provider.dart';
import 'package:my_test_app/providers/customer_orders_provider.dart';
import 'package:my_test_app/providers/product_offer_provider.dart';
import 'package:my_test_app/providers/cashback_provider.dart';
import 'package:my_test_app/controllers/seller_dashboard_controller.dart';

// Screens
import 'package:my_test_app/screens/login_screen.dart';
import 'package:my_test_app/screens/seller_screen.dart';
import 'package:my_test_app/screens/buyer/buyer_home_screen.dart';
import 'package:my_test_app/screens/consumer/consumer_home_screen.dart';
import 'package:my_test_app/screens/auth/new_client_screen.dart';
import 'package:my_test_app/screens/buyer/cart_screen.dart';
import 'package:my_test_app/screens/checkout/checkout_screen.dart';
import 'package:my_test_app/screens/buyer/my_orders_screen.dart';
import 'package:my_test_app/models/logged_user.dart';
import 'package:my_test_app/models/user_role.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // تهيئة اللغة العربية للتواريخ
  await initializeDateFormatting('ar', null);

  // تهيئة فايربيس للموبايل
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

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
    return Sizer(
      builder: (context, orientation, deviceType) {
        return MaterialApp(
          title: 'My Test App',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            primaryColor: AppTheme.primaryGreen,
            colorScheme: ColorScheme.light(primary: AppTheme.primaryGreen),
            textTheme: GoogleFonts.notoSansArabicTextTheme(),
          ),
          initialRoute: '/',
          routes: {
            '/': (context) => const AuthWrapper(),
            LoginScreen.routeName: (context) => const LoginScreen(),
            SellerScreen.routeName: (context) => const SellerScreen(),
            BuyerHomeScreen.routeName: (context) => const BuyerHomeScreen(),
            ConsumerHomeScreen.routeName: (context) => ConsumerHomeScreen(),
            CartScreen.routeName: (context) => const CartScreen(),
            CheckoutScreen.routeName: (context) => const CheckoutScreen(),
            MyOrdersScreen.routeName: (context) => const MyOrdersScreen(),
            '/register': (context) => const NewClientScreen(),
          },
        );
      },
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});
  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<LoggedInUser?>(
      future: _checkUserLoginStatus(),
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

  Future<LoggedInUser?> _checkUserLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString('loggedUser');
    if (userJson != null) {
      final userData = LoggedInUser.fromJson(jsonDecode(userJson));
      await Provider.of<BuyerDataProvider>(context, listen: false)
          .initializeData(userData.id, userData.id, userData.fullname);
      return userData;
    }
    return null;
  }
}
