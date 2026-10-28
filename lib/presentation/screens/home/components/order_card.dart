import 'package:app_image/app_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/themes/app_sizes.dart';
import '../../../../core/utilities/currency_formatter.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/app_dialog.dart';
import '../../../widgets/app_text_field.dart';

class OrderCard extends StatefulWidget {
  final String name;
  final String imageUrl;
  final int stock;
  final int price;
  final int initialQuantity;
  final VoidCallback? onTapCard;
  final VoidCallback? onTapRemove;
  final Function(int) onChangedQuantity;
  final Function(int)? onChangedPrice;
  final String? notes;
  final Function(String?)? onChangedNotes;

  const OrderCard({
    super.key,
    required this.name,
    required this.imageUrl,
    required this.stock,
    required this.price,
    this.initialQuantity = 0,
    this.onTapCard,
    this.onTapRemove,
    required this.onChangedQuantity,
    this.onChangedPrice,
    this.notes,
    this.onChangedNotes,
  });

  @override
  State<OrderCard> createState() => _OrderCardState();
}

class _OrderCardState extends State<OrderCard> {
  int quantity = 1;
  late int currentPrice;

  @override
  void initState() {
    quantity = widget.initialQuantity == 0 ? 1 : widget.initialQuantity;
    currentPrice = widget.price;
    super.initState();
  }

  @override
  void didUpdateWidget(covariant OrderCard oldWidget) {
    quantity = widget.initialQuantity == 0 ? 1 : widget.initialQuantity;
    currentPrice = widget.price;
    super.didUpdateWidget(oldWidget);
  }

  void _showEditPriceDialog() {
    final controller = TextEditingController(text: currentPrice.toString());
    AppDialog.show(
      title: 'Ubah Harga Satuan',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: AppTextField(
          controller: controller,
          labelText: 'Harga (Rp)',
          hintText: 'Masukkan harga baru...',
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          autofocus: true,
        ),
      ),
      rightButtonText: 'Simpan',
      leftButtonText: 'Batal',
      onTapLeftButton: (context) => context.pop(),
      onTapRightButton: (context) {
        final parsed = int.tryParse(controller.text);
        if (parsed != null && parsed >= 0) {
          setState(() {
            currentPrice = parsed;
          });
          widget.onChangedPrice?.call(parsed);
        }
        context.pop();
      },
    );
  }

  void _showEditNotesDialog() {
    final controller = TextEditingController(text: widget.notes ?? '');
    AppDialog.show(
      title: 'Catatan Item',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: AppTextField(
          controller: controller,
          labelText: 'Catatan (misal: Pedas, Tanpa Es, dll)',
          hintText: 'Tulis catatan untuk item ini...',
          autofocus: true,
        ),
      ),
      rightButtonText: 'Simpan',
      leftButtonText: 'Batal',
      onTapLeftButton: (context) => context.pop(),
      onTapRightButton: (context) {
        final val = controller.text.trim();
        widget.onChangedNotes?.call(val.isEmpty ? null : val);
        context.pop();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      borderRadius: BorderRadius.circular(AppSizes.radius),
      child: InkWell(
        onTap: widget.onTapCard,
        child: Ink(
          padding: const EdgeInsets.all(AppSizes.padding),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border.all(
              width: 1,
              color: Theme.of(context).colorScheme.surfaceContainer,
            ),
            borderRadius: BorderRadius.circular(AppSizes.radius),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        InkWell(
                          onTap: widget.onChangedPrice != null ? _showEditPriceDialog : null,
                          borderRadius: BorderRadius.circular(4),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  CurrencyFormatter.format(currentPrice),
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: widget.onChangedPrice != null
                                        ? Theme.of(context).colorScheme.primary
                                        : null,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '/pcs',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 10),
                                ),
                                if (widget.onChangedPrice != null) ...[
                                  const SizedBox(width: 4),
                                  Icon(
                                    Icons.edit_outlined,
                                    size: 13,
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Stock: ${widget.stock}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 10),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          height: 36,
                          constraints: const BoxConstraints(maxWidth: 112),
                          child: Stack(
                            children: [
                              AppButton(
                                width: double.infinity,
                                height: 30,
                                padding: EdgeInsets.zero,
                                buttonColor: Theme.of(context).colorScheme.surfaceContainerLowest,
                                borderColor: Theme.of(context).colorScheme.surfaceContainer,
                                borderRadius: BorderRadius.circular(4),
                                child: Text(
                                  '$quantity',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ),
                              AppButton(
                                width: 30,
                                height: 30,
                                padding: EdgeInsets.zero,
                                buttonColor: Theme.of(context).colorScheme.surfaceContainer,
                                borderRadius: BorderRadius.circular(4),
                                child: Text(
                                  '-',
                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                                onTap: () {
                                  if (quantity > 1) {
                                    quantity -= 1;
                                    setState(() {});

                                    widget.onChangedQuantity(quantity);
                                  }
                                },
                              ),
                              Positioned(
                                right: 0,
                                child: AppButton(
                                  width: 30,
                                  height: 30,
                                  padding: EdgeInsets.zero,
                                  buttonColor: Theme.of(context).colorScheme.surfaceContainer,
                                  borderRadius: BorderRadius.circular(4),
                                  child: Text(
                                    '+',
                                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(context).colorScheme.primary,
                                    ),
                                  ),
                                  onTap: () {
                                    if (quantity < widget.stock) {
                                      quantity += 1;
                                      setState(() {});

                                      widget.onChangedQuantity(quantity);
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (widget.onChangedNotes != null) ...[
                          const SizedBox(height: 8),
                          InkWell(
                            onTap: _showEditNotesDialog,
                            borderRadius: BorderRadius.circular(4),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                              decoration: BoxDecoration(
                                color: (widget.notes != null && widget.notes!.trim().isNotEmpty)
                                    ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.4)
                                    : Theme.of(context).colorScheme.surfaceContainer,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.edit_note_rounded,
                                    size: 15,
                                    color: (widget.notes != null && widget.notes!.trim().isNotEmpty)
                                        ? Theme.of(context).colorScheme.primary
                                        : Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      (widget.notes != null && widget.notes!.trim().isNotEmpty)
                                          ? 'Note: ${widget.notes!.trim()}'
                                          : '+ Catatan',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        fontSize: 11,
                                        fontWeight: (widget.notes != null && widget.notes!.trim().isNotEmpty)
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                        color: (widget.notes != null && widget.notes!.trim().isNotEmpty)
                                            ? Theme.of(context).colorScheme.primary
                                            : Theme.of(context).colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  AppImage(
                    width: 70,
                    height: 70,
                    image: widget.imageUrl,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(width: 0.5, color: Theme.of(context).colorScheme.surfaceContainerHighest),
                    backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
                    errorWidget: Icon(
                      Icons.image,
                      color: Theme.of(context).colorScheme.surfaceDim,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (widget.onTapRemove != null)
                    AppButton(
                      text: 'Remove',
                      width: 70,
                      fontSize: 10,
                      borderRadius: BorderRadius.circular(4),
                      padding: const EdgeInsets.all(AppSizes.padding / 4),
                      buttonColor: Theme.of(context).colorScheme.errorContainer.withValues(alpha: 0.32),
                      textColor: Theme.of(context).colorScheme.error,
                      onTap: () {
                        AppDialog.show(
                          title: 'Confirm',
                          text: 'Are you sure want to remove this product?',
                          rightButtonText: 'Remove',
                          leftButtonText: 'Cancel',
                          onTapRightButton: (context) {
                            widget.onTapRemove!();
                            context.pop();
                          },
                        );
                      },
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
