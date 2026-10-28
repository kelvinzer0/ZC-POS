import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';

import '../../../../core/themes/app_sizes.dart';
import '../../../../core/utilities/currency_formatter.dart';
import '../../../providers/home/home_notifier.dart';
import '../../../widgets/app_dialog.dart';
import '../../../widgets/app_empty_state.dart';
import '../../../widgets/app_text_field.dart';
import 'order_card.dart';

class CartPanelBody extends StatelessWidget {
  final PanelController panelController;

  const CartPanelBody({super.key, required this.panelController});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 62),
      physics: const NeverScrollableScrollPhysics(),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _OrderList(panelController: panelController),
          const _OrderTotal(),
        ],
      ),
    );
  }
}

class _OrderList extends ConsumerWidget {
  final PanelController panelController;

  const _OrderList({required this.panelController});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final homeState = ref.watch(homeNotifierProvider);

    if (homeState.orderedProducts.isEmpty) {
      return SizedBox(
        height: AppSizes.screenHeight(context) - 295,
        child: const AppEmptyState(
          title: 'Empty',
          subtitle: 'No products added to cart',
        ),
      );
    }

    return SizedBox(
      height: AppSizes.screenHeight(context) - 295,
      child: Scrollbar(
        child: ListView.builder(
          itemCount: homeState.orderedProducts.length,
          padding: const EdgeInsets.all(AppSizes.padding),
          itemBuilder: (context, i) {
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSizes.padding),
              child: OrderCard(
                name: homeState.orderedProducts[i].name,
                imageUrl: homeState.orderedProducts[i].imageUrl,
                stock: homeState.orderedProducts[i].stock,
                price: homeState.orderedProducts[i].price,
                notes: homeState.orderedProducts[i].notes,
                initialQuantity: homeState.orderedProducts[i].quantity,
                onChangedQuantity: (val) {
                  ref.read(homeNotifierProvider.notifier).onChangedOrderedProductQuantity(i, val);
                },
                onChangedPrice: (newPrice) {
                  ref.read(homeNotifierProvider.notifier).onChangedOrderedProductPrice(i, newPrice);
                },
                onChangedNotes: (newNotes) {
                  ref.read(homeNotifierProvider.notifier).onChangedOrderedProductNotes(i, newNotes);
                },
                onTapRemove: () {
                  final isLast = homeState.orderedProducts.length == 1;
                  ref.read(homeNotifierProvider.notifier).onRemoveOrderedProduct(homeState.orderedProducts[i]);
                  if (isLast) panelController.close();
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

class _OrderTotal extends ConsumerWidget {
  const _OrderTotal();

  void _showShippingFeeDialog(BuildContext context, WidgetRef ref) {
    final currentFee = ref.read(homeNotifierProvider).shippingFee;
    final controller = TextEditingController(text: currentFee > 0 ? '$currentFee' : '');

    AppDialog.show(
      title: 'Atur Ongkir',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppTextField(
              controller: controller,
              labelText: 'Biaya Ongkir (Rp)',
              hintText: 'Masukkan biaya ongkir (0 jika gratis)...',
              keyboardType: TextInputType.number,
              autofocus: true,
              prefixWidget: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 10),
                child: Icon(Icons.local_shipping_outlined, size: 20),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [0, 5000, 10000, 15000, 20000].map((fee) {
                return ActionChip(
                  label: Text(fee == 0 ? 'Gratis (0)' : CurrencyFormatter.format(fee)),
                  onPressed: () {
                    controller.text = fee.toString();
                    controller.selection = TextSelection.fromPosition(
                      TextPosition(offset: controller.text.length),
                    );
                  },
                );
              }).toList(),
            ),
          ],
        ),
      ),
      rightButtonText: 'Simpan',
      leftButtonText: 'Batal',
      onTapLeftButton: (context) => context.pop(),
      onTapRightButton: (context) {
        final parsed = int.tryParse(controller.text) ?? 0;
        ref.read(homeNotifierProvider.notifier).onChangedShippingFee(parsed >= 0 ? parsed : 0);
        context.pop();
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final homeState = ref.watch(homeNotifierProvider);
    final homeNotifier = ref.read(homeNotifierProvider.notifier);
    final subtotal = homeNotifier.getSubtotalAmount();
    final shippingFee = homeState.shippingFee;
    final total = homeNotifier.getTotalAmount();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.padding, vertical: AppSizes.padding * 0.75),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        border: Border(
          top: BorderSide(
            width: 1,
            color: Theme.of(context).colorScheme.surfaceContainer,
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (shippingFee > 0) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Subtotal (${homeState.orderedProducts.length} item)',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
                Text(
                  CurrencyFormatter.format(subtotal),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
          ],
          InkWell(
            onTap: () => _showShippingFeeDialog(context, ref),
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.local_shipping_outlined,
                        size: 16,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Ongkir',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.edit_outlined,
                        size: 14,
                        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.7),
                      ),
                    ],
                  ),
                  Text(
                    shippingFee > 0
                        ? CurrencyFormatter.format(shippingFee)
                        : '+ Atur Ongkir',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: shippingFee > 0
                          ? Theme.of(context).colorScheme.onSurface
                          : Theme.of(context).colorScheme.primary,
                      fontWeight: shippingFee > 0 ? FontWeight.w600 : FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Divider(height: 1, color: Theme.of(context).colorScheme.surfaceContainer),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total (${homeState.orderedProducts.length})',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                CurrencyFormatter.format(total),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
