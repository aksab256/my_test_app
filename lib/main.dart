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
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:facebook_app_events/facebook_app_events.dart'; // ✅ تتبع فيسبوك

// ✅ استخدام مكتبة جوجل مابس فقط لمنع التعارض مع latlong2
import 'package:google_maps_flutter/google_maps_flutter.dart' as google_maps;

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
import 'package:my_test_app/screens/consumer/consumer_general_sub_category_screen.dart';

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
import 'package:my_test_app/services/bubble_service.dart';
import 'package:my_test_app/screens/search/search_screen.dart';
import 'package:my_test_app/screens/special_requests/abaatly_had_pro_screen.dart';
import 'package:my_test_app/screens/customer_tracking_screen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// ✅ نسخة موحّدة من البلجن يقدر أي كود في الملف يوصلها (مش بس داخل main)
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

/// ✅ معالج الإشعارات في الخلفية (لازم تكون top-level function ومعلمة بـ pragma عشان تعمل صح)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // مفيش داعي لأي تنقل هنا - النظام بيتكفل بعرض الإشعار في الخلفية تلقائيًا
  // التوجيه الفعلي بيحصل في onMessageOpenedApp أو getInitialMessage لما المستخدم يضغط عليه
  debugPrint("📩 Background message received: ${message.messageId}");
}

/// ✅ دالة موحّدة للتوجيه بناءً على بيانات الإشعار (data payload)
/// بتستخدم navigatorKey فتقدر توجّه من غير ما تحتاج BuildContext
void _handleNotificationNavigation(Map<String, dynamic> data) {
  final route = data['route'] as String?;
  final orderId = data['orderId'] as String?;

  if (route == null) return;

  // تأخير خفيف يضمن إن الـ Navigator اتبنى فعليًا قبل أي تنقل (مهم خصوصًا لحالة cold start)
  WidgetsBinding.instance.addPostFrameCallback((_) {
    switch (route) {
      case '/customerTracking':
        navigatorKey.currentState?.pushNamed('/customerTracking', arguments: orderId ?? '');
        break;
      case '/con-orders':
        navigatorKey.currentState?.pushNamed('/con-orders');
        break;
      case '/deliveryMerchantDashboard':
        navigatorKey.currentState?.pushNamed('/deliveryMerchantDashboard');
        break;
      default:
        // أي route تاني معروف ومسجل في routes/onGenerateRoute
        navigatorKey.currentState?.pushNamed(route);
    }
  });
}

/// ✅ تهيئة شاملة للإشعارات: صلاحيات + إشعارات محلية + كل حالات FCM (مفتوح/خلفية/مغلق)
Future<void> _setupNotifications() async {
  // 1) طلب صلاحية الإشعارات (مهم جدًا لـ iOS، ومطلوب في أندرويد 13+)
  await FirebaseMessaging.instance.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );

  // 2) تهيئة الإشعارات المحلية (اللي بتظهر فعليًا وقت التطبيق مفتوح)
  const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('notif_icon');
  const InitializationSettings initializationSettings = InitializationSettings(android: initializationSettingsAndroid);

  await flutterLocalNotificationsPlugin.initialize(
    settings: initializationSettings, // ✅ الاسم الصحيح حسب النسخة المثبتة فعليًا في المشروع
    onDidReceiveNotificationResponse: (NotificationResponse response) {
      // الضغط على إشعار محلي ظاهر - بنقرا الـ payload المحفوظ فيه ونوجه بناءً عليه
      final payload = response.payload;
      if (payload != null && payload.isNotEmpty) {
        try {
          final data = jsonDecode(payload) as Map<String, dynamic>;
          _handleNotificationNavigation(data);
        } catch (e) {
          debugPrint("⚠️ Failed to parse notification payload: $e");
        }
      }
    },
  );

  final AndroidNotificationChannel channel = AndroidNotificationChannel(
    'high_importance_channel',
    'إشعارات هامة',
    description: 'هذه القناة مخصصة لإشعارات الطلبات الهامة.',
    importance: Importance.max,
    playSound: true,
  );

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  // 3) تسجيل معالج الخلفية (لازم يتسجل في main() قبل runApp، لكن الدالة نفسها top-level فوق)
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // 4) الحالة الأولى: التطبيق مفتوح فعليًا (foreground) - لازم نعرض إشعار محلي بنفسنا يدويًا
  //    لأن FCM مبيعرضش إشعار تلقائي والتطبيق شغال في المقدمة
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    final notification = message.notification;
    if (notification != null) {
      flutterLocalNotificationsPlugin.show(
        id: notification.hashCode,
        title: notification.title,
        body: notification.body,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'high_importance_channel',
            'إشعارات هامة',
            importance: Importance.max,
            priority: Priority.high,
          ),
        ),
        payload: jsonEncode(message.data), // بنحفظ بيانات التوجيه جوه الإشعار المحلي المعروض
      );
    }
  });

  // 5) الحالة الثانية: التطبيق كان في الخلفية والمستخدم ضغط على الإشعار ففتح التطبيق
  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    _handleNotificationNavigation(message.data);
  });

  // 6) الحالة الثالثة: التطبيق كان مقفول تمامًا (cold start) وفتح بالضغط على إشعار
  final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
  if (initialMessage != null) {
    _handleNotificationNavigation(initialMessage.data);
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ar', null);
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // ✅ تهيئة فيسبوك
  final facebookAppEvents = FacebookAppEvents();
  facebookAppEvents.setAutoLogAppEventsEnabled(true);

  // ✅ الإشعارات بكل حالاتها (صلاحيات + محلي + FCM في كل الحالات الثلاث)
  await _setupNotifications();

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

  // ✅ دالة التحديث الإجباري
  void _checkUpdate(BuildContext context) async {
    try {
      DocumentSnapshot config = await FirebaseFirestore.instance.collection('app_config').doc('version_control').get();
      if (config.exists) {
        int latestVersion = config['min_version'];
        int currentVersion = 19; // رقم الإصدار الحالي لتطبيقك
        if (currentVersion < latestVersion) {
          _showUpdateDialog(context, config['update_url']);
        }
      }
    } catch (e) {
      debugPrint("Update check failed: $e");
    }
  }

  void _showUpdateDialog(BuildContext context, String url) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text("تحديث إجباري"),
        content: const Text("يتوفر إصدار جديد من تطبيق أكسب يحتوي على تحسينات هامة. يرجى التحديث للمتابعة."),
        actions: [
          TextButton(
            onPressed: () async => await launchUrl(Uri.parse(url)),
            child: const Text("تحديث الآن"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // ⚠️ ملاحظة: themeNotifier متسجل هنا فقط لأي كود تاني في الشجرة بيسمعه
    // (زي زرار تبديل الوضع في شاشة الإعدادات لو موجود). قيمته بقت متجاهلة
    // تمامًا في MaterialApp تحت (انظر themeMode) بناءً على طلبك بتعطيل
    // الوضع الليلي بالكامل.
    Provider.of<ThemeNotifier>(context);

    // فحص التحديث عند بناء التطبيق
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkUpdate(context));

    return Sizer(
      builder: (context, orientation, deviceType) {
        return MaterialApp(
          navigatorKey: navigatorKey,
          title: 'أكسب',
          debugShowCheckedModeBanner: false,
          locale: const Locale('ar', 'EG'),
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('ar', 'EG')],
          // ✅ إصلاح: تعطيل الوضع الليلي بالكامل بناءً على طلبك
          // (النصوص كانت بتبقى باهتة وصعبة القراءة في وضع توفير الطاقة).
          // themeMode بقى مثبّت على Light دايمًا - بيتجاهل قيمة themeNotifier
          // تمامًا وكمان بيتجاهل إعدادات الوضع الليلي في نظام الجهاز نفسه.
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
            inputDecorationTheme: const InputDecorationTheme(
              labelStyle: TextStyle(color: Colors.black87, fontWeight: FontWeight.w500),
              hintStyle: TextStyle(color: Colors.black45),
              floatingLabelStyle: TextStyle(color: AppTheme.primaryGreen, fontWeight: FontWeight.bold),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: AppTheme.primaryGreen, width: 2),
              ),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.black38, width: 1),
              ),
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
          // ⚠️ ملاحظة: سيبت darkTheme موجودة في الكود (مش محذوفة) لأنها غير
          // مؤثرة أصلاً بعد تثبيت themeMode على Light فوق - مفيش خطر إنها
          // تتفعل. لو عايز تشيلها فعليًا من الكود (مش ضروري)، قولّي.
          darkTheme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.dark,
            primaryColor: AppTheme.primaryGreen,
            scaffoldBackgroundColor: const Color(0xFF121212),
            cardColor: const Color(0xFF1E1E1E),
            colorScheme: ColorScheme.fromSeed(
              seedColor: AppTheme.primaryGreen,
              brightness: Brightness.dark,
            ).copyWith(
              surface: const Color(0xFF1E1E1E),
              onSurface: Colors.white.withOpacity(0.92),
              onSurfaceVariant: Colors.white.withOpacity(0.75),
            ),
            textTheme: GoogleFonts.cairoTextTheme(ThemeData.dark().textTheme).apply(
              bodyColor: Colors.white.withOpacity(0.92),
              displayColor: Colors.white.withOpacity(0.95),
            ),
            inputDecorationTheme: InputDecorationTheme(
              labelStyle: TextStyle(color: Colors.white.withOpacity(0.85), fontWeight: FontWeight.w500),
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
              floatingLabelStyle: const TextStyle(color: AppTheme.primaryGreen, fontWeight: FontWeight.bold),
              focusedBorder: const OutlineInputBorder(
                borderSide: BorderSide(color: AppTheme.primaryGreen, width: 2),
              ),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.white.withOpacity(0.4), width: 1),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
          initialRoute: '/',
          routes: {
            '/': (context) => const AuthWrapper(),
            '/sellerhome': (context) => const SellerScreen(),
            LoginScreen.routeName: (context) => const LoginScreen(),
            SellerScreen.routeName: (context) => const SellerScreen(),
            BuyerHomeScreen.routeName: (context) => const BuyerHomeScreen(),
            ConsumerHomeScreen.routeName: (context) => ConsumerHomeScreen(),
            CartScreen.routeName: (context) => const CartScreen(),
            CheckoutScreen.routeName: (context) => const CheckoutScreen(),
            MyOrdersScreen.routeName: (context) => const MyOrdersScreen(),
            SearchScreen.routeName: (context) => SearchScreen(
                userRole: Provider.of<BuyerDataProvider>(context, listen: false).userRole == 'consumer'
                    ? UserRole.consumer
                    : UserRole.buyer),
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
              final rawLocation = args?['location'];
              google_maps.LatLng finalLocation;
              if (rawLocation is google_maps.LatLng) {
                finalLocation = rawLocation;
              } else {
                finalLocation = const google_maps.LatLng(30.0444, 31.2357);
              }
              return AbaatlyHadProScreen(
                userCurrentLocation: finalLocation,
                isStoreOwner: args?['isStoreOwner'] ?? false,
              );
            },
            '/customerTracking': (context) {
              final orderId = ModalRoute.of(context)?.settings.arguments as String? ?? '';
              return CustomerTrackingScreen(orderId: orderId);
            },
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
              return MaterialPageRoute(
                builder: (context) => BuyerProductListScreen(
                  mainCategoryId: args['mainId'] ?? '',
                  subCategoryId: args['subId'] ?? '',
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndShowActiveOrderBubble();
    });
  }

  void _checkAndShowActiveOrderBubble() async {
    final prefs = await SharedPreferences.getInstance();
    final activeOrderId = prefs.getString('active_special_order_id');
    if (activeOrderId != null) {
      BubbleService.show(activeOrderId);
    }
  }

  Future<LoggedInUser?> _checkUserLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString('loggedUser');
    if (userJson != null) {
      try {
        await UserSession.loadSession();
        final user = LoggedInUser.fromJson(jsonDecode(userJson));
        await Provider.of<BuyerDataProvider>(context, listen: false)
            .initializeData(user.id, user.id, user.fullname);
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
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(isSeller ? Icons.pending_actions : Icons.check_circle,
                color: isSeller ? Colors.orange : Colors.green, size: 80),
            const SizedBox(height: 20),
            Text(isSeller ? 'حسابك قيد المراجعة' : 'تم التسجيل بنجاح',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 40),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}