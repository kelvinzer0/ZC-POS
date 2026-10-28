import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../../app/di/app_providers.dart';
import '../../../core/themes/app_sizes.dart';
import '../../../core/utilities/currency_formatter.dart';
import '../../../domain/entities/transaction_entity.dart';
import '../../providers/transactions/transactions_notifier.dart';
import '../../widgets/app_progress_indicator.dart';
import '../../widgets/app_snack_bar.dart';

enum ReportPeriod { today, last7Days, thisMonth, allTime }

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  ReportPeriod _selectedPeriod = ReportPeriod.today;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(transactionsNotifierProvider.notifier).getAllTransactions();
    });
  }

  String _getPeriodTitle(ReportPeriod period) {
    return switch (period) {
      ReportPeriod.today => 'Hari Ini',
      ReportPeriod.last7Days => '7 Hari Terakhir',
      ReportPeriod.thisMonth => 'Bulan Ini',
      ReportPeriod.allTime => 'Semua Waktu',
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
      };
    }).toList();
  }

  void _printReport({
    required String periodTitle,
    required int totalSales,
    required int totalTransactions,
    required int totalItemsSold,
    required Map<String, int> paymentBreakdown,
    required Map<String, int> channelBreakdown,
    required List<MapEntry<String, int>> topProducts,
  }) async {
    final printerService = ref.read(printerServiceProvider);
    if (printerService.selectedPrinter == null) {
      AppSnackBar.showError('Printer belum dipilih! Silakan sambungkan printer di menu Printer Settings.');
      return;
    }

    final res = await printerService.printSalesReport(
      periodTitle: periodTitle,
      totalSales: totalSales,
      totalTransactions: totalTransactions,
      totalItemsSold: totalItemsSold,
      paymentBreakdown: paymentBreakdown,
      channelBreakdown: channelBreakdown,
      topProducts: topProducts,
    );

    if (res.isSuccess) {
      AppSnackBar.show('Laporan penjualan berhasil dicetak');
    } else {
      AppSnackBar.showError(res.error.toString());
    }
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
        title: const Text('Laporan Penjualan'),
        titleSpacing: 0,
        actions: [
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
          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: ReportPeriod.values.map((period) {
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
              }).toList(),
            ),
          ),
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

          // Action Buttons: Print Thermal & Export CSV
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _printReport(
                    periodTitle: periodTitle,
                    totalSales: totalSales,
                    totalTransactions: filteredTransactions.length,
                    totalItemsSold: totalItemsSold,
                    paymentBreakdown: paymentBreakdown,
                    channelBreakdown: channelBreakdown,
                    topProducts: topProducts,
                  ),
                  icon: const Icon(Icons.print_outlined, size: 18),
                  label: const Text('Cetak Rekap'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _exportReportCsv(filteredTransactions, periodTitle),
                  icon: const Icon(Icons.file_download_outlined, size: 18),
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
                            Text(_formatChannel(entry.key), style: const TextStyle(fontWeight: FontWeight.bold)),
                            Text('${CurrencyFormatter.format(entry.value)} ($percentage%)'),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
          ),
          const SizedBox(height: AppSizes.padding * 1.5),

          // Top Products
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
                ? const Text('Belum ada produk terjual', style: TextStyle(fontStyle: FontStyle.italic))
                : Column(
                    children: List.generate(
                      topProducts.length > 5 ? 5 : topProducts.length,
                      (i) {
                        final item = topProducts[i];
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 12,
                                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                                child: Text('${i + 1}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
                              ),
                              const SizedBox(width: 8),
                              Expanded(child: Text(item.key, style: const TextStyle(fontWeight: FontWeight.w600))),
                              Text('${item.value} pcs', style: const TextStyle(fontWeight: FontWeight.bold)),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  String _formatChannel(String ch) {
    return switch (ch.toLowerCase()) {
      'wa' => 'WhatsApp',
      'market' => 'Marketplace',
      'instagram' => 'Instagram',
      'telegram' => 'Telegram',
      'facebook' => 'Facebook',
      'tiktok' => 'TikTok',
      'lainnya' => 'Lainnya',
      _ => 'Offline / Toko',
    };
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
              Text(title, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.outline)),
              Icon(icon, size: 18, color: color),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
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
        const SizedBox(width: 6),
        Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
      ],
    );
  }
}
