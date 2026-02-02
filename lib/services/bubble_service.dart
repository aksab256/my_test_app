import 'package:flutter/material.dart';
import '../widgets/order_bubble.dart';
import '../main.dart'; // لاستخدام الـ navigatorKey العالمي

class BubbleService {
  static OverlayEntry? _overlayEntry;

  // 1. دالة إظهار الفقاعة (تم تحسين جلب الـ Overlay)
  static void show(String orderId) {
    if (_overlayEntry != null) return;

    // جلب الـ context من الـ navigatorKey لضمان الوصول للـ Overlay الصحيح
    final context = navigatorKey.currentContext;
    if (context == null) return;

    final overlay = Overlay.of(context);

    _overlayEntry = OverlayEntry(
      builder: (context) => OrderBubble(orderId: orderId),
    );

    overlay.insert(_overlayEntry!);
  }

  // 2. دالة إخفاء الفقاعة (تم إضافة try-catch لمنع الكراش)
  static void hide() {
    if (_overlayEntry != null) {
      try {
        _overlayEntry!.remove();
      } catch (e) {
        debugPrint("Overlay already removed or not found: $e");
      }
      _overlayEntry = null;
    }
  }

  // 3. دالة العودة الآمنة (الحل السحري للشاشة السوداء)
  // نستخدمها لما نحب نقفل الفقاعة ونرجع للتطبيق في نفس الوقت
  static void safeBackToApp() {
    hide(); // إخفاء الفقاعة أولاً
    
    // إخبار الـ Navigator العالمي بالرجوع لأول شاشة مستقرة (الرئيسية)
    // ده بيجبر الأندرويد يركز على التطبيق تاني ويلغي السواد
    if (navigatorKey.currentState != null) {
      navigatorKey.currentState!.popUntil((route) => route.isFirst);
    }
  }
}
