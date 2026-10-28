import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/themes/app_sizes.dart';
import '../../../core/utilities/currency_formatter.dart';
import '../../../core/utilities/date_time_formatter.dart';
import '../../../domain/entities/transaction_entity.dart';
import '../../providers/transactions/transactions_notifier.dart';
import '../../widgets/app_progress_indicator.dart';
import '../../widgets/app_snack_bar.dart';

enum ReportPeriod { today, last7Days, thisMonth, allTime, custom }

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  ReportPeriod _selectedPeriod = ReportPeriod.today;
  DateTimeRange? _customDateRange;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(transactionsNotifierProvider.notifier).getAllTransactions();
    });
  }

  String _formatDate(DateTime d) {
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  String _getPeriodTitle(ReportPeriod period) {
    return switch (period) {
      ReportPeriod.today => 'Hari Ini',
      ReportPeriod.last7Days => '7 Hari Terakhir',
      ReportPeriod.thisMonth => 'Bulan Ini',
      ReportPeriod.allTime => 'Semua Waktu',
      ReportPeriod.custom => _customDateRange != null
          ? '${_formatDate(_customDateRange!.start)} - ${_formatDate(_customDateRange!.end)}'
          : 'Pilih Tanggal',
    };
  }

  List<TransactionEntity> _filterTransactions(List<TransactionEntity> transactions) {
    final now = DateTime.now();

    return transactions.where((t) {
      if (t.createdAt == null) return false;
      final date = DateTime.tryParse(t.createdAt!);
      if (date == null) return false;

      return switch (_selectedPeriod) {
        ReportPeriod.today =>
          date.year == now.year && date.month == now.month && date.day == now.day,
        ReportPeriod.last7Days =>
          now.difference(date).inDays <= 7 && date.isBefore(now.add(const Duration(days: 1))),
        ReportPeriod.thisMonth =>
          date.year == now.year && date.month == now.month,
        ReportPeriod.allTime => true,
        ReportPeriod.custom => _customDateRange != null &&
            !date.isBefore(DateTime(_customDateRange!.start.year, _customDateRange!.start.month, _customDateRange!.start.day, 0, 0, 0)) &&
            !date.isAfter(DateTime(_customDateRange!.end.year, _customDateRange!.end.month, _customDateRange!.end.day, 23, 59, 59)),
      };
    }).toList();
  }

  Future<void> _pickCustomDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: now.add(const Duration(days: 365)),
      initialDateRange: _customDateRange ??
          DateTimeRange(
            start: now.subtract(const Duration(days: 7)),
            end: now,
          ),
      helpText: 'Pilih Rentang Tanggal Rekap Penjualan',
      saveText: 'Terapkan',
    );

    if (picked != null) {
      setState(() {
        _customDateRange = picked;
        _selectedPeriod = ReportPeriod.custom;
      });
    }
  }

  Future<void> _exportReportPdf({
    required String periodTitle,
    required List<TransactionEntity> transactions,
    required int totalSales,
    required int totalItemsSold,
    required int aov,
    required Map<String, int> paymentBreakdown,
    required Map<String, int> channelBreakdown,
    required List<MapEntry<String, int>> topProducts,
  }) async {
    if (transactions.isEmpty) {
      AppSnackBar.showError('Tidak ada data transaksi untuk diekspor ke PDF');
      return;
    }

    try {
      final pdf = pw.Document();
      final nowFormatted = DateTimeFormatter.stripDateWithClock(
        DateTime.now().toIso8601String(),
      );

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          header: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'WARUNG LAKKU POS',
                          style: pw.TextStyle(
                            fontSize: 18,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.indigo900,
                          ),
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          'Laporan Rekap Penjualan',
                          style: pw.TextStyle(
                            fontSize: 12,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.grey700,
                          ),
                        ),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          'Periode: $periodTitle',
                          style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          'Dibuat: $nowFormatted',
                          style: const pw.TextStyle(
                            fontSize: 9,
                            color: PdfColors.grey600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                pw.SizedBox(height: 6),
                pw.Divider(thickness: 1.5, color: PdfColors.indigo900),
                pw.SizedBox(height: 10),
              ],
            );
          },
          footer: (pw.Context context) {
            return pw.Container(
              alignment: pw.Alignment.centerRight,
              margin: const pw.EdgeInsets.only(top: 14),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Warung Lakku POS - Laporan Rekap Penjualan Resmi',
                    style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
                  ),
                  pw.Text(
                    'Halaman ${context.pageNumber} dari ${context.pagesCount}',
                    style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
                  ),
                ],
              ),
            );
          },
          build: (pw.Context context) {
            return [
              // Summary KPI Box
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                decoration: pw.BoxDecoration(
                  color: PdfColors.indigo50,
                  borderRadius: pw.BorderRadius.circular(6),
                  border: pw.Border.all(color: PdfColors.indigo200),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                  children: [
                    _buildPdfKpi('TOTAL OMZET', CurrencyFormatter.format(totalSales)),
                    _buildPdfKpi('TOTAL TRANSAKSI', '${transactions.length} Trx'),
                    _buildPdfKpi('RATA-RATA ORDER', CurrencyFormatter.format(aov)),
                    _buildPdfKpi('PRODUK TERJUAL', '$totalItemsSold Pcs'),
                  ],
                ),
              ),
              pw.SizedBox(height: 16),

              // Payment & Channel Breakdown
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Payment Table
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'Metode Pembayaran',
                          style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800),
                        ),
                        pw.SizedBox(height: 4),
                        pw.TableHelper.fromTextArray(
                          border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                          headerStyle: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                          headerDecoration: const pw.BoxDecoration(color: PdfColors.indigo700),
                          cellStyle: const pw.TextStyle(fontSize: 8),
                          cellPadding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 6),
                          headers: ['Metode', 'Omzet', '%'],
                          data: paymentBreakdown.entries.map((e) {
                            final pct = totalSales > 0 ? (e.value / totalSales * 100).toStringAsFixed(1) : '0';
                            return [e.key.toUpperCase(), CurrencyFormatter.format(e.value), '$pct%'];
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                  pw.SizedBox(width: 14),
                  // Channel Table
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'Saluran Penjualan',
                          style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800),
                        ),
                        pw.SizedBox(height: 4),
                        pw.TableHelper.fromTextArray(
                          border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                          headerStyle: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                          headerDecoration: const pw.BoxDecoration(color: PdfColors.indigo700),
                          cellStyle: const pw.TextStyle(fontSize: 8),
                          cellPadding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 6),
                          headers: ['Saluran', 'Omzet', '%'],
                          data: channelBreakdown.entries.map((e) {
                            final pct = totalSales > 0 ? (e.value / totalSales * 100).toStringAsFixed(1) : '0';
                            return [e.key.toUpperCase(), CurrencyFormatter.format(e.value), '$pct%'];
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 16),

              // Top Products Table
              if (topProducts.isNotEmpty) ...[
                pw.Text(
                  'Produk Terlaris (Top Ranking)',
                  style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800),
                ),
                pw.SizedBox(height: 4),
                pw.TableHelper.fromTextArray(
                  border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                  headerStyle: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                  headerDecoration: const pw.BoxDecoration(color: PdfColors.indigo700),
                  cellStyle: const pw.TextStyle(fontSize: 8),
                  cellPadding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 6),
                  headers: ['No', 'Nama Produk', 'Jumlah Terjual (Pcs)'],
                  data: [
                    for (int i = 0; i < topProducts.length && i < 10; i++)
                      [(i + 1).toString(), topProducts[i].key, '${topProducts[i].value} pcs'],
                  ],
                ),
                pw.SizedBox(height: 16),
              ],

              // Transactions Table
              pw.Text(
                'Daftar Transaksi Periode (${transactions.length} transaksi)',
                style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800),
              ),
              pw.SizedBox(height: 4),
              pw.TableHelper.fromTextArray(
                border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                headerStyle: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.indigo700),
                cellStyle: const pw.TextStyle(fontSize: 7.5),
                cellPadding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 5),
                headers: ['No', 'ID Transaksi', 'Waktu', 'Pelanggan', 'Saluran', 'Metode', 'Total Omzet'],
                data: [
                  for (int i = 0; i < transactions.length; i++)
                    [
                      (i + 1).toString(),
                      '#${transactions[i].id}',
                      DateTimeFormatter.stripDateWithClock(transactions[i].createdAt ?? ''),
                      transactions[i].customerName ?? '-',
                      transactions[i].channel.toUpperCase(),
                      transactions[i].paymentMethod.toUpperCase(),
                      CurrencyFormatter.format(transactions[i].totalAmount),
                    ],
                ],
              ),
            ];
          },
        ),
      );

      final dir = await getApplicationDocumentsDirectory();
      final sanitizedTitle = periodTitle.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
      final fileName = 'Rekap_Penjualan_${sanitizedTitle}_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(await pdf.save());

      if (!mounted) return;

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Row(
            children: const [
              Icon(Icons.picture_as_pdf_rounded, color: Colors.red),
              SizedBox(width: 8),
              Text('Export PDF Selesai'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Laporan periode $periodTitle berhasil diekspor ke PDF (${transactions.length} transaksi).'),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: SelectableText(file.path, style: const TextStyle(fontSize: 11, fontFamily: 'monospace')),
              ),
            ],
          ),
          actions: [
            OutlinedButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: file.path));
                AppSnackBar.show('Path file PDF disalin ke clipboard');
              },
              child: const Text('Salin Path'),
            ),
            FilledButton.icon(
              onPressed: () async {
                Navigator.pop(ctx);
                final openResult = await OpenFilex.open(file.path);
                if (openResult.type != ResultType.done) {
                  AppSnackBar.showError('Tidak dapat membuka file: ${openResult.message}');
                }
              },
              icon: const Icon(Icons.open_in_new_rounded, size: 16),
              label: const Text('Buka PDF'),
            ),
          ],
        ),
      );
    } catch (e) {
      AppSnackBar.showError('Gagal membuat file PDF: $e');
    }
  }

  pw.Widget _buildPdfKpi(String title, String value) {
    return pw.Column(
      children: [
        pw.Text(
          title,
          style: const pw.TextStyle(
            fontSize: 7.5,
            color: PdfColors.indigo900,
          ),
        ),
        pw.SizedBox(height: 3),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 10,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.indigo900,
          ),
        ),
      ],
    );
  }

  void _exportReportCsv(List<TransactionEntity> transactions, String periodTitle) async {
    if (transactions.isEmpty) {
      AppSnackBar.showError('Tidak ada data transaksi untuk diekspor');
      return;
    }

    final buffer = StringBuffer();
    buffer.writeln('id,createdAt,channel,paymentMethod,customerName,totalAmount,receivedAmount,returnAmount,description');

    for (final t in transactions) {
      final id = t.id?.toString() ?? '';
      final createdAt = t.createdAt ?? '';
      final channel = t.channel;
      final paymentMethod = t.paymentMethod;
      final customer = (t.customerName ?? '').replaceAll('"', '""');
      final total = t.totalAmount.toString();
      final received = t.receivedAmount.toString();
      final change = t.returnAmount.toString();
      final desc = (t.description ?? '').replaceAll('"', '""');

      buffer.writeln('$id,$createdAt,$channel,$paymentMethod,"$customer",$total,$received,$change,"$desc"');
    }

    final csvContent = buffer.toString();
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/laporan_transaksi_${DateTime.now().millisecondsSinceEpoch}.csv');
    await file.writeAsString(csvContent);

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Export Laporan CSV'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Laporan periode $periodTitle berhasil diekspor (${transactions.length} transaksi).'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(6),
              ),
              child: SelectableText(file.path, style: const TextStyle(fontSize: 11, fontFamily: 'monospace')),
            ),
          ],
        ),
        actions: [
          OutlinedButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: csvContent));
              AppSnackBar.show('Data CSV disalin ke clipboard');
            },
            child: const Text('Salin CSV'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final transactionsState = ref.watch(transactionsNotifierProvider);
    final allTransactions = transactionsState.allTransactions;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Laporan Hasil Penjualan'),
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range_rounded),
            tooltip: 'Pilih Rentang Tanggal',
            onPressed: _pickCustomDateRange,
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Segarkan Data',
            onPressed: () => ref.read(transactionsNotifierProvider.notifier).getAllTransactions(),
          ),
        ],
      ),
      body: allTransactions == null
          ? const AppProgressIndicator()
          : RefreshIndicator(
              onRefresh: () => ref.read(transactionsNotifierProvider.notifier).getAllTransactions(),
              child: _buildBody(allTransactions),
            ),
    );
  }

  Widget _buildBody(List<TransactionEntity> allTransactions) {
    final filteredTransactions = _filterTransactions(allTransactions);

    int totalSales = 0;
    int totalItemsSold = 0;
    final Map<String, int> paymentBreakdown = {};
    final Map<String, int> channelBreakdown = {};
    final Map<String, int> productQtyMap = {};

    for (final t in filteredTransactions) {
      totalSales += t.totalAmount;

      final method = t.paymentMethod.toLowerCase();
      paymentBreakdown[method] = (paymentBreakdown[method] ?? 0) + t.totalAmount;

      final ch = t.channel.toLowerCase();
      channelBreakdown[ch] = (channelBreakdown[ch] ?? 0) + t.totalAmount;

      if (t.orderedProducts != null) {
        for (final p in t.orderedProducts!) {
          totalItemsSold += p.quantity;
          productQtyMap[p.name] = (productQtyMap[p.name] ?? 0) + p.quantity;
        }
      }
    }

    final topProducts = productQtyMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final aov = filteredTransactions.isNotEmpty
        ? (totalSales / filteredTransactions.length).round()
        : 0;

    final periodTitle = _getPeriodTitle(_selectedPeriod);

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSizes.padding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Filter Chips: Quick periods + Custom Range
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ...ReportPeriod.values.where((p) => p != ReportPeriod.custom).map((period) {
                  final isSelected = _selectedPeriod == period;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(_getPeriodTitle(period)),
                      selected: isSelected,
                      onSelected: (val) {
                        if (val) setState(() => _selectedPeriod = period);
                      },
                    ),
                  );
                }),
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    avatar: const Icon(Icons.date_range_rounded, size: 16),
                    label: Text(
                      _selectedPeriod == ReportPeriod.custom
                          ? _getPeriodTitle(ReportPeriod.custom)
                          : 'Rentang Tanggal',
                    ),
                    selected: _selectedPeriod == ReportPeriod.custom,
                    onSelected: (_) => _pickCustomDateRange(),
                  ),
                ),
              ],
            ),
          ),
          if (_selectedPeriod == ReportPeriod.custom && _customDateRange != null) ...[
            const SizedBox(height: 8),
            InkWell(
              onTap: _pickCustomDateRange,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_month_rounded, size: 18, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Filter Aktif: ${_getPeriodTitle(ReportPeriod.custom)}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                    Text(
                      'Ubah',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: AppSizes.padding),

          // KPI Cards Grid
          Row(
            children: [
              Expanded(
                child: _KpiCard(
                  title: 'Total Omzet',
                  value: CurrencyFormatter.format(totalSales),
                  icon: Icons.account_balance_wallet_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: AppSizes.padding / 1.5),
              Expanded(
                child: _KpiCard(
                  title: 'Total Pesanan',
                  value: '${filteredTransactions.length} trx',
                  icon: Icons.receipt_long_outlined,
                  color: Colors.blue,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.padding / 1.5),
          Row(
            children: [
              Expanded(
                child: _KpiCard(
                  title: 'Rata-rata Order',
                  value: CurrencyFormatter.format(aov),
                  icon: Icons.analytics_outlined,
                  color: Colors.teal,
                ),
              ),
              const SizedBox(width: AppSizes.padding / 1.5),
              Expanded(
                child: _KpiCard(
                  title: 'Produk Terjual',
                  value: '$totalItemsSold pcs',
                  icon: Icons.shopping_basket_outlined,
                  color: Colors.purple,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.padding),

          // Action Buttons: Export PDF (Primary) & Export CSV (Secondary)
          Row(
            children: [
              Expanded(
                flex: 3,
                child: FilledButton.icon(
                  onPressed: () => _exportReportPdf(
                    periodTitle: periodTitle,
                    transactions: filteredTransactions,
                    totalSales: totalSales,
                    totalItemsSold: totalItemsSold,
                    aov: aov,
                    paymentBreakdown: paymentBreakdown,
                    channelBreakdown: channelBreakdown,
                    topProducts: topProducts,
                  ),
                  icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
                  label: const Text('Export PDF'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: OutlinedButton.icon(
                  onPressed: () => _exportReportCsv(filteredTransactions, periodTitle),
                  icon: const Icon(Icons.table_chart_outlined, size: 18),
                  label: const Text('Export CSV'),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.padding * 1.5),

          // Payment Methods Breakdown
          _SectionHeader(title: 'Metode Pembayaran', icon: Icons.payments_outlined),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(AppSizes.padding),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(AppSizes.radius),
              border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
            ),
            child: paymentBreakdown.isEmpty
                ? const Text('Belum ada transaksi pada periode ini', style: TextStyle(fontStyle: FontStyle.italic))
                : Column(
                    children: paymentBreakdown.entries.map((entry) {
                      final percentage = totalSales > 0 ? (entry.value / totalSales * 100).round() : 0;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(entry.key.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold)),
                            Text('${CurrencyFormatter.format(entry.value)} ($percentage%)'),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
          ),
          const SizedBox(height: AppSizes.padding * 1.5),

          // Channel Breakdown
          _SectionHeader(title: 'Saluran Penjualan (Channel)', icon: Icons.storefront_outlined),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(AppSizes.padding),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(AppSizes.radius),
              border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
            ),
            child: channelBreakdown.isEmpty
                ? const Text('Belum ada data saluran penjualan', style: TextStyle(fontStyle: FontStyle.italic))
                : Column(
                    children: channelBreakdown.entries.map((entry) {
                      final percentage = totalSales > 0 ? (entry.value / totalSales * 100).round() : 0;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(entry.key.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold)),
                            Text('${CurrencyFormatter.format(entry.value)} ($percentage%)'),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
          ),
          const SizedBox(height: AppSizes.padding * 1.5),

          // Top Selling Products
          _SectionHeader(title: 'Produk Terlaris', icon: Icons.star_outline_rounded),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(AppSizes.padding),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(AppSizes.radius),
              border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
            ),
            child: topProducts.isEmpty
                ? const Text('Belum ada data penjualan produk', style: TextStyle(fontStyle: FontStyle.italic))
                : Column(
                    children: [
                      for (int i = 0; i < topProducts.length && i < 5; i++)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 11,
                                backgroundColor: i == 0
                                    ? Colors.amber.shade700
                                    : Theme.of(context).colorScheme.surfaceContainerHighest,
                                child: Text(
                                  '${i + 1}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: i == 0 ? Colors.white : Theme.of(context).colorScheme.onSurface,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(topProducts[i].key, style: const TextStyle(fontWeight: FontWeight.w500)),
                              ),
                              Text(
                                '${topProducts[i].value} pcs',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
          ),
          const SizedBox(height: AppSizes.padding * 2),
        ],
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _KpiCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.padding),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppSizes.radius),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              Icon(icon, size: 18, color: color),
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;

  const _SectionHeader({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
