// lib/widgets/report_widgets.dart

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:my_test_app/data_sources/reports_data_source.dart'; // استيراد نماذج البيانات

// ⭐️ تعريف الألوان الثابتة (مثلما كانت في CSS) ⭐️
class ChartColors {
  static const Color primary = Color(0xFF28a745);
  static const Color secondary = Color(0xFF007bff);
  static const Color success = Color(0xFF28a745);
  static const Color danger = Color(0xFFdc3545);
  static const Color warning = Color(0xFFffc107);
  static const Color info = Color(0xFF17a2b8);

  // الألوان المستخدمة في الـ Doughnut Chart (Status)
  static const List<Color> statusColors = [
    info, // New Order
    secondary, // Processing
    warning, // Shipped
    success, // Delivered
    danger, // Cancelled
  ];
}


// --- 1. بطاقات الإحصائيات (Stats Cards) ---
class StatsCardsGrid extends StatelessWidget {
  final SalesOverview overview;

  const StatsCardsGrid({super.key, required this.overview});

  @override
  Widget build(BuildContext context) {
    // ⭐️ يفضل استخدام locale معين لضمان تنسيق الأرقام ⭐️
    final format = NumberFormat.currency(locale: 'ar_EG', symbol: 'جنيه');

    final cardsData = [
      {'title': 'إجمالي المبيعات', 'value': format.format(overview.totalSales), 'color': ChartColors.success, 'icon': Icons.attach_money},
      {'title': 'إجمالي الطلبات', 'value': overview.totalOrders.toString(), 'color': ChartColors.secondary, 'icon': Icons.shopping_cart},
      {'title': 'المنتجات المباعة', 'value': overview.productsSold.toString(), 'color': ChartColors.warning, 'icon': Icons.inventory_2},
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: cardsData.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: MediaQuery.of(context).size.width > 768 ? 3 : 2, // 3 أعمدة على شاشات كبيرة، 2 على صغيرة
        crossAxisSpacing: 20,
        mainAxisSpacing: 20,
        childAspectRatio: 1.5,
      ),
      itemBuilder: (context, index) {
        final card = cardsData[index];
        return StatCard(
          title: card['title'] as String,
          value: card['value'] as String,
          color: card['color'] as Color,
        );
      },
    );
  }
}

class StatCard extends StatelessWidget {
  final String title;
  final String value;
  final Color color;

  const StatCard({super.key, required this.title, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color, width: 4), // Border bottom effect
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF6c757d), // text-light
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.right,
            ),
            const SizedBox(height: 8),
            Text(
              value,
              // تم إزالة textDirection: TextDirection.ltr للاعتماد على الاتجاه الموروث
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              textAlign: TextAlign.right,
            ),
          ],
        ),
      ),
    );
  }
}

// --- 2. رسم بياني حالة الطلبات (Doughnut Chart) ---
class OrdersStatusChart extends StatelessWidget {
  final StatusReport report;

  const OrdersStatusChart({super.key, required this.report});

  @override
  Widget build(BuildContext context) {
    // فلترة البيانات الصفرية لتجنب ظهورها في الأسطورة
    final validData = <PieChartSectionData>[];
    for (int i = 0; i < report.labels.length; i++) {
      if (report.counts[i] > 0) {
        validData.add(
          PieChartSectionData(
            color: ChartColors.statusColors[i % ChartColors.statusColors.length],
            value: report.counts[i].toDouble(),
            title: '${report.counts[i]}',
            radius: 70,
            titleStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        );
      }
    }

    // بناء الليجند (Legend) يدوياً 
    final legend = <Widget>[];
    for (int i = 0; i < report.labels.length; i++) {
        if (report.counts[i] > 0) {
            legend.add(
                Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                        // ترتيب العناصر في RTL: [مربع اللون] [مسافة] [التسمية] [مسافة]
                        Container(
                            width: 10,
                            height: 10,
                            color: ChartColors.statusColors[i % ChartColors.statusColors.length],
                        ),
                        const SizedBox(width: 5),
                        Text(
                            report.labels[i],
                            style: const TextStyle(fontSize: 12, color: Color(0xFF343a40)),
                        ),
                        const SizedBox(width: 10),
                    ],
                )
            );
        }
    }

    // تم إزالة Directionality والاعتماد على الاتجاه العام
    return AspectRatio(
      aspectRatio: 1.5,
      child: Column(
        children: [
          const Text(
            'حالة الطلبات',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFF343a40)),
          ),
          const SizedBox(height: 15),
          Expanded(
            child: validData.isEmpty
                ? const Center(child: Text('لا توجد بيانات حالة لعرضها'))
                : PieChart(
                    PieChartData(
                      sections: validData,
                      sectionsSpace: 2,
                      centerSpaceRadius: 40, // لإعطائه شكل الدونات (Doughnut)
                      borderData: FlBorderData(show: false),
                    ),
                  ), // ⭐️ تم التأكد من إغلاق القوس هنا ⭐️
          ), // ⭐️ وتم التأكد من إغلاق القوس هنا ⭐️
          const SizedBox(height: 15),
          Wrap(
              alignment: WrapAlignment.center,
              spacing: 10,
              runSpacing: 5,
              children: legend,
          ),
        ],
      ),
    );
  }
}


// --- 3. رسم بياني المبيعات الشهرية (Bar Chart) ---
class MonthlySalesChart extends StatelessWidget {
  final MonthlySales report;

  const MonthlySalesChart({super.key, required this.report});

  @override
  Widget build(BuildContext context) {
    if (report.sales.isEmpty) {
      return const Center(child: Text('لا توجد بيانات مبيعات شهرية لعرضها.'));
    }

    final maxSales = report.sales.reduce((a, b) => a > b ? a : b);
    final salesFormat = NumberFormat('#,##0', 'ar_EG');

    // تم إزالة Directionality والاعتماد على الاتجاه العام
    return AspectRatio(
      aspectRatio: 1.5,
      child: Column(
        children: [
          const Text(
            'المبيعات الشهرية',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFF343a40)),
          ),
          const SizedBox(height: 15),
          Expanded(
            child: BarChart(
              BarChartData(
                barGroups: List.generate(report.labels.length, (i) {
                  return BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: report.sales[i],
                        color: ChartColors.primary.withOpacity(0.8), // 80% opacity
                        width: 20,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ],
                  );
                }),
                borderData: FlBorderData(
                  show: true,
                  border: const Border(
                    bottom: BorderSide(color: Color(0xFFe9ecef), width: 1),
                    left: BorderSide(color: Color(0xFFe9ecef), width: 1),
                  ),
                ),
                gridData: const FlGridData(show: false),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) => Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          report.labels[value.toInt()],
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500),
                          // تم إزالة textDirection: TextDirection.rtl
                        ),
                      ),
                      interval: 1,
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) => Text(
                        salesFormat.format(value.toInt()),
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                        // تم إزالة textDirection: TextDirection.rtl
                      ),
                      reservedSize: 45,
                      interval: (maxSales / 4).ceilToDouble(), // تقسيم المحور لـ 4 فترات تقريباً
                    ),
                  ),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                alignment: BarChartAlignment.spaceAround,
                maxY: maxSales * 1.15, // إضافة 15% مساحة فوق أكبر قيمة
              ),
            ),
          ),
        ],
      ),
    );
  }
}


// --- 4. جدول المنتجات الأكثر مبيعاً (Top Selling Products Table) ---
class TopProductsTable extends StatelessWidget {
  final List<TopProduct> products;

  const TopProductsTable({super.key, required this.products});

  @override
  Widget build(BuildContext context) {
    // تنسيق العملات ليظهر LTR داخل السياق RTL
    final currencyFormat = NumberFormat.currency(locale: 'ar_EG', symbol: 'جنيه');

    return Card(
      elevation: 5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(15.0),
        // تم إزالة Directionality والاعتماد على الاتجاه العام
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'المنتجات الأكثر مبيعاً',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFF343a40)),
            ),
            const SizedBox(height: 15),
            products.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(30.0),
                      child: Text(
                        'لا توجد منتجات مباعة في الفترة المحددة.',
                        style: TextStyle(color: Color(0xFF6c757d)),
                      ),
                    ),
                  )
                : DataTable(
                    columnSpacing: 20,
                    dataRowMinHeight: 45,
                    dataRowMaxHeight: 55,
                    columns: const [
                      DataColumn(label: Text('المنتج', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('الكمية المباعة', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                      DataColumn(label: Text('إجمالي المبيعات', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                    ],
                    rows: products.map((product) {
                      return DataRow(
                        cells: [
                          DataCell(Text(product.name)),
                          DataCell(Text(product.quantity.toString())),
                          DataCell(Text(
                            currencyFormat.format(product.totalSales),
                            // تم إزالة textDirection: TextDirection.ltr
                          )),
                        ],
                      );
                    }).toList(),
                  ),
          ],
        ),
      ),
    );
  }
}

// --- 5. ويدجت إطار الرسوم البيانية (Chart Frame) ---
class ChartFrame extends StatelessWidget {
  final Widget chart;

  const ChartFrame({super.key, required this.chart});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(15.0),
        child: SizedBox(
          height: 350,
          child: chart,
        ),
      ),
    );
  }
}

