// lib/providers/theme_notifier.dart

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// تقليد منطق تخزين 'theme' في Local Storage
class ThemeNotifier extends ChangeNotifier {
  ThemeMode _themeMode;

  ThemeNotifier(this._themeMode) {
    // 🟢🟢 [التصحيح]: استدعاء دالة التحميل غير المتزامنة هنا 🟢🟢
    // هذا يسمح للـ Provider بالبدء بقيمة افتراضية ثم تحديثها بالقيمة الحقيقية لاحقاً.
    loadTheme();
  }

  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _themeMode == ThemeMode.dark;

  // جلب السمة المحفوظة عند بدء التشغيل
  Future<void> loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final savedTheme = prefs.getString('theme');
    
    // 💡 ملاحظة: يجب تحويل 'light' و 'dark' إلى ThemeMode
    ThemeMode newTheme;
    if (savedTheme == 'dark') {
      newTheme = ThemeMode.dark;
    } else if (savedTheme == 'light') {
      newTheme = ThemeMode.light;
    } else {
        // إذا لم يتم العثور على قيمة، يمكن الاحتفاظ بـ _themeMode الحالي (القيمة الافتراضية)
        return; 
    }
    
    if (_themeMode != newTheme) {
        _themeMode = newTheme;
        notifyListeners();
    }
  }

  // تبديل السمة وتخزينها
  void toggleTheme() async {
    final prefs = await SharedPreferences.getInstance();
    if (_themeMode == ThemeMode.light) {
      _themeMode = ThemeMode.dark;
      prefs.setString('theme', 'dark');
    } else {
      _themeMode = ThemeMode.light;
      prefs.setString('theme', 'light');
    }
    notifyListeners();
  }
}

// 💡 تعريف الثيمات
final lightTheme = ThemeData(
  brightness: Brightness.light,
  primaryColor: const Color(0xFF2c3e50), // var(--section-heading-color)
  colorScheme: ColorScheme.light(
    secondary: const Color(0xFF4CAF50), // var(--logo-icon-color)
    surface: Colors.white, // var(--category-card-bg)
  ),
  scaffoldBackgroundColor: const Color(0xFFf5f7fa), // var(--bg-color)
  cardColor: Colors.white,
  textTheme: const TextTheme(
    bodyLarge: TextStyle(color: Color(0xFF333333)), // var(--text-color)
    titleLarge: TextStyle(color: Color(0xFF2c3e50)),
  ),
  shadowColor: Colors.black, // لتقليد var(--shadow-color)
  appBarTheme: const AppBarTheme(
    backgroundColor: Color(0xFF2c3e50),
    foregroundColor: Colors.white,
  ),
);

final darkTheme = ThemeData(
  brightness: Brightness.dark,
  primaryColor: const Color(0xFF16213e),
  colorScheme: ColorScheme.dark(
    secondary: const Color(0xFFbb86fc), // var(--nav-item-active-color)
    surface: const Color(0xFF222831), // var(--category-card-bg)
  ),
  scaffoldBackgroundColor: const Color(0xFF1a1a2e), // var(--bg-color)
  cardColor: const Color(0xFF222831),
  textTheme: const TextTheme(
    bodyLarge: TextStyle(color: Color(0xFFe0e0e0)), // var(--text-color)
    titleLarge: TextStyle(color: Color(0xFFbb86fc)),
  ),
  shadowColor: Colors.white, // لتقليد var(--shadow-color)
  appBarTheme: const AppBarTheme(
    backgroundColor: Color(0xFF16213e),
    foregroundColor: Colors.white,
  ),
);

