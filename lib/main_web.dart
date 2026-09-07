import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:sizer/sizer.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'package:my_test_app/firebase_options.dart';
import 'package:my_test_app/theme/app_theme.dart';
import 'package:my_test_app/providers/buyer_data_provider.dart';
import 'package:my_test_app/providers/cart_provider.dart';

// استيراد شاشات المستهلك والسلّة والـ Checkout فقط
import 'package:my_test_app/screens/consumer/MarketplaceHomeScreen.dart';
import 'package:my_test_app/screens/consumer/web/web_consumer_home_screen.dart';
import 'package:my_test_app/screens/consumer/consumer_sub_category_screen.dart';
import 'package:my_test_app/screens/consumer/consumer_general_sub_category_screen.dart';
import 'package:my_test_app/screens/consumer/ConsumerProductListScreen.dart';
import 'package:my_test_app/screens/buyer/cart_screen.dart';
import 'package:my_test_app/screens/checkout/checkout_screen.dart';
import 'package:my_test_app/screens/product_details_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ar', null);
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => BuyerDataProvider()),
        ChangeNotifierProvider(create: (_) => CartProvider()),
      ],
      child: const AksabWebMarketApp(),
    ),
  );
}

class AksabWebMarketApp extends StatelessWidget {
  const AksabWebMarketApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Sizer(
      builder: (context, orientation, deviceType) {
        return MaterialApp(
          title: 'أسواق أكسب - متجر الملابس والأزياء',
          debugShowCheckedModeBanner: false,
          locale: const Locale('ar', 'EG'),
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('ar', 'EG')],
          themeMode: ThemeMode.light,
          theme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.light,
            primaryColor: AppTheme.primaryGreen,
            colorScheme: ColorScheme.fromSeed(
              seedColor: AppTheme.primaryGreen,
              brightness: Brightness.light,
            ),
            textTheme: GoogleFonts.cairoTextTheme(ThemeData.light().textTheme).apply(
              bodyColor: Colors.black87,
              displayColor: Colors.black87,
            ),
          ),
          // الدخول المباشر لشاشة الماركت/المستهلك بدون شاشة تسجيل الدخول
          initialRoute: '/',
          routes: {
            '/': (context) => const WebConsumerHomeScreen(),
            CartScreen.routeName: (context) => const CartScreen(),
            CheckoutScreen.routeName: (context) => const CheckoutScreen(),
          },
          onGenerateRoute: (settings) {
            if (settings.name == MarketplaceHomeScreen.routeName) {
              final args = settings.arguments as Map<String, dynamic>?;
              return MaterialPageRoute(
                builder: (context) => MarketplaceHomeScreen(
                  currentStoreId: args?['storeId'] ?? '',
                  currentStoreName: args?['storeName'] ?? 'المتجر',
                ),
              );
            }
            if (settings.name == '/subcategories') {
              final args = settings.arguments as Map<String, dynamic>?;
              return MaterialPageRoute(
                builder: (context) => ConsumerSubCategoryScreen(
                  mainCategoryId: args?['mainId'] ?? '',
                  ownerId: args?['ownerId'] ?? '',
                  mainCategoryName: args?['mainCategoryName'] ?? '',
                ),
              );
            }
            if (settings.name == '/genralsubcategories') {
              final args = settings.arguments as Map<String, dynamic>?;
              return MaterialPageRoute(
                builder: (context) => ConsumerGeneralSubCategoryScreen(
                  mainCategoryId: args?['mainId'] ?? '',
                  mainCategoryName: args?['mainCategoryName'] ?? '',
                ),
              );
            }
            if (settings.name == ConsumerProductListScreen.routeName) {
              return MaterialPageRoute(
                settings: settings,
                builder: (context) => const ConsumerProductListScreen(),
              );
            }
            if (settings.name == '/productDetails') {
              final args = settings.arguments as Map<String, dynamic>?;
              return MaterialPageRoute(
                builder: (context) => ProductDetailsScreen(
                  productId: args?['productId'] ?? '',
                  offerId: args?['offerId'],
                ),
              );
            }
            return null;
          },
        );
      },
    );
  }
}