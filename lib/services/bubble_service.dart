import 'package:flutter/material.dart';
import '../widgets/order_bubble.dart';
import '../main.dart'; // لاستخدام الـ navigatorKey العالمي

class BubbleService {
  static OverlayEntry? _overlayEntry;

  // 1. دالة إظهار الفقاعة (تم إضافة Microtask لضمان استقرار الـ Navigation)
  static void show(String orderId) {
    // إذا كانت الفقاعة موجودة، نحذفها أولاً لتحديث البيانات
    if (_overlayEntry != null) {
      hide();
    }

    // استخدام Future.microtask يضمن تنفيذ الإظهار "بعد" اكتمال العمليات الحالية
    // وهذا يمنع خطأ الـ Null Check ويسهل إرسال الطلب في الخلفية
    Future.microtask(() {
      final context = navigatorKey.currentContext;
      if (context == null) return;

      try {
        final overlay = Overlay.of(context);

        _overlayEntry = OverlayEntry(
          builder: (context) => OrderBubble(orderId: orderId),
        );

        overlay.insert(_overlayEntry!);
      } catch (e) {
        debugPrint("❌ Error inserting bubble overlay: $e");
      }
    });
  }

  // 2. دالة إخفاء الفقاعة بأمان
  static void hide() {
    if (_overlayEntry != null) {
      try {
        _overlayEntry!.remove();
      } catch (e) {
        debugPrint("⚠️ Overlay already removed or not found: $e");
      }
      _overlayEntry = null;
    }
  }

  // 3. دالة العودة الآمنة (الحل السحري للشاشة السوداء)
  static void safeBackToApp() {
    hide(); // إخفاء الفقاعة أولاً
    
    // إجبار الـ Navigator على العودة للرئيسية لضمان تركيز الشاشة (Focus)
    if (navigatorKey.currentState != null) {
      navigatorKey.currentState!.popUntil((route) => route.isFirst);
    }
  }
}
