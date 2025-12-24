import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'dart:typed_data';
import 'package:my_test_app/models/order_model.dart';
import 'package:my_test_app/models/seller_model.dart';
import 'package:my_test_app/data_sources/seller_data_source.dart';

class InvoiceScreen extends StatefulWidget {
  final OrderModel order;
  const InvoiceScreen({super.key, required this.order});

  @override
  State<InvoiceScreen> createState() => _InvoiceScreenState();
}

class _InvoiceScreenState extends State<InvoiceScreen> {
  final SellerDataSource _sellerDataSource = SellerDataSource();
  SellerModel _sellerDetails = SellerModel.defaultPlaceholder();
  bool _isLoadingSeller = true;

  @override
  void initState() {
    super.initState();
    _fetchSellerDetails();
  }

  Future<void> _fetchSellerDetails() async {
    try {
      final details = await _sellerDataSource.getSellerDetails(widget.order.sellerId);
      if (mounted) {
        setState(() {
          _sellerDetails = details;
          _isLoadingSeller = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingSeller = false);
      }
    }
  }

  Future<Uint8List> _buildA4Invoice(PdfPageFormat format) async {
    final pdf = pw.Document();
    final font = await PdfGoogleFonts.cairoRegular();
    final boldFont = await PdfGoogleFonts.cairoBold();

    pdf.addPage(
      pw.Page(
        pageFormat: format,
        build: (pw.Context context) {
          return pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.Container(
              padding: const pw.EdgeInsets.all(20),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // --- الترويسة الاحترافية ---
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(_sellerDetails.name, style: pw.TextStyle(font: boldFont, fontSize: 22, color: PdfColors.green800)),
                          pw.Text('هاتف: ${_sellerDetails.phone}', style: pw.TextStyle(font: font, fontSize: 11)),
                          pw.Text('العنوان: ${_sellerDetails.address}', style: pw.TextStyle(font: font, fontSize: 11)),
                        ],
                      ),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text('فاتورة ضريبية مبسطة', style: pw.TextStyle(font: boldFont, fontSize: 14)),
                          pw.Text('رقم الطلب: #${widget.order.id.substring(0, 8)}', style: pw.TextStyle(font: font, fontSize: 10)),
                          pw.Text('التاريخ: ${DateFormat('yyyy-MM-dd').format(widget.order.orderDate)}', style: pw.TextStyle(font: font, fontSize: 10)),
                        ],
                      ),
                    ],
                  ),
                  pw.Divider(thickness: 2, color: PdfColors.green800),
                  pw.SizedBox(height: 20),

                  // --- بيانات العميل ---
                  pw.Text('بيانات العميل:', style: pw.TextStyle(font: boldFont, fontSize: 12)),
                  pw.Container(
                    width: double.infinity,
                    padding: const pw.EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(color: PdfColors.grey100),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('الاسم: ${widget.order.buyerDetails.name}', style: pw.TextStyle(font: font, fontSize: 11)),
                        pw.Text('الموبايل: ${widget.order.buyerDetails.phone}', style: pw.TextStyle(font: font, fontSize: 11)),
                        pw.Text('العنوان: ${widget.order.buyerDetails.address}', style: pw.TextStyle(font: font, fontSize: 11)),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 20),

                  // --- جدول المنتجات (الأصناف) ---
                  pw.TableHelper.fromTextArray(
                    headers: ['اسم الصنف', 'الكمية', 'سعر الوحدة', 'الإجمالي'],
                    data: widget.order.items.map((item) => [
                      item.name,
                      '${item.quantity}',
                      '${item.unitPrice.toStringAsFixed(2)}',
                      '${(item.quantity * item.unitPrice).toStringAsFixed(2)}'
                    ]).toList(),
                    headerStyle: pw.TextStyle(font: boldFont, color: PdfColors.white, fontSize: 10),
                    headerDecoration: const pw.BoxDecoration(color: PdfColors.green900),
                    cellStyle: pw.TextStyle(font: font, fontSize: 10),
                    cellAlignment: pw.Alignment.centerRight,
                  ),
                  
                  pw.SizedBox(height: 20),

                  // --- الملخص المالي والباركود ---
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      // QR Code لإضافة لمسة تقنية
                      pw.Container(
                        height: 80, width: 80,
                        child: pw.BarcodeWidget(
                          barcode: pw.Barcode.qrCode(),
                          data: 'Order: ${widget.order.id} | Store: ${_sellerDetails.name}',
                        ),
                      ),
                      // الحسابات
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          _summaryRow('الإجمالي:', '${widget.order.grossTotal.toStringAsFixed(2)} ج.م', font),
                          _summaryRow('خصم كاش باك:', '-${widget.order.cashbackApplied.toStringAsFixed(2)} ج.م', font, color: PdfColors.red700),
                          pw.Divider(width: 150),
                          _summaryRow('الصافي النهائي:', '${widget.order.totalAmount.toStringAsFixed(2)} ج.م', boldFont, fontSize: 14),
                        ],
                      ),
                    ],
                  ),

                  pw.Spacer(),
                  pw.Center(
                    child: pw.Text('شكراً لثقتكم في ${_sellerDetails.name} - تم الإنشاء عبر تطبيق أسواق اكسب', 
                        style: pw.TextStyle(font: font, fontSize: 9, color: PdfColors.grey600)),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    return pdf.save();
  }

  pw.Widget _summaryRow(String label, String value, pw.Font font, {double fontSize = 11, PdfColor? color}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          pw.Text(value, style: pw.TextStyle(font: font, fontSize: fontSize, color: color ?? PdfColors.black)),
          pw.SizedBox(width: 10),
          pw.Text(label, style: pw.TextStyle(font: font, fontSize: fontSize)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('طباعة الفاتورة'), backgroundColor: const Color(0xFF28A745)),
      body: _isLoadingSeller
          ? const Center(child: CircularProgressIndicator())
          : PdfPreview(
              build: (format) => _buildA4Invoice(format),
              canChangePageFormat: false,
              initialPageFormat: PdfPageFormat.a4,
              pdfFileName: "invoice_${widget.order.id.substring(0,8)}.pdf",
            ),
    );
  }
}

