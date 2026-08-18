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
  SellerModel? _sellerDetails;
  bool _isLoadingSeller = true;
  String _errorMessage = '';

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
          if (details != null) {
            _sellerDetails = details;
          } else {
            _errorMessage = 'بيانات المتجر غير موجودة';
          }
          _isLoadingSeller = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'خطأ في جلب بيانات المورد';
          _isLoadingSeller = false;
        });
      }
    }
  }

  Future<Uint8List> _buildA4Invoice(PdfPageFormat format) async {
    final pdf = pw.Document();
    final font = await PdfGoogleFonts.cairoRegular();
    final boldFont = await PdfGoogleFonts.cairoBold();
    
    final String storeName = _sellerDetails?.name ?? "متجر موثق";
    final String storePhone = _sellerDetails?.phone ?? "غير مسجل";
    final String storeAddress = _sellerDetails?.address ?? "غير محدد";

    pdf.addPage(
      pw.MultiPage(
        pageFormat: format,
        textDirection: pw.TextDirection.rtl,
        theme: pw.ThemeData.withFont(base: font, bold: boldFont),
        margin: const pw.EdgeInsets.all(25),

        header: (pw.Context context) {
          return pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 10),
            padding: const pw.EdgeInsets.only(bottom: 5),
            decoration: const pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  storeName,
                  style: pw.TextStyle(font: boldFont, fontSize: 10, color: PdfColors.green900),
                ),
                pw.Text(
                  'فاتورة رقم #${widget.order.id.substring(0, 8).toUpperCase()} - صفحة ${context.pageNumber} من ${context.pagesCount}',
                  style: pw.TextStyle(font: font, fontSize: 9, color: PdfColors.grey600),
                ),
              ],
            ),
          );
        },

        footer: (pw.Context context) {
          return pw.Column(
            mainAxisSize: pw.MainAxisSize.min,
            children: [
              pw.Divider(thickness: 0.5, color: PdfColors.grey400),
              pw.SizedBox(height: 3),
              pw.Center(
                child: pw.Text(
                  'نشكركم لثقتكم في $storeName - تم الإنشاء بواسطة أسواق اكسب 2026',
                  style: pw.TextStyle(font: font, fontSize: 8, color: PdfColors.grey500),
                ),
              ),
            ],
          );
        },

        build: (pw.Context context) {
          return [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(storeName,
                        style: pw.TextStyle(font: boldFont, fontSize: 22, color: PdfColors.green900)),
                    pw.SizedBox(height: 5),
                    pw.Text('هاتف: $storePhone', style: pw.TextStyle(font: font, fontSize: 11)),
                    pw.Text('العنوان: $storeAddress', style: pw.TextStyle(font: font, fontSize: 11)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: const pw.BoxDecoration(color: PdfColors.green50),
                      child: pw.Text('فاتورة ضريبية مبسطة',
                          style: pw.TextStyle(font: boldFont, fontSize: 14, color: PdfColors.green900)),
                    ),
                    pw.SizedBox(height: 5),
                    pw.Text('رقم الفاتورة: #${widget.order.id.substring(0, 8).toUpperCase()}',
                        style: pw.TextStyle(font: boldFont, fontSize: 10)),
                    pw.Text('التاريخ: ${DateFormat('yyyy-MM-dd HH:mm').format(widget.order.orderDate)}',
                        style: pw.TextStyle(font: font, fontSize: 10)),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 10),
            pw.Divider(thickness: 2, color: PdfColors.green800),
            pw.SizedBox(height: 20),

            pw.Text('فاتورة إلى:', style: pw.TextStyle(font: boldFont, fontSize: 12, color: PdfColors.grey700)),
            pw.SizedBox(height: 5),
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                  color: PdfColors.grey50,
                  borderRadius: pw.BorderRadius.circular(5),
                  border: pw.Border.all(color: PdfColors.grey200)),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('الاسم: ${widget.order.buyerDetails.name}', style: pw.TextStyle(font: boldFont, fontSize: 11)),
                  pw.SizedBox(height: 3),
                  pw.Text('الموبايل: ${widget.order.buyerDetails.phone}', style: pw.TextStyle(font: font, fontSize: 11)),
                  pw.Text('العنوان: ${widget.order.buyerDetails.address}', style: pw.TextStyle(font: font, fontSize: 11)),
                ],
              ),
            ),
            pw.SizedBox(height: 25),

            pw.TableHelper.fromTextArray(
              headers: ['اسم الصنف', 'الكمية', 'سعر الوحدة', 'الإجمالي'],
              data: widget.order.items.map((item) => [
                    item.name,
                    '${item.quantity}',
                    '${item.unitPrice.toStringAsFixed(2)} ج.م',
                    '${(item.quantity * item.unitPrice).toStringAsFixed(2)} ج.م'
                  ]).toList(),
              headerStyle: pw.TextStyle(font: boldFont, color: PdfColors.white, fontSize: 10),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.green800),
              cellStyle: pw.TextStyle(font: font, fontSize: 10),
              cellAlignment: pw.Alignment.centerRight,
              columnWidths: {
                0: const pw.FlexColumnWidth(3),
                1: const pw.FlexColumnWidth(1),
                2: const pw.FlexColumnWidth(1.5),
                3: const pw.FlexColumnWidth(1.5),
              },
            ),
            pw.SizedBox(height: 25),

            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Column(
                  children: [
                    pw.Container(
                      height: 70,
                      width: 70,
                      child: pw.BarcodeWidget(
                        barcode: pw.Barcode.qrCode(),
                        data: 'Order: ${widget.order.id} | Store: $storeName',
                      ),
                    ),
                    pw.SizedBox(height: 5),
                    pw.Text('امسح للتحقق', style: pw.TextStyle(font: font, fontSize: 8, color: PdfColors.grey600)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    _summaryRow('الإجمالي قبل الخصم:', '${widget.order.grossTotal.toStringAsFixed(2)} ج.م', font),
                    _summaryRow('خصم الكاش باك:', '-${widget.order.cashbackApplied.toStringAsFixed(2)} ج.م', font, color: PdfColors.red700),
                    pw.SizedBox(width: 150, child: pw.Divider(thickness: 1, color: PdfColors.grey400)),
                    _summaryRow('صافي المبلغ المطلوب:', '${widget.order.totalAmount.toStringAsFixed(2)} ج.م', boldFont, fontSize: 14, color: PdfColors.green900),
                  ],
                ),
              ],
            ),
          ];
        },
      ),
    );
    return pdf.save();
  }

  pw.Widget _summaryRow(String label, String value, pw.Font font, {double fontSize = 11, PdfColor? color}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Row(
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          pw.Text(value, style: pw.TextStyle(font: font, fontSize: fontSize, color: color ?? PdfColors.black)),
          pw.SizedBox(width: 15),
          pw.Text(label, style: pw.TextStyle(font: font, fontSize: fontSize)),
        ],
      ),
    );
  }

  // دالة المشاركة المباشرة لكل الصفحات
  Future<void> _shareFullPdf() async {
    final pdfBytes = await _buildA4Invoice(PdfPageFormat.a4);
    await Printing.sharePdf(
      bytes: pdfBytes,
      filename: "Aksab_Invoice_${widget.order.id.substring(0, 8)}.pdf",
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('معاينة الفاتورة للطباعة', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF28A745),
        centerTitle: true,
        actions: [
          if (!_isLoadingSeller && _errorMessage.isEmpty)
            IconButton(
              icon: const Icon(Icons.share),
              tooltip: 'مشاركة الفاتورة كاملة',
              onPressed: _shareFullPdf,
            ),
        ],
      ),
      body: SafeArea(
        child: _isLoadingSeller
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage.isNotEmpty
                ? Center(child: Text(_errorMessage, style: const TextStyle(color: Colors.red, fontFamily: 'Cairo')))
                : PdfPreview(
                    build: (format) => _buildA4Invoice(format),
                    canChangePageFormat: false,
                    initialPageFormat: PdfPageFormat.a4,
                    pdfFileName: "Aksab_Invoice_${widget.order.id.substring(0, 8)}.pdf",
                  ),
      ),
    );
  }
}