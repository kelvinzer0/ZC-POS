import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';

import '../../../../app/di/app_providers.dart';
import '../../../../core/services/contacts/customer_contacts_service.dart';
import '../../../../core/themes/app_sizes.dart';
import '../../../../core/utilities/currency_formatter.dart';
import '../../../providers/contacts/customer_contacts_provider.dart';
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
  final _shippingFeeController = TextEditingController();
  final _customerController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _customerFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    final state = ref.read(homeNotifierProvider);
    final homeNotifier = ref.read(homeNotifierProvider.notifier);
    final totalAmount = homeNotifier.getTotalAmount();

    if (state.shippingFee > 0) {
      _shippingFeeController.text = state.shippingFee.toString();
    }

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
    _shippingFeeController.dispose();
    _customerController.dispose();
    _descriptionController.dispose();
    _customerFocusNode.dispose();
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

    ref.listen(homeNotifierProvider.select((s) => s.orderedProducts.isEmpty), (_, isEmpty) {
      if (isEmpty) {
        _amountController.clear();
        _shippingFeeController.clear();
        _customerController.clear();
        _descriptionController.clear();
      }
    });

    ref.listen(homeNotifierProvider.select((s) => s.shippingFee), (_, fee) {
      final feeText = fee > 0 ? fee.toString() : '';
      if (_shippingFeeController.text != feeText) {
        _shippingFeeController.text = feeText;
      }
    });

    ref.listen(homeNotifierProvider.select((s) => s.customerName), (_, name) {
      if (_customerController.text != (name ?? '')) {
        _customerController.text = name ?? '';
      }
    });

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppTextField(
          controller: _shippingFeeController,
          keyboardType: TextInputType.number,
          labelText: 'Biaya Ongkir (Optional)',
          hintText: 'Biaya pengiriman / ongkir...',
          prefixWidget: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 10),
            child: Icon(Icons.local_shipping_outlined, size: 20),
          ),
          onChanged: (val) {
            final fee = int.tryParse(val) ?? 0;
            homeNotifier.onChangedShippingFee(fee >= 0 ? fee : 0);
          },
        ),
        const SizedBox(height: AppSizes.padding),
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
        RawAutocomplete<CustomerContact>(
          textEditingController: _customerController,
          focusNode: _customerFocusNode,
          optionsBuilder: (TextEditingValue textEditingValue) {
            final query = textEditingValue.text.trim().toLowerCase();
            final contactsAsync = ref.read(customerContactsProvider);
            final contacts = contactsAsync.value ?? [];
            if (query.isEmpty) {
              return contacts.take(4);
            }
            return contacts.where((c) {
              final matchName = c.name.toLowerCase().contains(query);
              final matchPhone = c.phone?.contains(query) ?? false;
              return matchName || matchPhone;
            }).take(6);
          },
          displayStringForOption: (CustomerContact option) => option.name,
          onSelected: (CustomerContact selection) {
            _customerController.text = selection.name;
            homeNotifier.onChangedCustomerName(selection.name);
          },
          optionsViewBuilder: (context, onSelected, options) {
            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(10),
                color: Theme.of(context).colorScheme.surfaceContainerLowest,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: 220,
                    maxWidth: MediaQuery.of(context).size.width - 64,
                  ),
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    shrinkWrap: true,
                    itemCount: options.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (BuildContext context, int index) {
                      final CustomerContact option = options.elementAt(index);
                      return ListTile(
                        dense: true,
                        leading: Icon(
                          option.isFromDevice
                              ? Icons.contact_phone_outlined
                              : Icons.history_rounded,
                          size: 18,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        title: Text(
                          option.name,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                        subtitle: option.phone != null
                            ? Text(
                                option.phone!,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Theme.of(context).colorScheme.outline,
                                ),
                              )
                            : null,
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: option.isFromDevice
                                ? Theme.of(context).colorScheme.primaryContainer
                                : Theme.of(context).colorScheme.secondaryContainer,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            option.isFromDevice ? 'Buku Kontak' : 'Pelanggan Lama',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: option.isFromDevice
                                  ? Theme.of(context).colorScheme.onPrimaryContainer
                                  : Theme.of(context).colorScheme.onSecondaryContainer,
                            ),
                          ),
                        ),
                        onTap: () => onSelected(option),
                      );
                    },
                  ),
                ),
              ),
            );
          },
          fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
            final contactsAsync = ref.watch(customerContactsProvider);
            return AppTextField(
              controller: controller,
              labelText: 'Customer Name (Auto Suggest dari Kontak)',
              hintText: 'Ketik nama customer / pilih kontak...',
              prefixWidget: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 10),
                child: Icon(Icons.person_outline, size: 20),
              ),
              suffixWidget: IconButton(
                icon: const Icon(Icons.contacts_outlined, size: 20),
                tooltip: 'Pilih dari Kontak',
                onPressed: () {
                  _pickFromContactsModal(
                    context,
                    contactsAsync.value ?? [],
                    homeNotifier,
                  );
                },
              ),
              onChanged: (v) => homeNotifier.onChangedCustomerName(v),
            );
          },
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

  void _pickFromContactsModal(
    BuildContext context,
    List<CustomerContact> contacts,
    HomeNotifier homeNotifier,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        String searchQuery = '';
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filtered = contacts.where((c) {
              if (searchQuery.isEmpty) return true;
              return c.name.toLowerCase().contains(searchQuery.toLowerCase()) ||
                  (c.phone?.contains(searchQuery) ?? false);
            }).toList();

            return Container(
              height: MediaQuery.of(context).size.height * 0.7,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.contacts_rounded),
                            const SizedBox(width: 8),
                            Text(
                              'Pilih Kontak Customer',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          autofocus: true,
                          decoration: InputDecoration(
                            hintText: 'Cari nama atau nomor HP...',
                            prefixIcon: const Icon(Icons.search),
                            filled: true,
                            fillColor: Theme.of(context).colorScheme.surfaceContainerLowest,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          ),
                          onChanged: (val) {
                            setModalState(() {
                              searchQuery = val;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: filtered.isEmpty
                        ? Center(
                            child: Text(
                              'Tidak ada kontak ditemukan',
                              style: TextStyle(color: Theme.of(context).colorScheme.outline),
                            ),
                          )
                        : ListView.separated(
                            itemCount: filtered.length,
                            separatorBuilder: (_, _) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final item = filtered[index];
                              return ListTile(
                                leading: CircleAvatar(
                                  radius: 16,
                                  child: Text(
                                    item.name.isNotEmpty ? item.name[0].toUpperCase() : '?',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                                subtitle: item.phone != null ? Text(item.phone!) : null,
                                trailing: Text(
                                  item.isFromDevice ? 'Buku Kontak' : 'Riwayat Trx',
                                  style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.outline),
                                ),
                                onTap: () {
                                  _customerController.text = item.name;
                                  homeNotifier.onChangedCustomerName(item.name);
                                  Navigator.pop(ctx);
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
