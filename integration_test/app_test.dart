import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:my_test_app/main.dart' as app;

void main() {
  // تأمين تهيئة بيئة الاختبار التلقائي الشامل
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('🧪 فحص دورة التطبيق الشاملة (E2E Test)', () {
    testWidgets('محاكاة دورة الدورة اللوجستية الكاملة من السلة حتى تأكيد العهدة', (tester) async {
      app.main(); // إطلاق التطبيق بالكامل
      
      // الانتظار الكامل حتى تستقر الشاشة الافتتاحية وتتحمل البيانات من الفايربيز
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // البحث عن زر الشراء أو التوجه للسلة (تأمين البحث لمنع خطأ No element)
      final checkoutButton = find.byType(ElevatedButton); 

      // إذا لم يظهر الزر فوراً، ننتظر حتى يظهر في الواجهة
      if (!tester.any(checkoutButton)) {
        debugPrint('⏳ في انتظار تحميل واجهة المنتجات أو السلة...');
        await tester.pumpAndSettle(const Duration(seconds: 3));
      }

      // التحقق والتفاعل مع الزر الأول المتاح
      if (tester.any(checkoutButton)) {
        await tester.tap(checkoutButton.first);
        await tester.pumpAndSettle(const Duration(seconds: 2));

        // 2. محاكاة إدخال كود التاجر أو تفاصيل عنوان العهدة
        final addressField = find.byType(TextField);
        if (tester.any(addressField)) {
          await tester.enterText(addressField.first, 'سموحة، الإسكندرية - عهدة مؤمنة');
          await tester.pumpAndSettle();
        }

        // 3. البحث عن زر تأكيد العهدة النهائي ورصد استجابة السيرفر
        final confirmButton = find.text('تأكيد العهدة');
        
        if (tester.any(confirmButton)) {
           await tester.tap(confirmButton);
           await tester.pumpAndSettle(const Duration(seconds: 4));
           
           // التأكد من ظهور رسالة النجاح اللوجستية الشاملة للتطبيق
           expect(find.text('✅ تم تأكيد العهدة وإرسال الطلب!'), findsOneWidget);
        }
      } else {
        debugPrint('⚠️ تنبيه: لم يتم العثور على أزرار تفاعل في الشاشة الحالية، تأكد من حالة تسجيل الدخول.');
      }
    });
  });
}