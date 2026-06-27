import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdf/pdf.dart'; // حزمة التنسيق المالي للـ PDF
import 'package:pdf/widgets.dart' as pw; // حزمة بناء عناصر الـ PDF
import 'package:printing/printing.dart'; // حزمة أمر الطباعة الفوري للويندوز والويب والموبايل
import '../../../main.dart'; // الوصول الحي لإعدادات البيئة النشطة AppSettings.isDemoMode

// ==========================================
// شاشة حوكمة وإدارة الخزائن المالية المركزية
// ==========================================
class TreasuriesManagementPage extends StatefulWidget {
  const TreasuriesManagementPage({super.key});

  @override
  State<TreasuriesManagementPage> createState() => _TreasuriesManagementPageState();
}

class _TreasuriesManagementPageState extends State<TreasuriesManagementPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _balanceController = TextEditingController();

  // الفرز والتوجيه التلقائي للمجموعات بنفس طريقتك المعتمدة بالكود (إضافة ديمو أمام الاسم)
  String get treasuriesCollection => AppSettings.isDemoMode ? 'demo_treasuries' : 'treasuries';

  // دالة تأسيس خزينة مالية جديدة وحفظ الرصيد الافتتاحي بالسيرفر
  Future<void> _createNewTreasury() async {
    if (!_formKey.currentState!.validate()) return;
    try {
      final double initialBalance = double.parse(_balanceController.text.trim());
      final String treasuryName = _nameController.text.trim();

      // الحقول ثابتة ومطابقة تماماً في الديمو واللايف لتأمين العهدة
      await FirebaseFirestore.instance.collection(treasuriesCollection).add({
        'treasury_name': treasuryName,
        'available_balance': initialBalance,
        'created_at': FieldValue.serverTimestamp(),
        'is_active': true,
      });

      _nameController.clear();
      _balanceController.clear();
      if (mounted) Navigator.pop(context); // إغلاق نافذة الإدخال المنبثقة

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("تم تأسيس الخزينة بنجاح وإدراج الرصيد الافتتاحي بدفاتر المحاسبة", style: TextStyle(fontFamily: 'Cairo')),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("حدث خطأ أثناء التأسيس المالي: $e", style: const TextStyle(fontFamily: 'Cairo')), backgroundColor: Colors.red),
      );
    }
  }

  // نافذة منبثقة لتأسيس خزينة / عهدة مالية جديدة
  void _showCreateDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          "تأسيس خزينة / عهدة مالية جديدة", 
          style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16)
        ),
        content: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'اسم الخزينة (مثال: الخزينة المركزية بالأسكندرية)', 
                  border: OutlineInputBorder(),
                  labelStyle: TextStyle(fontFamily: 'Cairo', fontSize: 13),
                ),
                validator: (val) => (val == null || val.trim().isEmpty) ? 'يرجى إدخال اسم الخزينة الرسمي' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _balanceController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'الرصيد الدفتري الافتتاحي (جنيه)', 
                  border: OutlineInputBorder(),
                  labelStyle: TextStyle(fontFamily: 'Cairo', fontSize: 13),
                ),
                validator: (val) => (val == null || double.tryParse(val) == null) ? 'يرجى إدخال رصيد نقدي صحيح' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), 
            child: const Text("إلغاء", style: TextStyle(fontFamily: 'Cairo'))
          ),
          ElevatedButton(
            onPressed: _createNewTreasury,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo[900]),
            child: const Text("تأكيد التأسيس المالي", style: TextStyle(color: Colors.white, fontFamily: 'Cairo')),
          ),
        ],
      ),
    );
  }

  // شريط تعريف وتنبيه لوضع المحاكاة (الديمو) بنفس الهوية المرئية للنظام
  Widget _buildDemoBadge() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.amber[100],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.amber[400]!),
      ),
      child: Row(
        children: [
          Icon(Icons.science_outlined, color: Colors.amber[900], size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              "وضع المحاكاة نشط: الحركات تذهب وتُجلب تلقائيًا من كوليكشن ($treasuriesCollection).",
              style: TextStyle(color: Colors.amber[900], fontWeight: FontWeight.w500, fontSize: 12, fontFamily: 'Cairo'),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          AppSettings.isDemoMode ? "حوكمة الخزائن الحسابية (وضع تجريبي)" : "الحوكمة والرقابة الحية على الخزائن والأرصدة",
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white, fontFamily: 'Cairo'),
        ),
        backgroundColor: Colors.indigo[900],
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: ElevatedButton.icon(
              onPressed: _showCreateDialog,
              icon: const Icon(Icons.add, size: 16, color: Colors.indigo),
              label: const Text("تأسيس خزينة", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo, fontFamily: 'Cairo')),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.white),
            ),
          )
        ],
      ),
      body: Column(
        children: [
          if (AppSettings.isDemoMode) _buildDemoBadge(), // ظهور العلامة التنبيهية فورا في وضع الديمو
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection(treasuriesCollection)
                  .orderBy('created_at', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text(
                      "لا توجد خزائن مالية معرفة بنظام الشركة حالياً. اضغط على تأسيس خزينة للبدء.",
                      style: TextStyle(fontFamily: 'Cairo', fontSize: 13, color: Colors.grey),
                    ),
                  );
                }

                return GridView.builder(
                  padding: const EdgeInsets.all(24),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 380,
                    childAspectRatio: 1.4,
                    crossAxisSpacing: 20,
                    mainAxisSpacing: 20,
                  ),
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    final doc = snapshot.data!.docs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final String name = data['treasury_name'] ?? 'خزينة مالية غير معرفة';
                    final double balance = (data['available_balance'] ?? 0.0).toDouble();

                    return InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => TreasuryDetailsPage(
                              treasuryId: doc.id,
                              treasuryName: name,
                            ),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Card(
                        elevation: 1,
                        color: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: Colors.grey[200]!, width: 1),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(color: Colors.teal[50], borderRadius: BorderRadius.circular(12)),
                                    child: const Icon(Icons.account_balance_wallet_rounded, color: Colors.teal, size: 24),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(color: Colors.green[50], borderRadius: BorderRadius.circular(20)),
                                    child: const Text("نشط ومطابق", style: TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
                                  )
                                ],
                              ),
                              const Spacer(),
                              Text(
                                name,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1E293B), fontFamily: 'Cairo'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 6),
                              Row(
                                textBaseline: TextBaseline.alphabetic,
                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                children: [
                                  Text(
                                    balance.toStringAsFixed(2),
                                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 22, color: Colors.indigo),
                                  ),
                                  const SizedBox(width: 4),
                                  const Text("جنيه", style: TextStyle(fontSize: 12, color: Colors.grey, fontFamily: 'Cairo')),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Icon(Icons.analytics_outlined, size: 14, color: Colors.blueGrey[400]),
                                  const SizedBox(width: 6),
                                  Text("اضغط لمعاينة كشف الحساب والدفتر اليومي", style: TextStyle(fontSize: 11, color: Colors.blueGrey[400], fontFamily: 'Cairo')),
                                ],
                              )
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// شاشة تفاصيل كشف الحساب المفتوح
// ==========================================
class TreasuryDetailsPage extends StatelessWidget {
  final String treasuryId;
  final String treasuryName;

  const TreasuryDetailsPage({
    super.key,
    required this.treasuryId,
    required this.treasuryName,
  });

  // الفرز اللوجستي لجدول الحركات التفصيلية (إضافة ديمو أمام الاسم)
  String get transactionsCollection => AppSettings.isDemoMode ? 'demo_treasury_transactions' : 'treasury_transactions';

  Widget _buildDetailsDemoBadge() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.amber[100],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.amber[400]!),
      ),
      child: Row(
        children: [
          Icon(Icons.analytics_outlined, color: Colors.amber[900], size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              "معاينة تفصيلية (وضع تجريبي): القيود والحركات تُجلب من مجموعة ($transactionsCollection).",
              style: TextStyle(color: Colors.amber[900], fontWeight: FontWeight.w500, fontSize: 11, fontFamily: 'Cairo'),
            ),
          ),
        ],
      ),
    );
  }

  // 📝 دالة توليد وطباعة ملف الـ PDF الاحترافي الداعم للغة العربية بدون أي خطأ في الـ Positional Arguments
  Future<void> _printTreasuryReport(List<QueryDocumentSnapshot> docs) async {
    final pdf = pw.Document();
    // تحميل خط عربي متوافق لضمان عدم خروج الحروف بشكل مقطع بالـ PDF
    final arabicFont = await PdfGoogleFonts.cairoRegular();
    final arabicFontBold = await PdfGoogleFonts.cairoBold();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(base: arabicFont, bold: arabicFontBold),
        textDirection: pw.TextDirection.rtl, // تحديد الاتجاه العربي من اليمين لليسار بالتقرير
        build: (pw.Context context) {
          return [
            pw.Header(
              level: 0,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text("مجموعة شركات الهناء - نظام الحوكمة والرقابة ERP", style: pw.TextStyle(fontSize: 12, color: PdfColors.blueGrey)),
                  pw.Text("كشف حساب جاري الخزينة", style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900)),
                ],
              ),
            ),
            pw.SizedBox(height: 15),
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: const pw.BoxDecoration(
                border: pw.Border(
                  top: pw.BorderSide(color: PdfColors.grey300),
                  bottom: pw.BorderSide(color: PdfColors.grey300),
                  left: pw.BorderSide(color: PdfColors.grey300),
                  right: pw.BorderSide(color: PdfColors.grey300),
                ),
                borderRadius: pw.BorderRadius.all(pw.Radius.circular(8)),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text("اسم الخزينة المستهدفة: $treasuryName", style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 4),
                  pw.Text("معرف السيرفر الحسابي: $treasuryId", style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
                  pw.SizedBox(height: 4),
                  pw.Text("تاريخ وطباعة التقرير: ${DateTime.now().toLocal().toString().substring(0, 16)}", style: const pw.TextStyle(fontSize: 10)),
                ],
              ),
            ),
            pw.SizedBox(height: 20),
            pw.Text("الدفتر الحركي التفصيلي لقيود الخزينة:", style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 10),
            
            // بناء جدول البيانات بداخل مستند الـ PDF باستخدام أنواع الكلاسات المحمية لـ pw حصراً
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              columnWidths: const {
                0: pw.FlexColumnWidth(2.5), // رقم المعاملة
                1: pw.FlexColumnWidth(2),   // نوع القيد
                2: pw.FlexColumnWidth(1.5), // الحركة المالية
                3: pw.FlexColumnWidth(2.5), // الطرف المستلم
                4: pw.FlexColumnWidth(2),   // المستند المرجعي
                5: pw.FlexColumnWidth(2.5), // التاريخ والوقت
              },
              children: [
                // ترويسة الجدول بالـ PDF
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                  children: [
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('رقم المعاملة', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('نوع القيد', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('الحركة المالية', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('الطرف المستلم', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('المستند المرجعي', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('التاريخ والوقت', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
                  ],
                ),
                // صفوف القيود المحاسبية الحية
                ...docs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final String txId = data['transactionId'] ?? doc.id;
                  final String type = data['type'] == 'outflow' ? 'دائن / مصروف سائل' : 'مدين / توريد نقدية';
                  final double amount = (data['amount'] ?? 0.0).toDouble();
                  final String partyName = data['partyName'] ?? 'تسوية حسابات داخلية';
                  final String invoice = data['invoiceNumber'] ?? 'بدون ملحق';
                  
                  final Timestamp? createdAt = data['createdAt'] as Timestamp?;
                  final String dateLabel = createdAt != null 
                      ? "${createdAt.toDate().toLocal().toIso8601String().substring(0, 10)} ${createdAt.toDate().toLocal().toIso8601String().substring(11, 16)}"
                      : '---';

                  return pw.TableRow(
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(txId, style: const pw.TextStyle(fontSize: 8))),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(type, style: const pw.TextStyle(fontSize: 9))),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text("$amount جنيه", style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold))),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(partyName, style: const pw.TextStyle(fontSize: 9))),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(invoice, style: const pw.TextStyle(fontSize: 9))),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(dateLabel, style: const pw.TextStyle(fontSize: 8))),
                    ],
                  );
                }).toList(),
              ],
            ),
          ];
        },
      ),
    );

    // استدعاء نظام الطباعة الأصلي بالتشغيل لمعاينة وحفظ التقرير
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'كشف_حساب_$treasuryName.pdf',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          "كشف حساب جاري: $treasuryName",
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white, fontFamily: 'Cairo'),
        ),
        backgroundColor: Colors.indigo[900],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (AppSettings.isDemoMode) _buildDetailsDemoBadge(), 
            Card(
              color: Colors.white,
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey[200]!),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Row(
                  children: [
                    CircleAvatar(radius: 26, backgroundColor: Colors.indigo[50], child: const Icon(Icons.account_balance_rounded, color: Colors.indigo)),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(treasuryName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, fontFamily: 'Cairo')),
                          const SizedBox(height: 4),
                          Text("المعرف الحسابي بالسيرفر: $treasuryId", style: const TextStyle(fontSize: 11, color: Colors.grey, fontFamily: 'monospace')),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            // 🔄 دمج عنوان الدفتر الحركي وزر الطباعة الـ PDF في Row خارجي ثابت ومستقر
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "الدفتر الحركي الجاري (حركات القيد الدائن والمدين اللحظية)",
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blueGrey[800], fontFamily: 'Cairo'),
                ),
                // ⚡ زر الطباعة هنا بشكل آمن وظاهر تماماً ومحمي من الفلوت أو الاختفاء بالويب
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection(transactionsCollection)
                      .where('treasuryId', isEqualTo: treasuryId)
                      .orderBy('createdAt', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                      return ElevatedButton.icon(
                        onPressed: () => _printTreasuryReport(snapshot.data!.docs),
                        icon: const Icon(Icons.print_outlined, size: 16, color: Colors.white),
                        label: const Text(
                          "طباعة كشف الحساب (PDF)", 
                          style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white)
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal[700],
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      );
                    }
                    return const SizedBox();
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                  .collection(transactionsCollection)
                  .where('treasuryId', isEqualTo: treasuryId)
                  .orderBy('createdAt', descending: true)
                  .snapshots()
                  .handleError((error) {
                    debugPrint("============== [رابط الفهرس المحاسبي المركّب] ==============");
                    debugPrint("خطأ لوجستي في الفهرسة: $error");
                    debugPrint("يرجى النقر على الرابط أعلاه لإنشاء الفهرس بالفايربيز وسيعمل الجدول فوراً.");
                    debugPrint("==========================================================");
                  }),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                      child: const Center(
                        child: Text(
                          "لم يتم تسجيل أو رصد أي قيود محاسبية لهذه الخزينة حتى الآن.",
                          style: TextStyle(fontFamily: 'Cairo', fontSize: 13, color: Colors.grey),
                        ),
                      ),
                    );
                  }

                  return Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.vertical,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            headingRowColor: WidgetStateProperty.all(Colors.grey[50]),
                            columns: const [
                              DataColumn(label: Text('رقم المعاملة', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo'))),
                              DataColumn(label: Text('نوع القيد المحاسبي', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo'))),
                              DataColumn(label: Text('الحركة المالية', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo'))),
                              DataColumn(label: Text('الطرف المستلم / المورد', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo'))),
                              DataColumn(label: Text('المستند المرجعي', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo'))),
                              DataColumn(label: Text('التاريخ والوقت بالسيرفر', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo'))),
                            ],
                            rows: snapshot.data!.docs.map((doc) {
                              final data = doc.data() as Map<String, dynamic>;
                              final String txId = data['transactionId'] ?? doc.id;
                              final String type = data['type'] == 'outflow' ? 'دائن / مصروف سائل' : 'مدين / توريد نقدية';
                              final double amount = (data['amount'] ?? 0.0).toDouble();
                              final String partyName = data['partyName'] ?? 'تسوية حسابات داخلية';
                              final String invoice = data['invoiceNumber'] ?? 'بدون ملحق';
                              
                              final Timestamp? createdAt = data['createdAt'] as Timestamp?;
                              final String dateLabel = createdAt != null 
                                  ? "${createdAt.toDate().toLocal().toIso8601String().substring(0, 10)} ${createdAt.toDate().toLocal().toIso8601String().substring(11, 16)}"
                                  : 'جاري التدوين...';

                              return DataRow(cells: [
                                DataCell(Text(txId, style: const TextStyle(fontSize: 12, fontFamily: 'monospace', color: Colors.grey))),
                                DataCell(
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: data['type'] == 'outflow' ? Colors.red[50] : Colors.green[50],
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(type, style: TextStyle(color: data['type'] == 'outflow' ? Colors.red[700] : Colors.green[700], fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
                                  ),
                                ),
                                DataCell(Text("$amount جنيه", style: TextStyle(fontWeight: FontWeight.bold, color: data['type'] == 'outflow' ? Colors.red : Colors.green, fontFamily: 'Cairo'))),
                                DataCell(Text(partyName, style: const TextStyle(fontFamily: 'Cairo', fontSize: 13))),
                                DataCell(Text(invoice, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo, fontSize: 13))),
                                DataCell(Text(dateLabel, style: const TextStyle(fontSize: 12))),
                              ]);
                            }).toList(),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            )
          ],
        ),
      ),
    );
  }
}