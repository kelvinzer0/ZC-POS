import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:unified_esc_pos_printer/unified_esc_pos_printer.dart';

import '../../../app/di/app_providers.dart';
import '../../../core/themes/app_sizes.dart';
import '../../providers/account/printer_settings_notifier.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_drop_down.dart';
import '../../widgets/app_icon_button.dart';
import '../../widgets/app_snack_bar.dart';
import '../../widgets/app_text_field.dart';

class PrinterSettingsScreen extends ConsumerStatefulWidget {
  const PrinterSettingsScreen({super.key});

  @override
  ConsumerState<PrinterSettingsScreen> createState() => _PrinterSettingsScreenState();
}

class _PrinterSettingsScreenState extends ConsumerState<PrinterSettingsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(printerSettingsNotifierProvider.notifier).getAndSelectPrinter();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Printer Settings'),
        titleSpacing: 0,
      ),
      body: const _PrinterSettingsBody(),
    );
  }
}

class _PrinterSettingsBody extends StatelessWidget {
  const _PrinterSettingsBody();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSizes.padding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          _SettingsRow(),
          SizedBox(height: AppSizes.padding),
          _ReceiptHeaderSection(),
          SizedBox(height: AppSizes.padding),
          _ReceiptLogoSection(),
          SizedBox(height: AppSizes.padding * 1.5),
          _DevicesHeader(),
          SizedBox(height: AppSizes.padding),
          _PrinterList(),
        ],
      ),
    );
  }
}

class _ReceiptHeaderSection extends ConsumerStatefulWidget {
  const _ReceiptHeaderSection();

  @override
  ConsumerState<_ReceiptHeaderSection> createState() => _ReceiptHeaderSectionState();
}

class _ReceiptHeaderSectionState extends ConsumerState<_ReceiptHeaderSection> {
  late final TextEditingController _titleController;
  late final TextEditingController _subtitleController;

  @override
  void initState() {
    super.initState();
    final headerTitle = ref.read(printerSettingsNotifierProvider).receiptHeaderTitle;
    final headerSubtitle = ref.read(printerSettingsNotifierProvider).receiptHeaderSubtitle;
    _titleController = TextEditingController(text: headerTitle);
    _subtitleController = TextEditingController(text: headerSubtitle);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _subtitleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.padding),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppSizes.radius),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.title, size: 20, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                'Header & Identitas Struk',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Sesuaikan nama toko/usaha dan informasi sub-judul (link/kontak) di bagian atas struk.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.outline),
          ),
          const SizedBox(height: AppSizes.padding),
          AppTextField(
            controller: _titleController,
            labelText: 'Nama Usaha / Judul Struk',
            hintText: 'Contoh: Warung Lakku POS (default: ZC-POS)',
            onChanged: (v) {
              ref.read(printerSettingsNotifierProvider.notifier).setReceiptHeaderTitle(v);
            },
          ),
          const SizedBox(height: AppSizes.padding / 1.5),
          AppTextField(
            controller: _subtitleController,
            labelText: 'Sub-judul / Tagline / Info Kontak',
            hintText: 'Contoh: Jl. Merdeka No. 1 / WA: 08123456789',
            onChanged: (v) {
              ref.read(printerSettingsNotifierProvider.notifier).setReceiptHeaderSubtitle(v);
            },
          ),
        ],
      ),
    );
  }
}

class _ReceiptLogoSection extends ConsumerWidget {
  const _ReceiptLogoSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logoPath = ref.watch(printerSettingsNotifierProvider.select((p) => p.receiptLogoPath));
    final file = logoPath != null ? File(logoPath) : null;
    final exists = file != null && file.existsSync();

    return Container(
      padding: const EdgeInsets.all(AppSizes.padding),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppSizes.radius),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.receipt_long, size: 20, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                'Logo Struk (Thermal Receipt)',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Logo gambar hitam-putih / monokrom untuk dicetak di bagian atas struk.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.outline),
          ),
          const SizedBox(height: AppSizes.padding),
          if (exists)
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.file(
                    file,
                    width: 64,
                    height: 64,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: AppSizes.padding),
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      AppButton(
                        height: 36,
                        text: 'Ganti Logo',
                        fontSize: 12,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        buttonColor: Theme.of(context).colorScheme.surfaceContainer,
                        onTap: () => _pickAndSetLogo(context, ref),
                      ),
                      AppButton(
                        height: 36,
                        text: 'Hapus Logo',
                        fontSize: 12,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        buttonColor: Theme.of(context).colorScheme.errorContainer.withValues(alpha: 0.3),
                        textColor: Theme.of(context).colorScheme.error,
                        onTap: () async {
                          await ref.read(printerSettingsNotifierProvider.notifier).setReceiptLogoPath(null);
                          AppSnackBar.show('Logo struk berhasil dihapus');
                        },
                      ),
                    ],
                  ),
                ),
              ],
            )
          else
            AppButton(
              height: 40,
              buttonColor: Theme.of(context).colorScheme.surfaceContainer,
              onTap: () => _pickAndSetLogo(context, ref),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.add_photo_alternate_outlined,
                    size: 18,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Pilih Gambar Logo Struk',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _pickAndSetLogo(BuildContext context, WidgetRef ref) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
      if (picked == null) return;

      final appDir = await getApplicationDocumentsDirectory();
      final savedPath = '${appDir.path}/receipt_logo_${DateTime.now().millisecondsSinceEpoch}.png';
      await File(picked.path).copy(savedPath);

      await ref.read(printerSettingsNotifierProvider.notifier).setReceiptLogoPath(savedPath);
      AppSnackBar.show('Logo struk berhasil disimpan');
    } catch (e) {
      AppSnackBar.showError('Gagal memilih logo: $e');
    }
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow();

  @override
  Widget build(BuildContext context) {
    return const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _ConnectionTypeDropDown()),
        SizedBox(width: AppSizes.padding),
        Expanded(child: _PaperSizeSelector()),
      ],
    );
  }
}

class _PaperSizeSelector extends ConsumerWidget {
  const _PaperSizeSelector();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paperSize = ref.watch(printerSettingsNotifierProvider.select((p) => p.paperSize));
    final isScanning = ref.watch(printerSettingsNotifierProvider.select((p) => p.isScanning));
    final isConnecting = ref.watch(printerSettingsNotifierProvider.select((s) => s.connectingDeviceId != null));
    final isDisconnecting = ref.watch(printerSettingsNotifierProvider.select((p) => p.isDisconnecting));

    final isBusy = isScanning || isConnecting || isDisconnecting;

    return AppDropDown<PaperSize>(
      labelText: 'Paper Size',
      selectedValue: paperSize,
      enabled: !isBusy,
      dropdownItems: PaperSize.values.map((size) {
        return DropdownMenuItem<PaperSize>(
          value: size,
          child: Text(_label(size)),
        );
      }).toList(),
      onChanged: (value) {
        if (value == null) return;
        ref.read(printerSettingsNotifierProvider.notifier).setPaperSize(value);
      },
    );
  }

  String _label(PaperSize size) {
    return switch (size) {
      PaperSize.mm58 => '58mm',
      PaperSize.mm72 => '72mm',
      PaperSize.mm80 => '80mm',
    };
  }
}

class _ConnectionTypeDropDown extends ConsumerWidget {
  const _ConnectionTypeDropDown();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedTypes = ref.watch(printerSettingsNotifierProvider.select((p) => p.selectedTypes));
    final isScanning = ref.watch(printerSettingsNotifierProvider.select((p) => p.isScanning));
    final isConnecting = ref.watch(printerSettingsNotifierProvider.select((s) => s.connectingDeviceId != null));
    final isDisconnecting = ref.watch(printerSettingsNotifierProvider.select((p) => p.isDisconnecting));

    final isBusy = isScanning || isConnecting || isDisconnecting;

    return AppDropDown<PrinterConnectionType>.multi(
      labelText: 'Connection Types',
      hintText: 'Select connection types',
      enabled: !isBusy,
      selectedValues: selectedTypes,
      dropdownItems: PrinterConnectionType.values.map((type) {
        return DropdownMenuItem<PrinterConnectionType>(
          value: type,
          child: Row(
            children: [
              Icon(_icon(type), size: 18),
              const SizedBox(width: 8),
              Text(_label(type)),
            ],
          ),
        );
      }).toList(),
      selectedValuesTextBuilder: _selectedLabel,
      onChanged: (type) {
        if (type == null) return;
        ref.read(printerSettingsNotifierProvider.notifier).toggleConnectionType(type);
      },
    );
  }

  String _label(PrinterConnectionType type) {
    return switch (type) {
      PrinterConnectionType.usb => 'USB',
      PrinterConnectionType.bluetooth => 'Bluetooth',
      PrinterConnectionType.ble => 'BLE',
      PrinterConnectionType.network => 'Network',
    };
  }

  IconData _icon(PrinterConnectionType type) {
    return switch (type) {
      PrinterConnectionType.usb => Icons.usb,
      PrinterConnectionType.bluetooth => Icons.bluetooth,
      PrinterConnectionType.ble => Icons.bluetooth_searching,
      PrinterConnectionType.network => Icons.wifi,
    };
  }

  String _selectedLabel(Set<PrinterConnectionType> selectedTypes) {
    if (selectedTypes.length == PrinterConnectionType.values.length) {
      return 'All connection types';
    }

    return selectedTypes.map(_label).join(', ');
  }
}

class _DevicesHeader extends ConsumerWidget {
  const _DevicesHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isScanning = ref.watch(printerSettingsNotifierProvider.select((p) => p.isScanning));
    final isConnecting = ref.watch(printerSettingsNotifierProvider.select((s) => s.connectingDeviceId != null));
    final isDisconnecting = ref.watch(printerSettingsNotifierProvider.select((p) => p.isDisconnecting));
    final hasSelectedPrinter = ref.read(printerSettingsNotifierProvider.notifier).selectedPrinterIndex != -1;

    final isBusy = isScanning || isConnecting || isDisconnecting;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Text(
              'Available Devices',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: AppSizes.padding / 1.5),
            if (isScanning || isDisconnecting)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
          ],
        ),
        Row(
          children: [
            AppIconButton(
              icon: Icons.refresh,
              iconSize: 18,
              enabled: !isBusy,
              onTap: () {
                ref.read(printerSettingsNotifierProvider.notifier).getAndSelectPrinter();
              },
            ),
            const SizedBox(width: 4),
            AppIconButton(
              icon: Icons.link_off,
              iconSize: 18,
              enabled: hasSelectedPrinter && !isBusy,
              onTap: () {
                ref.read(printerSettingsNotifierProvider.notifier).disconnectPrinter();
              },
            ),
            const SizedBox(width: 4),
            AppIconButton(
              icon: Icons.print_outlined,
              iconSize: 18,
              enabled: hasSelectedPrinter && !isConnecting,
              onTap: () async {
                final result = await ref.read(printerServiceProvider).testPrint();

                if (result.isFailure) {
                  AppSnackBar.showError(result.error.toString());
                }
              },
            ),
          ],
        ),
      ],
    );
  }
}

class _PrinterList extends ConsumerWidget {
  const _PrinterList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(printerSettingsNotifierProvider.notifier);

    final printers = ref.watch(printerSettingsNotifierProvider.select((s) => s.printers));
    final isScanning = ref.watch(printerSettingsNotifierProvider.select((s) => s.isScanning));
    final isConnecting = ref.watch(printerSettingsNotifierProvider.select((s) => s.connectingDeviceId != null));
    final selectedPrinterIndex = notifier.selectedPrinterIndex;

    if (printers.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(AppSizes.padding * 2),
        child: Center(
          child: Text(
            isScanning ? 'Scanning for printers...' : '(No printer detected)',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
        ),
      );
    }

    return Column(
      spacing: AppSizes.padding,
      children: List.generate(
        printers.length,
        (i) {
          final printer = printers[i];
          final isLoading = notifier.isConnectingPrinter(printer);

          return _PrinterButton(
            printer: printer,
            isSelected: selectedPrinterIndex == i || isLoading,
            isLoading: isLoading,
            enabled: !isConnecting || isLoading,
            subtitle: notifier.getDeviceSubtitle(printer),
            onTap: () => notifier.onSelectPrinter(printer),
          );
        },
      ),
    );
  }
}

class _PrinterButton extends StatelessWidget {
  final PrinterDevice printer;
  final bool isSelected;
  final bool isLoading;
  final bool enabled;
  final String subtitle;
  final VoidCallback onTap;

  const _PrinterButton({
    required this.printer,
    required this.isSelected,
    required this.isLoading,
    required this.enabled,
    required this.subtitle,
    required this.onTap,
  });

  IconData _connectionIcon(PrinterConnectionType type) {
    return switch (type) {
      PrinterConnectionType.usb => Icons.usb,
      PrinterConnectionType.bluetooth => Icons.bluetooth,
      PrinterConnectionType.ble => Icons.bluetooth_searching,
      PrinterConnectionType.network => Icons.wifi,
    };
  }

  @override
  Widget build(BuildContext context) {
    return AppButton(
      enabled: enabled,
      buttonColor: isSelected
          ? Theme.of(context).colorScheme.surfaceContainer
          : Theme.of(context).colorScheme.surfaceContainerLowest,
      borderColor: isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.outlineVariant,
      onTap: onTap,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(
                _connectionIcon(printer.connectionType),
                size: 36,
              ),
              const SizedBox(width: AppSizes.padding),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    printer.name,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ],
          ),
          if (isLoading)
            Padding(
              padding: const EdgeInsets.only(right: 2.0),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            )
          else if (isSelected)
            Icon(
              Icons.check_circle,
              size: 24,
              color: Theme.of(context).colorScheme.primary,
            ),
        ],
      ),
    );
  }
}
