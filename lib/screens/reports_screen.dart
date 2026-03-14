// screens/reports_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:provider/provider.dart';
import '../providers/attendance_provider.dart';
import '../utils/app_theme.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  late DateTime _selectedMonth;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = DateTime(now.year, now.month);
  }

  void _prevMonth() => setState(
    () => _selectedMonth = DateTime(
      _selectedMonth.year,
      _selectedMonth.month - 1,
    ),
  );

  void _nextMonth() {
    final now = DateTime.now();
    final next = DateTime(_selectedMonth.year, _selectedMonth.month + 1);
    if (next.isBefore(DateTime(now.year, now.month + 1))) {
      setState(() => _selectedMonth = next);
    }
  }

  bool get _isCurrentMonth {
    final now = DateTime.now();
    return _selectedMonth.year == now.year && _selectedMonth.month == now.month;
  }

  String _monthLabel() => DateFormat('MMMM yyyy', 'ar').format(_selectedMonth);

  String _formatLate(int mins) {
    if (mins <= 0) return '—';
    if (mins < 60) return '$minsد';
    final h = mins ~/ 60;
    final m = mins % 60;
    return m == 0 ? '$hس' : '$hس $mد';
  }

  Future<void> _exportPdf(Map<String, EmployeeStat> stats) async {
    try {
      // Safely load Arabic fonts from assets
      final regularData = await DefaultAssetBundle.of(context).load('assets/fonts/Cairo-Regular.ttf');
      final boldData = await DefaultAssetBundle.of(context).load('assets/fonts/Cairo-Bold.ttf');
      
      final arabicFont = pw.Font.ttf(regularData);
      final arabicFontBold = pw.Font.ttf(boldData);

      final pdf = pw.Document();
      final rows = stats.values.toList()
        ..sort((a, b) => b.total.compareTo(a.total));

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          textDirection: pw.TextDirection.rtl,
          build: (ctx) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              // Header
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#7C3AED'),
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Column(
                  children: [
                    pw.Text(
                      'تقرير الحضور والانصراف',
                      style: pw.TextStyle(
                        font: arabicFontBold,
                        fontSize: 20,
                        color: PdfColors.white,
                      ),
                      textDirection: pw.TextDirection.rtl,
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      _monthLabel(),
                      style: pw.TextStyle(
                        font: arabicFont,
                        fontSize: 13,
                        color: PdfColors.grey200,
                      ),
                      textDirection: pw.TextDirection.rtl,
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),
              // Table
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                columnWidths: {
                  0: const pw.FlexColumnWidth(3),
                  1: const pw.FlexColumnWidth(1.5),
                  2: const pw.FlexColumnWidth(1.5),
                  3: const pw.FlexColumnWidth(1.5),
                  4: const pw.FlexColumnWidth(2),
                },
                children: [
                  // Table header
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(
                      color: PdfColor.fromInt(0xFF1E1B4B),
                    ),
                    children: ['الموظف', 'حضور', 'تأخير', 'غياب', 'إجمالي التأخير']
                        .map(
                          (h) => pw.Padding(
                            padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                            child: pw.Text(
                              h,
                              style: pw.TextStyle(font: arabicFontBold, fontSize: 11, color: PdfColors.white),
                              textDirection: pw.TextDirection.rtl,
                              textAlign: pw.TextAlign.center,
                            ),
                          ),
                        )
                        .toList(),
                  ),
                  // Data rows
                  ...rows.asMap().entries.map((entry) {
                    final i = entry.key;
                    final s = entry.value;
                    final bg = i.isEven ? PdfColors.white : const PdfColor.fromInt(0xFFF5F3FF);
                    return pw.TableRow(
                      decoration: pw.BoxDecoration(color: bg),
                      children: [
                        s.name,
                        '${s.present}',
                        '${s.late}',
                        '${s.absent}',
                        _formatLate(s.totalLateMinutes),
                      ]
                          .map(
                            (val) => pw.Padding(
                              padding: const pw.EdgeInsets.symmetric(vertical: 7, horizontal: 6),
                              child: pw.Text(
                                val,
                                style: pw.TextStyle(font: arabicFont, fontSize: 11),
                                textDirection: pw.TextDirection.rtl,
                                textAlign: pw.TextAlign.center,
                              ),
                            ),
                          )
                          .toList(),
                    );
                  }),
                ],
              ),
              pw.SizedBox(height: 16),
              pw.Text(
                'تم إنشاء التقرير بتاريخ: ${DateFormat('yyyy-MM-dd – hh:mm a', 'ar').format(DateTime.now())}',
                style: pw.TextStyle(font: arabicFont, fontSize: 9, color: PdfColors.grey),
                textDirection: pw.TextDirection.rtl,
              ),
            ],
          ),
        ),
      );

      if (!mounted) return;
      
      // Use layoutPdf instead of sharePdf for maximum reliability cross-platform
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name: 'تقرير_${_monthLabel()}.pdf',
      );
      
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطأ في إنشاء PDF: ${e.toString()}', textAlign: TextAlign.center),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AttendanceProvider>();
    final stats = provider.reportForMonth(
      _selectedMonth.year,
      _selectedMonth.month,
    );
    final rows = stats.values.toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    return Column(
      children: [
        // Month picker
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AppTheme.cardColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.primaryColor.withAlpha(80)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.white70,
                ),
                onPressed: _prevMonth,
              ),
              Text(
                _monthLabel(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.chevron_left_rounded,
                  color: _isCurrentMonth ? Colors.white24 : Colors.white70,
                ),
                onPressed: _isCurrentMonth ? null : _nextMonth,
              ),
            ],
          ),
        ),

        // Export button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: ElevatedButton.icon(
            onPressed: stats.isEmpty ? null : () => _exportPdf(stats),
            icon: const Icon(
              Icons.picture_as_pdf_rounded,
              color: Colors.white,
              size: 20,
            ),
            label: const Text(
              'تصدير PDF',
              style: TextStyle(color: Colors.white, fontSize: 14),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Summary totals row
        if (rows.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _SummaryChip(
                  label: 'أيام حضور',
                  count: rows.fold(0, (s, e) => s + e.present),
                  color: Colors.green,
                ),
                const SizedBox(width: 8),
                _SummaryChip(
                  label: 'تأخيرات',
                  count: rows.fold(0, (s, e) => s + e.late),
                  color: Colors.orange,
                ),
                const SizedBox(width: 8),
                _SummaryChip(
                  label: 'غيابات',
                  count: rows.fold(0, (s, e) => s + e.absent),
                  color: Colors.red,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Table & Chart Scrollable Area
        Expanded(
          child: rows.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.bar_chart_rounded,
                        color: Colors.white24,
                        size: 64,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'لا توجد بيانات لهذا الشهر',
                        style: TextStyle(color: Colors.white38),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  child: Column(
                    children: [
                      // 📊 Monthly Comparison Bar Chart
                      _buildEmployeesChart(rows),
                      
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Column(
                          children: rows
                              .map(
                                (s) =>
                                    _EmployeeStatCard(s: s, formatLate: _formatLate),
                              )
                              .toList(),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildEmployeesChart(List<EmployeeStat> rows) {
    // Only show up to 8 employees to avoid layout squeezing, sorted by total attendance
    final topRows = rows.take(8).toList();
    if (topRows.isEmpty) return const SizedBox.shrink();

    return Container(
      height: 220,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.only(top: 16, right: 16, left: 8, bottom: 8),
      decoration: BoxDecoration(color: AppTheme.cardColor, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('مقارنة أداء الموظفين', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 16),
          Expanded(
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: (topRows.map((e) => e.total).reduce((a, b) => a > b ? a : b) + 2).toDouble(),
                barTouchData: BarTouchData(enabled: false),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (double value, TitleMeta meta) {
                        if (value.toInt() >= topRows.length) return const SizedBox.shrink();
                        final name = topRows[value.toInt()].name;
                        final shortName = name.split(' ').first;
                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(shortName, style: const TextStyle(color: Colors.white54, fontSize: 10), overflow: TextOverflow.ellipsis),
                        );
                      },
                      reservedSize: 28,
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      getTitlesWidget: (value, meta) {
                        if (value == 0) return const SizedBox.shrink();
                        return Text(value.toInt().toString(), style: const TextStyle(color: Colors.white38, fontSize: 10));
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) => FlLine(color: Colors.white10, strokeWidth: 1),
                ),
                borderData: FlBorderData(show: false),
                barGroups: topRows.asMap().entries.map((e) {
                  final index = e.key;
                  final stat = e.value;
                  return BarChartGroupData(
                    x: index,
                    barRods: [
                      BarChartRodData(
                        toY: stat.present.toDouble(),
                        color: Colors.green,
                        width: 6,
                        borderRadius: BorderRadius.circular(2),
                      ),
                      BarChartRodData(
                        toY: stat.late.toDouble(),
                        color: Colors.orange,
                        width: 6,
                        borderRadius: BorderRadius.circular(2),
                      ),
                      BarChartRodData(
                        toY: stat.absent.toDouble(),
                        color: Colors.red,
                        width: 6,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _Legend(color: Colors.green, text: 'حاضر'),
              const SizedBox(width: 12),
              _Legend(color: Colors.orange, text: 'متأخر'),
              const SizedBox(width: 12),
              _Legend(color: Colors.red, text: 'غائب'),
            ],
          )
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String text;
  const _Legend({required this.color, required this.text});
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(color: Colors.white54, fontSize: 10)),
      ],
    );
  }
}

// ─────────────────────────────────────────────
class _SummaryChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  const _SummaryChip({
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withAlpha(30),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withAlpha(80)),
        ),
        child: Column(
          children: [
            Text(
              '$count',
              style: TextStyle(
                color: color,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label,
              style: TextStyle(color: color.withAlpha(180), fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
class _EmployeeStatCard extends StatelessWidget {
  final EmployeeStat s;
  final String Function(int) formatLate;
  const _EmployeeStatCard({required this.s, required this.formatLate});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Name + total
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: AppTheme.primaryColor.withAlpha(50),
                child: Text(
                  s.name.isNotEmpty ? s.name[0] : '؟',
                  style: const TextStyle(
                    color: AppTheme.primaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  s.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.white12,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${s.total} يوم',
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Stats
          Row(
            children: [
              _StatCell(
                label: 'حضور',
                value: '${s.present}',
                color: Colors.green,
              ),
              _StatCell(
                label: 'تأخير',
                value: '${s.late}',
                color: Colors.orange,
              ),
              _StatCell(label: 'غياب', value: '${s.absent}', color: Colors.red),
              _StatCell(
                label: 'إجمالي التأخير',
                value: formatLate(s.totalLateMinutes),
                color: Colors.blue,
              ),
            ],
          ),
          // Late bar
          if (s.total > 0) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Row(
                children: [
                  if (s.present > 0)
                    Flexible(
                      flex: s.present,
                      child: Container(height: 5, color: Colors.green),
                    ),
                  if (s.late > 0)
                    Flexible(
                      flex: s.late,
                      child: Container(height: 5, color: Colors.orange),
                    ),
                  if (s.absent > 0)
                    Flexible(
                      flex: s.absent,
                      child: Container(height: 5, color: Colors.red),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatCell({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          Text(
            label,
            style: TextStyle(color: color.withAlpha(160), fontSize: 10),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
