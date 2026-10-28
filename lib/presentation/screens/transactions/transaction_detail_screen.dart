import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/di/app_providers.dart';
import '../../../core/extensions/string_casing_extension.dart';
import '../../../core/themes/app_colors.dart';
import '../../../core/themes/app_sizes.dart';
import '../../../core/utilities/currency_formatter.dart';
import '../../../core/utilities/date_time_formatter.dart';
import '../../../domain/entities/ordered_product_entity.dart';
import '../../../domain/entities/transaction_entity.dart';
import '../../providers/transactions/transaction_detail_notifier.dart';
import '../../widgets/app_empty_state.dart';
import '../../widgets/app_progress_indicator.dart';
import '../../widgets/app_snack_bar.dart';

class TransactionDetailScreen extends ConsumerWidget {
  final int id;

  const TransactionDetailScreen({super.key, required this.id});

  void _showPrintOptions(BuildContext context, WidgetRef ref, TransactionEntity? transaction) {
    final targetTransaction = transaction ?? ref.read(transactionDetailNotifierProvider);
    if (targetTransaction == null) {
      AppSnackBar.showError('Data transaksi belum siap');
      return;
    }

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppSizes.radius * 1.5)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSizes.padding),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSizes.padding),
                  child: Row(
                    children: [
                      Icon(Icons.print_rounded, color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 8),
                      Text(
                        'Pilih Opsi Cetak',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                const Divider(),
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                    child: Icon(Icons.receipt_long, color: Theme.of(context).colorScheme.primary),
                  ),
                  title: const Text('Customer Receipt', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('Struk belanja lengkap untuk pelanggan'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _print(ref, targetTransaction, isKitchen: false);
                  },
                ),
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
                    child: Icon(Icons.restaurant, color: Theme.of(context).colorScheme.secondary),
                  ),
                  title: const Text('Kitchen Ticket', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('Tiket dapur ringkas (Trx ID, tgl, list pesanan & catatan)'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _print(ref, targetTransaction, isKitchen: true);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _print(WidgetRef ref, TransactionEntity transaction, {required bool isKitchen}) async {
    final printerService = ref.read(printerServiceProvider);
    if (printerService.selectedPrinter == null) {
      AppSnackBar.showError('Printer belum dipilih! Silakan sambungkan printer di menu Printer Settings.');
      return;
    }

    final result = isKitchen
        ? await printerService.printKitchenTicket(transaction)
        : await printerService.printCustomerReceipt(transaction);

    if (result.isFailure) {
      AppSnackBar.showError(result.error.toString());
    } else {
      AppSnackBar.show(isKitchen ? 'Kitchen Ticket berhasil dicetak' : 'Customer Receipt berhasil dicetak');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final watchedTransaction = ref.watch(transactionDetailNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.print_outlined),
            tooltip: 'Print Options',
            onPressed: () => _showPrintOptions(context, ref, watchedTransaction),
          ),
        ],
      ),
      body: FutureBuilder(
        future: ref.read(transactionDetailNotifierProvider.notifier).getTransactionDetail(id),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && watchedTransaction == null) {
            return const AppProgressIndicator();
          }

          if (snapshot.hasError && watchedTransaction == null) {
            throw snapshot.error.toString();
          }

          final transaction = watchedTransaction ?? snapshot.data;

          if (transaction == null) {
            return const AppEmptyState(title: 'Not Found');
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppSizes.padding),
            child: Column(
              children: [
                _StatusSection(
                  onTapPrint: () => _showPrintOptions(context, ref, transaction),
                ),
                const SizedBox(height: AppSizes.padding * 2),
                _TransactionDetail(transaction: transaction),
                const SizedBox(height: AppSizes.padding),
                _PaymentDetail(transaction: transaction),
                const SizedBox(height: AppSizes.padding),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _StatusSection extends StatelessWidget {
  final VoidCallback onTapPrint;

  const _StatusSection({required this.onTapPrint});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Icon(
          Icons.check_circle_outline_rounded,
          color: AppColors.green,
          size: 60,
        ),
        const SizedBox(height: AppSizes.padding / 2),
        Text(
          'Transaction Created',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: AppSizes.padding),
        OutlinedButton.icon(
          onPressed: onTapPrint,
          icon: const Icon(Icons.print_outlined),
          label: const Text('Cetak Struk / Ticket'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSizes.radius)),
          ),
        ),
      ],
    );
  }
}

class _TransactionDetail extends StatelessWidget {
  final TransactionEntity transaction;

  const _TransactionDetail({required this.transaction});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.padding),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppSizes.radius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Transaction ID',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '${transaction.id ?? '-'}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.padding),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Payment Method',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              Text(
                transaction.paymentMethod.toTitleCase(),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
          const SizedBox(height: AppSizes.padding),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Created By',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              Text(
                transaction.createdBy?.name ?? '-',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
          const SizedBox(height: AppSizes.padding),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Created At',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              Text(
                DateTimeFormatter.normalWithClock(transaction.createdAt ?? ''),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
          const SizedBox(height: AppSizes.padding),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Customer Name',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              Text(
                transaction.customerName ?? '-',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
          const SizedBox(height: AppSizes.padding),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Notes / Catatan',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(width: AppSizes.padding),
              Expanded(
                child: Text(
                  (transaction.description != null && transaction.description!.trim().isNotEmpty)
                      ? transaction.description!.trim()
                      : '-',
                  textAlign: TextAlign.right,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PaymentDetail extends StatelessWidget {
  final TransactionEntity transaction;

  const _PaymentDetail({required this.transaction});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.padding),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppSizes.radius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Ordered Products',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '${transaction.orderedProducts?.length ?? '0'}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const Divider(height: AppSizes.padding * 2),
          ...List.generate(transaction.orderedProducts?.length ?? 0, (i) {
            return Padding(
              padding: EdgeInsets.only(top: i == 0 ? 0 : AppSizes.padding / 2),
              child: _ProductItem(order: transaction.orderedProducts![i]),
            );
          }),
          const Divider(height: AppSizes.padding * 2),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                CurrencyFormatter.format(transaction.totalAmount),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.padding),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Payment Received',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              Text(
                CurrencyFormatter.format(transaction.receivedAmount),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
          const SizedBox(height: AppSizes.padding),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Change',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              Text(
                CurrencyFormatter.format(transaction.receivedAmount - transaction.totalAmount),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProductItem extends StatelessWidget {
  final OrderedProductEntity order;

  const _ProductItem({required this.order});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          order.name,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        if (order.notes != null && order.notes!.trim().isNotEmpty) ...[
          const SizedBox(height: 2),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              'Note: ${order.notes!.trim()}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
        const SizedBox(height: AppSizes.padding / 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${CurrencyFormatter.format(order.price)} x ${order.quantity}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            Text(
              CurrencyFormatter.format((order.price) * order.quantity),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ],
    );
  }
}
