import 'dart:io';

import 'package:app_image/app_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/themes/app_sizes.dart';
import '../../providers/account/printer_settings_notifier.dart';
import '../../providers/auth/auth_notifier.dart';
import '../../providers/main/main_notifier.dart';
import '../../providers/store/store_notifier.dart';
import '../../providers/theme/theme_notifier.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_dialog.dart';
import '../../widgets/app_snack_bar.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Account')),
      body: const SingleChildScrollView(
        padding: EdgeInsets.all(AppSizes.padding),
        child: Column(
          children: [
            _UserInfo(),
            _StoreCodeSection(),
            _ProfileButton(),
            _ThemeButton(),
            _PrinterSettingsButton(),
            _AboutButton(),
            _SignOutButton(),
          ],
        ),
      ),
    );
  }
}

class _UserInfo extends ConsumerWidget {
  const _UserInfo();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(mainNotifierProvider.select((p) => p.user));
    final receiptLogo = ref.watch(receiptLogoProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSizes.padding),
      child: Column(
        children: [
          if (receiptLogo != null && File(receiptLogo).existsSync())
            ClipRRect(
              borderRadius: BorderRadius.circular(100),
              child: Image.file(
                File(receiptLogo),
                width: 120,
                height: 120,
                fit: BoxFit.cover,
              ),
            )
          else
            AppImage(
              image: user?.imageUrl ?? '',
              width: 120,
              height: 120,
              borderRadius: BorderRadius.circular(100),
              backgroundColor: Theme.of(context).colorScheme.surface,
            ),
          const SizedBox(height: AppSizes.padding),
          Text(
            user?.name ?? '(No Name)',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppSizes.padding / 4),
          Text(
            user?.email ?? '',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _StoreCodeSection extends ConsumerWidget {
  const _StoreCodeSection();

  void _showChangeStoreDialog(BuildContext context, WidgetRef ref, String currentCode) {
    final controller = TextEditingController(text: currentCode);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: const [
            Icon(Icons.storefront_rounded),
            SizedBox(width: 8),
            Text('Ganti / Buat Toko'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Masukkan Store Code untuk menghubungkan akun ini ke toko lain, atau buat toko baru.',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: InputDecoration(
                labelText: 'Store Code',
                hintText: 'Misal: LAKKU-01',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.auto_awesome),
                  tooltip: 'Generate Kode Baru',
                  onPressed: () {
                    final newCode = ref.read(storeNotifierProvider.notifier).generateNewStoreCode();
                    controller.text = newCode;
                  },
                ),
              ),
              textCapitalization: TextCapitalization.characters,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () async {
              final newCode = controller.text.trim().toUpperCase().replaceAll(' ', '-');
              if (newCode.isNotEmpty) {
                Navigator.pop(ctx);
                await AppDialog.showProgress(() async {
                  await ref.read(storeNotifierProvider.notifier).setStoreCode(newCode);
                });
                AppSnackBar.show('Store Code berhasil diubah ke: $newCode');
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storeState = ref.watch(storeNotifierProvider);
    final activeCode = storeState.activeStoreCode;

    return Container(
      margin: const EdgeInsets.only(top: AppSizes.padding / 2),
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
              Row(
                children: [
                  Icon(Icons.storefront_rounded, size: 20, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Shared Store Code',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              if (storeState.isSyncing)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Semua akun dengan Store Code ini otomatis berbagi katalog produk, transaksi, dan setting printer/tema secara cloud.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                  fontSize: 11,
                ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: SelectableText(
                    activeCode,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      fontFamily: 'monospace',
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  tooltip: 'Salin Store Code',
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: activeCode));
                    AppSnackBar.show('Store Code disalin! Bagikan ke akun lain untuk bergabung.');
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showChangeStoreDialog(context, ref, activeCode),
                  icon: const Icon(Icons.swap_horiz_rounded, size: 16),
                  label: const Text('Ganti / Buat Baru', style: TextStyle(fontSize: 12)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await AppDialog.showProgress(() async {
                      await ref.read(storeNotifierProvider.notifier).fetchFromCloud();
                      await ref.read(storeNotifierProvider.notifier).syncToCloud();
                    });
                    AppSnackBar.show('Pengaturan & data toko berhasil disinkronkan ke cloud');
                  },
                  icon: const Icon(Icons.cloud_sync_rounded, size: 16),
                  label: const Text('Sync Cloud', style: TextStyle(fontSize: 12)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProfileButton extends StatelessWidget {
  const _ProfileButton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSizes.padding),
      child: AppButton(
        buttonColor: Theme.of(context).colorScheme.surface,
        borderColor: Theme.of(context).colorScheme.surfaceContainer,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.person,
                  size: 18,
                ),
                const SizedBox(width: AppSizes.padding / 1.5),
                Text(
                  'Profile',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 18,
            ),
          ],
        ),
        onTap: () {
          context.go('/account/profile');
        },
      ),
    );
  }
}

class _ThemeButton extends StatelessWidget {
  const _ThemeButton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSizes.padding),
      child: AppButton(
        buttonColor: Theme.of(context).colorScheme.surface,
        borderColor: Theme.of(context).colorScheme.surfaceContainer,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.format_paint_outlined,
                  size: 18,
                ),
                const SizedBox(width: AppSizes.padding / 1.5),
                Text(
                  'Theme',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 18,
            ),
          ],
        ),
        onTap: () {
          AppDialog.show(
            title: 'Theme',
            leftButtonText: 'Close',
            child: const _ThemeDialogBody(),
          );
        },
      ),
    );
  }
}

class _PrinterSettingsButton extends StatelessWidget {
  const _PrinterSettingsButton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSizes.padding),
      child: AppButton(
        buttonColor: Theme.of(context).colorScheme.surface,
        borderColor: Theme.of(context).colorScheme.surfaceContainer,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.print_outlined,
                  size: 18,
                ),
                const SizedBox(width: AppSizes.padding / 1.5),
                Text(
                  'Printer Settings',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 18,
            ),
          ],
        ),
        onTap: () {
          context.go('/account/printer-settings');
        },
      ),
    );
  }
}

class _AboutButton extends StatelessWidget {
  const _AboutButton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSizes.padding),
      child: AppButton(
        buttonColor: Theme.of(context).colorScheme.surface,
        borderColor: Theme.of(context).colorScheme.surfaceContainer,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  size: 18,
                ),
                const SizedBox(width: AppSizes.padding / 1.5),
                Text(
                  'About',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 18,
            ),
          ],
        ),
        onTap: () {
          context.go('/account/about');
        },
      ),
    );
  }
}

class _ThemeDialogBody extends ConsumerWidget {
  const _ThemeDialogBody();

  static const List<Color> _presetColors = [
    Color(0xFFE3562A), // Orange (Default)
    Color(0xFF10B981), // Emerald Green
    Color(0xFF2563EB), // Ocean Blue
    Color(0xFF6366F1), // Indigo
    Color(0xFF8B5CF6), // Purple Violet
    Color(0xFFF43F5E), // Rose Pink
    Color(0xFFDC2626), // Crimson Red
    Color(0xFFF59E0B), // Amber
    Color(0xFF0D9488), // Teal
    Color(0xFF0284C7), // Sky Blue
  ];

  void _openColorPicker(BuildContext context, WidgetRef ref, Color currentColor) {
    showDialog(
      context: context,
      builder: (ctx) => _ColorPickerModal(
        initialColor: currentColor,
        onColorSelected: (color) {
          ref.read(themeNotifierProvider.notifier).changeAccentColor(color);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeState = ref.watch(themeNotifierProvider);
    final isCustomColor = !_presetColors.any((c) => c.toARGB32() == themeState.accentColor.toARGB32());

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(
                  themeState.isLight ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                  size: 20,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: AppSizes.padding / 1.5),
                Text(
                  'Dark Mode',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            Switch(
              value: !themeState.isLight,
              onChanged: (val) {
                ref.read(themeNotifierProvider.notifier).changeBrightness(!val);
              },
            ),
          ],
        ),
        const Divider(height: AppSizes.padding * 1.5),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Warna Aksen (Accent Color)',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: themeState.accentColor,
                shape: BoxShape.circle,
                border: Border.all(color: Theme.of(context).colorScheme.outlineVariant, width: 2),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Pilih dari palet warna atau gunakan color picker kustom:',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.outline,
          ),
        ),
        const SizedBox(height: AppSizes.padding),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            ..._presetColors.map((color) {
              final isSelected = color.toARGB32() == themeState.accentColor.toARGB32();
              return InkWell(
                onTap: () {
                  ref.read(themeNotifierProvider.notifier).changeAccentColor(color);
                },
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? Colors.white : Colors.transparent,
                      width: 2.5,
                    ),
                    boxShadow: [
                      if (isSelected)
                        BoxShadow(
                          color: color.withValues(alpha: 0.6),
                          blurRadius: 8,
                          spreadRadius: 2,
                        ),
                    ],
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, size: 20, color: Colors.white)
                      : null,
                ),
              );
            }),
            InkWell(
              onTap: () => _openColorPicker(context, ref, themeState.accentColor),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  gradient: const SweepGradient(
                    colors: [
                      Colors.red,
                      Colors.yellow,
                      Colors.green,
                      Colors.cyan,
                      Colors.blue,
                      Colors.purple,
                      Colors.red,
                    ],
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isCustomColor ? Colors.white : Theme.of(context).colorScheme.outlineVariant,
                    width: isCustomColor ? 3 : 1.5,
                  ),
                  boxShadow: [
                    if (isCustomColor)
                      BoxShadow(
                        color: themeState.accentColor.withValues(alpha: 0.6),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                  ],
                ),
                child: Center(
                  child: Icon(
                    isCustomColor ? Icons.check : Icons.colorize_rounded,
                    size: 18,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ColorPickerModal extends StatefulWidget {
  final Color initialColor;
  final ValueChanged<Color> onColorSelected;

  const _ColorPickerModal({
    required this.initialColor,
    required this.onColorSelected,
  });

  @override
  State<_ColorPickerModal> createState() => _ColorPickerModalState();
}

class _ColorPickerModalState extends State<_ColorPickerModal> {
  late double _hue;
  late double _saturation;
  late double _value;
  late TextEditingController _hexController;

  @override
  void initState() {
    super.initState();
    final hsv = HSVColor.fromColor(widget.initialColor);
    _hue = hsv.hue;
    _saturation = hsv.saturation;
    _value = hsv.value;
    _hexController = TextEditingController(text: _colorToHex(widget.initialColor));
  }

  @override
  void dispose() {
    _hexController.dispose();
    super.dispose();
  }

  Color get _currentColor => HSVColor.fromAHSV(1.0, _hue, _saturation, _value).toColor();

  String _colorToHex(Color color) {
    return '#${color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
  }

  void _onHexSubmitted(String hex) {
    var cleaned = hex.replaceAll('#', '').trim();
    if (cleaned.length == 6) {
      final parsed = int.tryParse('FF$cleaned', radix: 16);
      if (parsed != null) {
        final color = Color(parsed);
        final hsv = HSVColor.fromColor(color);
        setState(() {
          _hue = hsv.hue;
          _saturation = hsv.saturation;
          _value = hsv.value;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentColor = _currentColor;

    return AlertDialog(
      title: const Text('Color Picker Kustom'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: currentColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: currentColor.withValues(alpha: 0.4),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSizes.padding),
            Text('Hue / Spektrum Warna: ${_hue.round()}°', style: Theme.of(context).textTheme.bodySmall),
            Slider(
              value: _hue,
              min: 0,
              max: 360,
              activeColor: currentColor,
              onChanged: (val) {
                setState(() {
                  _hue = val;
                  _hexController.text = _colorToHex(_currentColor);
                });
              },
            ),
            Text('Saturation (Kepekatan): ${(_saturation * 100).round()}%', style: Theme.of(context).textTheme.bodySmall),
            Slider(
              value: _saturation,
              min: 0,
              max: 1.0,
              activeColor: currentColor,
              onChanged: (val) {
                setState(() {
                  _saturation = val;
                  _hexController.text = _colorToHex(_currentColor);
                });
              },
            ),
            Text('Brightness (Kecerahan): ${(_value * 100).round()}%', style: Theme.of(context).textTheme.bodySmall),
            Slider(
              value: _value,
              min: 0.1,
              max: 1.0,
              activeColor: currentColor,
              onChanged: (val) {
                setState(() {
                  _value = val;
                  _hexController.text = _colorToHex(_currentColor);
                });
              },
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _hexController,
              decoration: const InputDecoration(
                labelText: 'Kode HEX Warna',
                hintText: '#E3562A',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onSubmitted: _onHexSubmitted,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: () {
            widget.onColorSelected(currentColor);
            Navigator.pop(context);
          },
          child: const Text('Terapkan'),
        ),
      ],
    );
  }
}

class _SignOutButton extends ConsumerWidget {
  const _SignOutButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSizes.padding),
      child: AppButton(
        buttonColor: Theme.of(context).colorScheme.surface,
        borderColor: Theme.of(context).colorScheme.surfaceContainer,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.exit_to_app_rounded,
                  size: 18,
                ),
                const SizedBox(width: AppSizes.padding / 1.5),
                Text(
                  'Sign Out',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 18,
            ),
          ],
        ),
        onTap: () {
          AppDialog.show(
            title: 'Confirm',
            text: 'Are you sure want to sign out?',
            leftButtonText: 'Cancel',
            rightButtonText: 'Sign Out',
            onTapRightButton: (context) async {
              context.pop();

              final isSyncronizing = ref.read(mainNotifierProvider).isSyncronizing;

              if (isSyncronizing) {
                AppSnackBar.showError('Cannot sign out while synchronizing data is in progress. Please wait a moment.');
                return;
              }

              final res = await AppDialog.showProgress(() async {
                return ref.read(authNotifierProvider.notifier).signOut();
              });

              if (res.isSuccess) {
                if (!context.mounted) return;
                context.go('/sign-in');
              } else {
                AppSnackBar.showError(res.error.toString());
              }
            },
          );
        },
      ),
    );
  }
}
