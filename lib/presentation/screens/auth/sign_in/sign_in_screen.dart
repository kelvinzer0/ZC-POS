import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/di/app_providers.dart';
import '../../../../core/themes/app_sizes.dart';
import '../../../providers/auth/auth_notifier.dart';
import '../../../providers/store/store_notifier.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/app_dialog.dart';
import '../../../widgets/app_logo.dart';
import '../../../widgets/app_snack_bar.dart';
import '../../../widgets/app_text_field.dart';

class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  late final TextEditingController _storeCodeController;

  @override
  void initState() {
    super.initState();
    final currentCode = ref.read(storeServiceProvider).activeStoreCode;
    _storeCodeController = TextEditingController(text: currentCode);
  }

  @override
  void dispose() {
    _storeCodeController.dispose();
    super.dispose();
  }

  void _generateNewStoreCode() {
    final newCode = ref.read(storeNotifierProvider.notifier).generateNewStoreCode();
    _storeCodeController.text = newCode;
    AppSnackBar.show('Kode toko baru dibuat: $newCode');
  }

  Future<void> _onSignIn() async {
    final code = _storeCodeController.text.trim().toUpperCase().replaceAll(' ', '-');
    if (code.isNotEmpty) {
      await ref.read(storeNotifierProvider.notifier).setStoreCode(code);
    }

    final res = await AppDialog.showProgress(() async {
      return ref.read(authNotifierProvider.notifier).signIn();
    });

    if (res.isSuccess) {
      ref.read(appRoutesProvider).router.refresh();
    } else {
      AppDialog.showError(error: res.error?.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: AppSizes.padding * 1.5, vertical: AppSizes.padding),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const AppLogo(
                    width: 140,
                    height: 140,
                  ),
                  const SizedBox(height: AppSizes.padding),
                  Text(
                    'Welcome!',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Warung Lakku POS',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                  ),
                  const SizedBox(height: 24),

                  // Store Code Section
                  Container(
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
                          children: [
                            Icon(Icons.storefront_rounded, size: 20, color: Theme.of(context).colorScheme.primary),
                            const SizedBox(width: 8),
                            Text(
                              'Kode Toko (Store Code)',
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Gunakan Store Code yang sama pada 2 perangkat/akun untuk mengelola toko & menyinkronkan data secara cloud.',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.outline,
                                fontSize: 11,
                              ),
                        ),
                        const SizedBox(height: 12),
                        AppTextField(
                          controller: _storeCodeController,
                          labelText: 'Store Code',
                          hintText: 'Misal: LAKKU-01',
                          suffixWidget: IconButton(
                            icon: const Icon(Icons.auto_awesome, size: 20),
                            tooltip: 'Generate Kode Toko Baru',
                            onPressed: _generateNewStoreCode,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                            onPressed: _generateNewStoreCode,
                            icon: const Icon(Icons.add_business_rounded, size: 16),
                            label: const Text('Buat Toko Baru', style: TextStyle(fontSize: 12)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  AppButton(
                    text: 'Sign In With Google',
                    onTap: _onSignIn,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
