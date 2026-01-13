import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/consumer_order_model.dart';

class OrderPrinterHelper {
  static Future<void> printOrderReceipt(ConsumerOrderModel order) async {
    final pdf = pw.Document();

    // تحميل خط يدعم العربية (مهم جداً للطباعة بالعربي)
    final fontData = await PdfGoogleFonts.cairoRegular();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80, // تنسيق ورق الكاشير الصغير
        build: (pw.Context context) {
          return pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Center(
                  child: pw.Text(order.supermarketName, 
                    style: pw.TextStyle(font: fontData, fontSize: 20, fontWeight: pw.FontWeight.bold)),
                ),
                pw.Divider(),
                pw.Text('رقم الطلب: ${order.orderId}', style: pw.TextStyle(font: fontData)),
                pw.Text('التاريخ: ${order.orderDate?.toString().split(' ')[0]}', style: pw.TextStyle(font: fontData)),
                pw.Text('العميل: ${order.customerName}', style: pw.TextStyle(font: fontData)),
                pw.Text('الهاتف: ${order.customerPhone}', style: pw.TextStyle(font: fontData)),
                pw.Divider(),
                pw.Text('المنتجات:', style: pw.TextStyle(font: fontData, fontWeight: pw.FontWeight.bold)),
                
                // جدول المنتجات
                pw.ListView.builder(
                  itemCount: order.items.length,
                  itemBuilder: (context, index) {
                    final item = order.items[index];
                    return pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(vertical: 2),
                      child: pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(item.name ?? 'منتج', style: pw.TextStyle(font: fontData, fontSize: 10)),
                          pw.Text('x${item.quantity}', style: pw.TextStyle(font: fontData, fontSize: 10)),
                        ],
                      ),
                    );
                  },
                ),
                
                pw.Divider(),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('التوصيل:', style: pw.TextStyle(font: fontData)),
                    pw.Text('${order.deliveryFee} EGP', style: pw.TextStyle(font: fontData)),
                  ],
                ),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('الإجمالي النهائي:', style: pw.TextStyle(font: fontData, fontWeight: pw.FontWeight.bold)),
                    pw.Text('${order.finalAmount} EGP', style: pw.TextStyle(font: fontData, fontWeight: pw.FontWeight.bold)),
                  ],
                ),
                pw.SizedBox(height: 20),
                pw.Center(
                  child: pw.Text('شكراً لتعاملكم معنا', style: pw.TextStyle(font: fontData, fontSize: 12)),
                ),
              ],
            ),
          );
        },
      ),
    );

    // أمر الطباعة المباشر
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Receipt-${order.orderId}',
    );
  }
}
