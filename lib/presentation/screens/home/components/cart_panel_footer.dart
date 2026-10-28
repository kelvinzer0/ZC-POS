import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';

import '../../../../app/di/app_providers.dart';
import '../../../../core/themes/app_sizes.dart';
import '../../../../core/utilities/currency_formatter.dart';
import '../../../providers/home/home_notifier.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/app_dialog.dart';
import '../../../widgets/app_drop_down.dart';
import '../../../widgets/app_text_field.dart';

class CartPanelFooter extends ConsumerWidget {
  final PanelController panelController;

  const CartPanelFooter({super.key, required this.panelController});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPanelExpanded = ref.watch(homeNotifierProvider.select((s) => s.isPanelExpanded));

    return Container(
      width: AppSizes.screenWidth(context),
      padding: const EdgeInsets.fromLTRB(AppSizes.padding, 0, AppSizes.padding, AppSizes.padding),
      color: Theme.of(context).colorScheme.surfaceContainerLowest,
      child: Row(
        children: [
          AnimatedContainer(
            width: isPanelExpanded ? AppSizes.screenWidth(context) / 3 : 0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: AppSizes.screenWidth(context) / 3 - AppSizes.padding / 2,
                child: _BackButton(panelController: panelController),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: _PayButton(panelController: panelController),
          ),
        ],
      ),
    );
  }
}

class _BackButton extends ConsumerWidget {
  final PanelController panelController;

  const _BackButton({required this.panelController});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppButton(
      text: 'Back',
      buttonColor: Theme.of(context).colorScheme.surface,
      borderColor: Theme.of(context).colorScheme.primary,
      textColor: Theme.of(context).colorScheme.primary,
      onTap: () => panelController.close(),
    );
  }
}

class _PayButton extends ConsumerWidget {
  final PanelController panelController;

  const _PayButton({required this.panelController});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final homeState = ref.watch(homeNotifierProvider);
    final homeNotifier = ref.read(homeNotifierProvider.notifier);

    return AppButton(
      text: !homeState.isPanelExpanded
          ? homeState.orderedProducts.isNotEmpty
                ? "${homeState.orderedProducts.length} Products = ${CurrencyFormatter.format(homeNotifier.getTotalAmount())}"
                : 'Transaction'
          : 'Pay',
      enabled: homeState.orderedProducts.isNotEmpty,
      onTap: () {
        if (homeState.isPanelExpanded) {
          AppDialog.show(
            child: const _AdditionalInfoDialog(),
            showButtons: false,
          );
        } else {
          panelController.open();
        }
      },
    );
  }
}

class _AdditionalInfoDialog extends ConsumerStatefulWidget {
  const _AdditionalInfoDialog();

  @override
  ConsumerState<_AdditionalInfoDialog> createState() => _AdditionalInfoDialogState();
}

class _AdditionalInfoDialogState extends ConsumerState<_AdditionalInfoDialog> {
  final _amountController = TextEditingController();
  final _customerController = TextEditingController();
  final _descriptionController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final state = ref.read(homeNotifierProvider);
    final homeNotifier = ref.read(homeNotifierProvider.notifier);
    final totalAmount = homeNotifier.getTotalAmount();

    // Default fill receivedAmount with total pesanan, which user can edit freely
    final initialAmount = state.receivedAmount > 0 ? state.receivedAmount : totalAmount;
    if (initialAmount > 0) {
      _amountController.text = initialAmount.toString();
      _amountController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _amountController.text.length,
      );
      if (state.receivedAmount <= 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          homeNotifier.onChangedReceivedAmount(totalAmount);
        });
      }
    }
    _customerController.text = state.customerName ?? '';
    _descriptionController.text = state.description ?? '';
  }

  @override
  void dispose() {
    _amountController.dispose();
    _customerController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> onPay({
    required GoRouter router,
    required HomeNotifier homeNotifier,
  }) async {
    var res = await AppDialog.showProgress(() {
      return homeNotifier.createTransaction();
    });

    if (res.isSuccess) {
      homeNotifier.onRemoveAllOrderedProduct();
      router.go('/transactions/transaction-detail/${res.data}');
    } else {
      AppDialog.showError(error: res.error?.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final homeState = ref.watch(homeNotifierProvider);
    final homeNotifier = ref.read(homeNotifierProvider.notifier);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppTextField(
          autofocus: true,
          keyboardType: TextInputType.number,
          controller: _amountController,
          labelText: 'Received Amount',
          hintText: 'Received amount...',
          suffixWidget: IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 20),
            tooltip: 'Isi Total Pesanan (Uang Pas)',
            onPressed: () {
              final total = homeNotifier.getTotalAmount();
              _amountController.text = total.toString();
              _amountController.selection = TextSelection(
                baseOffset: 0,
                extentOffset: _amountController.text.length,
              );
              homeNotifier.onChangedReceivedAmount(total);
            },
          ),
          onChanged: (val) {
            homeNotifier.onChangedReceivedAmount(int.tryParse(val) ?? 0);
          },
        ),
        const SizedBox(height: AppSizes.padding),
        AppDropDown(
          labelText: 'Payment Method',
          selectedValue: homeState.selectedPaymentMethod,
          dropdownItems: const [
            DropdownMenuItem(
              value: 'bank',
              child: Text('Bank'),
            ),
            DropdownMenuItem(
              value: 'cash',
              child: Text('Cash'),
            ),
          ],
          onChanged: (v) => homeNotifier.onChangedPaymentMethod(v),
        ),
        const SizedBox(height: AppSizes.padding),
        AppDropDown(
          labelText: 'Channel Transaksi',
          selectedValue: homeState.selectedChannel,
          dropdownItems: const [
            DropdownMenuItem(
              value: 'offline',
              child: Row(
                children: [
                  Icon(Icons.storefront_outlined, size: 18),
                  SizedBox(width: 8),
                  Text('Offline / Toko'),
                ],
              ),
            ),
            DropdownMenuItem(
              value: 'market',
              child: Row(
                children: [
                  Icon(Icons.shopping_bag_outlined, size: 18),
                  SizedBox(width: 8),
                  Text('Marketplace'),
                ],
              ),
            ),
            DropdownMenuItem(
              value: 'wa',
              child: Row(
                children: [
                  Icon(Icons.chat_outlined, size: 18, color: Colors.green),
                  SizedBox(width: 8),
                  Text('WhatsApp'),
                ],
              ),
            ),
            DropdownMenuItem(
              value: 'instagram',
              child: Row(
                children: [
                  Icon(Icons.camera_alt_outlined, size: 18, color: Colors.purple),
                  SizedBox(width: 8),
                  Text('Instagram'),
                ],
              ),
            ),
            DropdownMenuItem(
              value: 'telegram',
              child: Row(
                children: [
                  Icon(Icons.send_rounded, size: 18, color: Colors.lightBlue),
                  SizedBox(width: 8),
                  Text('Telegram'),
                ],
              ),
            ),
            DropdownMenuItem(
              value: 'facebook',
              child: Row(
                children: [
                  Icon(Icons.facebook, size: 18, color: Colors.blue),
                  SizedBox(width: 8),
                  Text('Facebook'),
                ],
              ),
            ),
            DropdownMenuItem(
              value: 'tiktok',
              child: Row(
                children: [
                  Icon(Icons.music_note_rounded, size: 18),
                  SizedBox(width: 8),
                  Text('TikTok'),
                ],
              ),
            ),
            DropdownMenuItem(
              value: 'lainnya',
              child: Row(
                children: [
                  Icon(Icons.more_horiz_rounded, size: 18),
                  SizedBox(width: 8),
                  Text('Lainnya'),
                ],
              ),
            ),
          ],
          onChanged: (v) => homeNotifier.onChangedChannel(v),
        ),
        const SizedBox(height: AppSizes.padding),
        AppTextField(
          controller: _customerController,
          labelText: 'Customer Name (Optional)',
          hintText: 'e.g. Jhone Doe',
          onChanged: (v) => homeNotifier.onChangedCustomerName(v),
        ),
        const SizedBox(height: AppSizes.padding),
        AppTextField(
          controller: _descriptionController,
          labelText: 'Catatan Semua Pesanan / Order Notes (Optional)',
          hintText: 'Misal: Meja 5 / Bungkus / Sambal dipisah...',
          onChanged: (v) => homeNotifier.onChangedDescription(v),
        ),
        const SizedBox(height: AppSizes.padding * 1.5),
        Row(
          children: [
            Expanded(
              child: AppButton(
                text: 'Cancel',
                buttonColor: Theme.of(context).colorScheme.surface,
                borderColor: Theme.of(context).colorScheme.primary,
                textColor: Theme.of(context).colorScheme.primary,
                onTap: () {
                  context.pop();
                },
              ),
            ),
            const SizedBox(width: AppSizes.padding / 2),
            Expanded(
              flex: 2,
              child: AppButton(
                text: 'Pay',
                enabled: (int.tryParse(_amountController.text) ?? 0) >= homeNotifier.getTotalAmount(),
                onTap: () {
                  final router = ref.read(appRoutesProvider).router;

                  context.pop();
                  onPay(
                    homeNotifier: homeNotifier,
                    router: router,
                  );
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}
