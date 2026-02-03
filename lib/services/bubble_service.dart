import 'package:flutter/material.dart';
import '../widgets/order_bubble.dart';
import '../main.dart'; 

class BubbleService {
  static OverlayEntry? _overlayEntry;

  static void show(String orderId) {
    if (_overlayEntry != null) hide();

    // تأخير بسيط جداً (100 مللي ثانية) عشان نضمن إن الـ Pop خلص والـ Navigator استقر
    Future.delayed(const Duration(milliseconds: 100), () {
      // ✅ بنجيب الـ Context من الـ currentState مباشرة
      final context = navigatorKey.currentState?.overlay?.context;
      
      if (context == null) {
        debugPrint("❌ Bubble Error: Could not find overlay context");
        return;
      }

      try {
        // ✅ استخدام rootOverlay: true هو السر عشان تظهر فوق كل حاجة
        final overlay = Overlay.of(context, rootOverlay: true);

        _overlayEntry = OverlayEntry(
          builder: (context) => OrderBubble(orderId: orderId),
        );

        overlay.insert(_overlayEntry!);
        debugPrint("✅ Bubble Inserted Successfully for Order: $orderId");
      } catch (e) {
        debugPrint("❌ Bubble Insertion Failed: $e");
      }
    });
  }

  static void hide() {
    if (_overlayEntry != null) {
      try {
        _overlayEntry!.remove();
      } catch (e) {
        debugPrint("⚠️ Overlay already removed: $e");
      }
      _overlayEntry = null;
    }
  }

  static void safeBackToApp() {
    hide();
    if (navigatorKey.currentState != null) {
      navigatorKey.currentState!.popUntil((route) => route.isFirst);
    }
  }
}
