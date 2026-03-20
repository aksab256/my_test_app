// lib/screens/reports_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:my_test_app/data_sources/reports_data_source.dart';
import 'package:my_test_app/widgets/report_widgets.dart';

// تعريف حالة شاشة التقرير (Loading, Loaded, Error)
enum ReportStatus { initial, loading, loaded, error, noData }

class ReportsScreen extends StatefulWidget {
  final String sellerId; 

  const ReportsScreen({super.key, required this.sellerId});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final ReportsDataSource _dataSource = ReportsDataSource();
  ReportStatus _status = ReportStatus.initial;
  FullReportData? _reportData;
  String _errorMessage = '';

  // مرشحات التاريخ
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _initializeDateFilters();
    _loadReports();
  }

  void _initializeDateFilters() {
    final now = DateTime.now();
    _startDate = DateTime(now.year, now.month, 1);
    _endDate = DateTime(now.year, now.month + 1, 0);
  }

  Future<void> _loadReports() async {
    if (widget.sellerId.isEmpty) {
      if(mounted) {
        setState(() {
          _status = ReportStatus.error;
          _errorMessage = 'معرّف البائع غير متوفر.';
        });
      }
      return;
    }

    if(mounted) {
      setState(() {
        _status = ReportStatus.loading;
      });
    }

    final endDateExclusive = _endDate.add(const Duration(hours: 23, minutes: 59, seconds: 59));

    try {
      final data = await _dataSource.loadFullReport(
        widget.sellerId,
        _startDate,
        endDateExclusive,
      );

      if(mounted) {
        setState(() {
          _reportData = data;
          _status = ReportStatus.loaded;
        });
      }

    } catch (e) {
      if(mounted) {
        setState(() {
          if (e.toString().contains('No orders found')) {
            _status = ReportStatus.noData;
          } else {
            _status = ReportStatus.error;
            _errorMessage = 'حدث خطأ أثناء تحميل التقارير: ${e.toString().split(':').last.trim()}';
          }
        });
      }
    }
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final initialDate = isStartDate ? _startDate : _endDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    
    if (!mounted) return;

    if (picked != null) {
      if (isStartDate) {
        if (picked.isAfter(_endDate)) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تاريخ البداية يجب أن يكون قبل تاريخ النهاية.')),
          );
          return;
        }
        _startDate = picked;
      } else {
        if (picked.isBefore(_startDate)) {
          if (!mounted) return; 
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تاريخ النهاية يجب أن يكون بعد تاريخ البداية.')),
          );
          return;
        }
        _endDate = picked;
      }
      _loadReports();
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تقارير المبيعات', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: ChartColors.primary,
        foregroundColor: Colors.white,
        // تم تفعيل السهم للرجوع بما أننا ألغينا الـ BottomNavBar (إلا لو كنت بتفتحه من Drawer)
        automaticallyImplyLeading: true, 
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildDateFilter(),
            const SizedBox(height: 20),
            _buildBodyContent(),
          ],
        ),
      ),
    );
  }

  Widget _buildDateFilter() {
    final dateFormat = DateFormat('yyyy/MM/dd');

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(15.0),
        child: Wrap(
          spacing: 15,
          runSpacing: 10,
          alignment: WrapAlignment.center,
          children: [
            _buildDateInput('من:', _startDate, true, dateFormat),
            _buildDateInput('إلى:', _endDate, false, dateFormat),
            ElevatedButton(
              onPressed: _loadReports,
              style: ElevatedButton.styleFrom(
                backgroundColor: ChartColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              child: const Text('تطبيق', style: TextStyle(fontFamily: 'Cairo')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateInput(String label, DateTime date, bool isStartDate, DateFormat dateFormat) {
    return InkWell(
      onTap: () => _selectDate(context, isStartDate),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.calendar_month, size: 18, color: ChartColors.primary),
            const SizedBox(width: 8),
            Text(
              dateFormat.format(date),
              style: const TextStyle(color: ChartColors.primary, fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(fontFamily: 'Cairo')),
          ],
        ),
      ),
    );
  }

  Widget _buildBodyContent() {
    switch (_status) {
      case ReportStatus.loading:
        return const Center(child: Padding(
          padding: EdgeInsets.all(50.0),
          child: CircularProgressIndicator(color: ChartColors.primary),
        ));

      case ReportStatus.error:
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(50.0),
            child: Text(
              'خطأ في التحميل: $_errorMessage',
              textAlign: TextAlign.center,
              style: const TextStyle(color: ChartColors.danger, fontSize: 16, fontFamily: 'Cairo'),
            ),
          ),
        );

      case ReportStatus.noData:
        return const Center(
          child: Padding(
            padding: EdgeInsets.all(50.0),
            child: Text(
              'لا توجد بيانات متاحة في الفترة المحددة.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 16, fontFamily: 'Cairo'),
            ),
          ),
        );

      case ReportStatus.loaded:
        if (_reportData == null) return const SizedBox.shrink();
        return Column(
          children: [
            StatsCardsGrid(overview: _reportData!.overview),
            const SizedBox(height: 20),
            Wrap(
              spacing: 20,
              runSpacing: 20,
              alignment: WrapAlignment.center,
              children: [
                SizedBox(
                  width: 350,
                  child: ChartFrame(chart: OrdersStatusChart(report: _reportData!.statusReport)),
                ),
                SizedBox(
                  width: 350,
                  child: ChartFrame(chart: MonthlySalesChart(report: _reportData!.monthlySales)),
                ),
              ],
            ),
            const SizedBox(height: 20),
            TopProductsTable(products: _reportData!.topProducts),
          ],
        );

      case ReportStatus.initial:
      default:
        return const SizedBox.shrink();
    }
  }
}
