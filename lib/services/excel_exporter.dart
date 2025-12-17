import 'dart:io';
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:my_test_app/models/order_model.dart';
import 'package:share_plus/share_plus.dart'; // ضرورية جداً للأندرويد
import 'package:flutter/foundation.dart' show kIsWeb; // للتحقق من الويب بأمان

class ExcelExporter {
  static Future<String> exportOrders(List<OrderModel> orders, String userRole) async {
    
    // 1. طلب الصلاحيات (فقط للأندرويد وغير الويب)
    if (!kIsWeb && Platform.isAndroid) {
      // في أندرويد 11 وما فوق، يفضل استخدام share_plus لتجنب تعقيدات الوصول للذاكرة
      await Permission.storage.request();
    }

    // 2. إنشاء كائن Excel
    final excel = Excel.createExcel();
    final Sheet sheet = excel['الطلبات'];

    // 3. تعريف الأعمدة
    final headerRow = [
      'رقم الطلب', 'الحالة', 'تاريخ الطلب', 'الإجمالي',
      'اسم الصنف', 'الكمية', 'سعر الوحدة', 'إجمالي الصنف'
    ];
    
    final List<CellValue> headerCells = headerRow.map((h) => TextCellValue(h)).toList();
    sheet.insertRowIterables(headerCells, 0);

    // 4. تعبئة البيانات
    int rowIndex = 1;
    final formatter = DateFormat('yyyy-MM-dd HH:mm:ss', 'en_US');

    for (var order in orders) {
      for (var item in order.items) {
        final itemTotal = (item.quantity * item.unitPrice).toDouble();
        
        final List<CellValue> rowData = [
          TextCellValue(order.id.substring(0, 8)), // تبسيط الرقم للمورد
          TextCellValue(order.statusText),
          TextCellValue(formatter.format(order.orderDate)),
          DoubleCellValue(order.totalAmount),
          TextCellValue(item.name),
          IntCellValue(item.quantity),
          DoubleCellValue(item.unitPrice),
          DoubleCellValue(itemTotal),
        ];
        sheet.insertRowIterables(rowData, rowIndex);
        rowIndex++;
      }
    }

    // 5. حفظ وتصدير الملف (منطق الأندرويد القوي)
    final fileBytes = excel.encode();
    if (fileBytes == null) throw Exception('فشل في إنشاء محتوى ملف Excel');

    if (kIsWeb) {
      // إذا كنت تجرب على الويب حالياً (تجنب الانهيار)
      return "التصدير مدعوم بالكامل على نسخة الأندرويد فقط";
    } else {
      // ⭐️ شغل الأندرويد الأساسي ⭐️
      final timeStamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final fileName = 'Orders_$timeStamp.xlsx';
      
      // حفظ في مجلد مؤقت آمن
      final directory = await getTemporaryDirectory();
      final filePath = '${directory.path}/$fileName';
      final file = File(filePath);
      await file.writeAsBytes(fileBytes, flush: true);

      // أهم خطوة للأندرويد: فتح قائمة المشاركة لسهولة الوصول
      await Share.shareXFiles([XFile(filePath)], text: 'تقرير طلبات $userRole');
      
      return filePath;
    }
  }
}
