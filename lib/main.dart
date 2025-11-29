// lib/main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:my_test_app/firebase_options.dart';
import 'package:sizer/sizer.dart'; // ⭐️⭐️ الإضافة 1: استيراد مكتبة Sizer ⭐️⭐️

// 💡 استيراد شاشات التوجيه 💡
import 'package:my_test_app/screens/login_screen.dart'; // ✅ تم تعديل المسار ليكون داخل screens مباشرة
import 'package:my_test_app/screens/auth/new_client_screen.dart'; // 🆕 شاشة التسجيل (باقية في auth)
import 'package:my_test_app/screens/buyer/buyer_home_screen.dart'; // مسار المشتري الرئيسي
import 'package:my_test_app/screens/seller_screen.dart'; // شاشة البائع
import 'package:my_test_app/screens/buyer/buyer_category_screen.dart'; // شاشة الأقسام الفرعية
import 'package:my_test_app/screens/buyer/buyer_product_list_screen.dart'; // شاشة قائمة المنتجات
import 'package:my_test_app/screens/buyer/cart_screen.dart'; // شاشة السلة
// ملاحظة: بما أن PostRegistrationMessageScreen موجود كـ Class في نهاية الملف،
// لا نحتاج لاستيراد خاص له ما لم يكن في ملف خارجي.

import 'package:my_test_app/theme/app_theme.dart';
import 'package:my_test_app/providers/buyer_data_provider.dart';
import 'package:my_test_app/providers/manufacturers_provider.dart';
import 'package:my_test_app/providers/cart_provider.dart';
import 'package:my_test_app/models/logged_user.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:my_test_app/controllers/seller_dashboard_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {                                         
    await Firebase.initializeApp(               
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('🚨 FATAL FIREBASE INIT ERROR: $e');                                             
  }

  // ⭐️⭐️ تغليف التطبيق بـ MultiProvider ⭐️⭐️
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
      ],
      child: const MyApp(), // تطبيقنا الآن ابن لـ MultiProvider
    ),
  );
}

class MyApp extends StatelessWidget {           
  const MyApp({super.key});

  @override                                     
  Widget build(BuildContext context) {
    // ⭐️⭐️ الإضافة 2: تغليف MaterialApp بـ Sizer ⭐️⭐️
    return Sizer(
      builder: (context, orientation, deviceType) {
        return MaterialApp(
          title: 'My Test App',                     
          debugShowCheckedModeBanner: false,
          // 3. الثيم الفاتح - استخدام الثوابت الجديدة                                              
          theme: ThemeData(
            useMaterial3: true,                     
            primaryColor: AppTheme.primaryGreen,
            colorScheme: ColorScheme.light(
              primary: AppTheme.primaryGreen,
              secondary: AppTheme.accentBlueLight,
            ),
            scaffoldBackgroundColor: AppTheme.scaffoldLight,
            cardColor: Colors.white,
            // 💡💡 توحيد الخط لـ Noto Sans Arabic في الثيم الفاتح 💡💡
            textTheme: GoogleFonts.notoSansArabicTextTheme(                                         
              const TextTheme(
                bodyLarge: TextStyle(color: Color(0xff343a40)),
              ),
            ),
          ),
          // 4. الثيم الداكن - استخدام الثوابت الجديدة
          darkTheme: ThemeData.dark().copyWith(
            useMaterial3: true,
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
            // 💡💡 توحيد الخط لـ Noto Sans Arabic في الثيم الداكن 💡💡
            textTheme: GoogleFonts.notoSansArabicTextTheme(                                         
              const TextTheme(                      
                bodyLarge: TextStyle(color: Color(0xffe0e0e0)),                                     
              ),
            ),
          ),
          // 🔹 ضبط اتجاه النصوص مركزي لكل التطبيق
          builder: (context, child) {
            return Directionality(
              textDirection: TextDirection.rtl,     
              child: child!,
            );
          },
          // ⭐️⭐️ تعريف المسارات المُسمّاة 'routes' ⭐️⭐️                                              
          initialRoute: '/',
          routes: {
            '/': (context) => const AuthWrapper(), // 💡 المسار الرئيسي يوجه إلى الـ Wrapper
            // 💡 تعريف المسارات الأساسية
            LoginScreen.routeName: (context) => const LoginScreen(),
            BuyerHomeScreen.routeName: (context) => const BuyerHomeScreen(),
            SellerScreen.routeName: (context) => const SellerScreen(),
            CartScreen.routeName: (context) => const CartScreen(),

            // 🆕 مسارات التسجيل                    
            '/register': (context) => const NewClientScreen(),
            // 🆕 مسار رسالة ما بعد التسجيل         
            '/post_registration_message': (context) => const PostRegistrationMessageScreen(),
          },                                        
          // 🆕 استخدام onGenerateRoute لفك الـ Map الخاص بـ '/products'
          onGenerateRoute: (settings) {
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
            // ✅ توحيد معالجة مسار /category هنا
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
    ); // ⭐️⭐️ نهاية Sizer builder ⭐️⭐️
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
      final userData = LoggedInUser.fromJson(jsonDecode(userJsonString));

      // ⭐️ استدعاء initializeData لمزود البيانات ⭐️                                            
      final buyerProvider = Provider.of<BuyerDataProvider>(context, listen: false);

      // نمرر id مرتين لـ currentUserId و currentDealerId (حسب المنطق الأصلي)
      await buyerProvider.initializeData(userData.id, userData.id, userData.fullname);

      return userData;
    }
    return null; // لا يوجد مستخدم مسجل         
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<LoggedInUser?>(
      future: _userFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          // عرض شاشة تحميل بسيطة أثناء التحقق من الشيرد بريفرينسز
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // 💡 منطق التوجيه بناءً على حالة تسجيل الدخول والدور 💡
        if (snapshot.hasData && snapshot.data != null) {
          final user = snapshot.data!;          
          // توجيه بناءً على الدور المخزن
          if (user.role == "seller") {
            return const SellerScreen(); // 🎯 توجه مباشرة لـ SellerScreen
          } else {
            // "consumer" أو "buyer" أو أي شيء آخر يذهب إلى شاشة المشتري/المتجر
            return const BuyerHomeScreen(); //  🎯 توجه لـ BuyerHomeScreen
          }
        } else {                                
          // لم يتم تسجيل الدخول: اذهب إلى شاشة الدخول (Login Screen)
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
    // استقبال Arguments لتحديد ما إذا كان الحساب "seller"
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final isSeller = args?['isSeller'] ?? false;
    // ⭐️ التوجيه التلقائي بعد 3 ثوانٍ إلى شاشة تسجيل الدخول ⭐️
    Future.delayed(const Duration(seconds: 3), () {                                             
      // نستخدم pushReplacementNamed لضمان عدم العودة لهذه الشاشة
      Navigator.of(context).pushReplacementNamed(LoginScreen.routeName);                        
    });
                                                
    final String message;
    final IconData icon;                        
    final Color color;

    if (isSeller) {
      // 🚨 رسالة تاجر الجملة (قيد المراجعة) - تم التعديل بناءً على منطق المجموعات 🚨
      message = 'تم تسجيل حساب التاجر بنجاح.\nحسابك قيد المراجعة في انتظار النقل إلى التجار النشطين.';                                          
      icon = Icons.pending_actions;
      color = Colors.orange;
    } else {
      // رسالة تاجر التجزئة والمستهلك (نجاح)
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
