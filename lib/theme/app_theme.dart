// lib/theme/app_theme.dart
import 'package:flutter/material.dart';

// 🟢 1. إضافة كلاس AppTheme ليحتوي على الثوابت التي تشير إليها من main.dart
class AppTheme {
  // الثوابت الانتقالية: تُستخدم في main.dart وفي الصفحات القديمة قبل تحديثها بالكامل
  static const Color primaryGreen = Color(0xff28a745);
  static const Color accentBlueLight = Color(0xff007bff);
  static const Color scaffoldLight = Color(0xfff8f9fa);
  static const Color cardDark = Color(0xff2c2c2c);
  static const Color darkSidebarBg = Color(0xff212529);

  // 🎯 الثوابت المضافة حديثاً لحل مشاكل trader_offer_card.dart
  static const Color primaryDarkGreen = Color(0xff388E3C); // لون أخضر داكن
  static const Color textDark = Color(0xff333333); // لون نص داكن لتباين عالٍ

  // 🆕🆕 الثوابت المضافة حديثًا لحل أخطاء Consumer Widgets 🆕🆕
  static const Color borderColor = Color(0xFFE0E0E0); // لون حدود افتراضي
  static const Color secondaryTextColor = Color(0xFF757575); // لون نص ثانوي
  
}

/// اللون الأساسي الافتراضي الاحتياطي (هذا اللون يستخدم إذا كان الجهاز لا يدعم Material You)
const Color _defaultSeedColor = Color(0xFF1B5E20); // لون أخضر داكن متناسق

/// دالة مساعدة لإنشاء ThemeData Light و Dark باستخدام Dynamic Color
///
/// [dynamicColorScheme] هو مخطط الألوان المستخرج من خلفية شاشة المستخدم (Material You).
/// [brightness] يحدد ما إذا كنا نبني ثيم الوضع النهاري أو الليلي.
ThemeData createTheme(ColorScheme? dynamicColorScheme, Brightness brightness) {
  // 1. تحديد مخطط الألوان (ColorScheme)
  ColorScheme colorScheme;

  if (dynamicColorScheme != null) {
    // استخدم الألوان الديناميكية إن وجدت
    colorScheme = dynamicColorScheme;
  } else {
    // استخدم اللون الأساسي الاحتياطي (Seed Color)
    colorScheme = ColorScheme.fromSeed(
      seedColor: _defaultSeedColor,
      brightness: brightness,
    );
  }

  // 2. بناء ThemeData باستخدام Material 3
  return ThemeData(
    // تفعيل Material 3
    useMaterial3: true,

    // إسناد مخطط الألوان الذي تم تحديده
    colorScheme: colorScheme,

    // 🟢 1. الخطوط (Text Theme)
    fontFamily: 'Tajawal',
    textTheme: const TextTheme( ),

    // 🟢 2. تخصيص الـ AppBar (شريط العناوين)
    appBarTheme: AppBarTheme(
      backgroundColor: colorScheme.surface,
      foregroundColor: colorScheme.onSurface,
      elevation: 0,
      centerTitle: true,
    ),

    // 🟢 3. تخصيص الأزرار المعبأة (Filled Buttons)
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),

    // 🟢 4. تخصيص حقول الإدخال (Input Decoration Theme)
    inputDecorationTheme: InputDecorationTheme(
      contentPadding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 12.0),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10.0),
        borderSide: BorderSide(color: colorScheme.outline, width: 1.0),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10.0),
        borderSide: BorderSide(color: colorScheme.outlineVariant, width: 1.0),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10.0),
        borderSide: BorderSide(color: colorScheme.primary, width: 2.0),
      ),
      fillColor: colorScheme.surface,
      filled: true,
    ),

    // 🟢 5. تخصيص الخطوط الفاصلة (Divider Theme)
    dividerTheme: DividerThemeData(
      color: colorScheme.outlineVariant,
      space: 1,
      thickness: 1,
    ),

    // 6. الـ Card Theme (تم إصلاحه في نسختك الأصلية)
    cardTheme: CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: colorScheme.surfaceContainerHigh,
    ),
  );
}

