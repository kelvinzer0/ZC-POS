import 'dart:io';

import 'package:app_image/app_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app/di/app_providers.dart';
import '../../../core/themes/app_sizes.dart';
import '../../providers/account/account_notifier.dart';
import '../../providers/main/main_notifier.dart';
import '../../providers/store/store_notifier.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_dialog.dart';
import '../../widgets/app_icon_button.dart';
import '../../widgets/app_progress_indicator.dart';
import '../../widgets/app_snack_bar.dart';
import '../../widgets/app_text_field.dart';

class ProfileFormScreen extends ConsumerStatefulWidget {
  const ProfileFormScreen({super.key});

  @override
  ConsumerState<ProfileFormScreen> createState() => _ProfileFormScreenState();
}

class _ProfileFormScreenState extends ConsumerState<ProfileFormScreen> {
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final phoneController = TextEditingController();
  final storeCodeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref.read(accountNotifierProvider.notifier).initProfileForm();

      final state = ref.read(accountNotifierProvider);
      nameController.text = state.name ?? '';
      emailController.text = state.email ?? '';
      phoneController.text = state.phone ?? '';
      storeCodeController.text = ref.read(storeServiceProvider).activeStoreCode;
    });
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    storeCodeController.dispose();
    super.dispose();
  }

  void onTapImage() async {
    try {
      final pickedFile = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 50,
      );

      if (pickedFile == null) return;

      CroppedFile? croppedFile;
      try {
        croppedFile = await ImageCropper().cropImage(
          sourcePath: pickedFile.path,
          aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
          uiSettings: [
            AndroidUiSettings(toolbarTitle: 'Crop Photo'),
            IOSUiSettings(title: 'Crop Photo'),
          ],
        );
      } catch (e) {
        debugPrint('Crop failed or skipped: $e');
      }

      final file = croppedFile != null ? File(croppedFile.path) : File(pickedFile.path);
      ref.read(accountNotifierProvider.notifier).onChangedImage(file);
    } catch (e) {
      debugPrint('Error picking image: $e');
      AppSnackBar.show('Gagal memilih gambar');
    }
  }

  void updatedUser() async {
    // Sync controller values to notifier state
    final name = nameController.text.trim();
    if (name.isNotEmpty) {
      ref.read(accountNotifierProvider.notifier).onChangedName(name);
    }
    final email = emailController.text.trim();
    if (email.isNotEmpty) {
      ref.read(accountNotifierProvider.notifier).onChangedEmail(email);
    }
    final phone = phoneController.text.trim();
    if (phone.isNotEmpty) {
      ref.read(accountNotifierProvider.notifier).onChangedPhone(phone);
    }

    final code = storeCodeController.text.trim().toUpperCase().replaceAll(' ', '-');
    if (code.isNotEmpty) {
      await ref.read(storeNotifierProvider.notifier).setStoreCode(code);
    }

    var res = await AppDialog.showProgress(() {
      return ref.read(accountNotifierProvider.notifier).updatedUser();
    });

    if (res.isSuccess) {
      if (!mounted) return;
      Navigator.of(context).pop();
      AppSnackBar.show('Profile updated');

      // Refresh user data
      try {
        ref.read(mainNotifierProvider.notifier).getAndSyncAllUserData();
      } catch (_) {}
    } else {
      AppDialog.showError(error: res.error.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final account = ref.read(accountNotifierProvider.notifier);

    final isLoaded = ref.watch(accountNotifierProvider.select((s) => s.isLoaded));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        titleSpacing: 0,
      ),
      body: !isLoaded
          ? const AppProgressIndicator()
          : SingleChildScrollView(
              padding: const EdgeInsets.all(AppSizes.padding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ImageSection(onTapImage: onTapImage),
                  _StoreCodeField(
                    controller: storeCodeController,
                    onGenerate: () {
                      final newCode = ref.read(storeNotifierProvider.notifier).generateNewStoreCode();
                      storeCodeController.text = newCode;
                    },
                  ),
                  _NameField(controller: nameController, onChanged: account.onChangedName),
                  _EmailField(controller: emailController, onChanged: account.onChangedEmail),
                  _PhoneField(controller: phoneController, onChanged: account.onChangedPhone),
                  _UpdateButton(onTap: updatedUser),
                ],
              ),
            ),
    );
  }
}

class _ImageSection extends ConsumerWidget {
  final VoidCallback onTapImage;

  const _ImageSection({required this.onTapImage});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final imageFile = ref.watch(accountNotifierProvider.select((s) => s.imageFile));
    final imageUrl = ref.watch(accountNotifierProvider.select((s) => s.imageUrl));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Profile Image',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: AppSizes.padding / 2),
        Stack(
          children: [
            GestureDetector(
              onTap: onTapImage,
              child: AppImage(
                image: imageFile?.path ?? imageUrl ?? '',
                width: 100,
                height: 100,
                borderRadius: BorderRadius.circular(AppSizes.radius),
                backgroundColor: Theme.of(context).colorScheme.surface,
                border: Border.all(
                  width: 1,
                  color: Theme.of(context).colorScheme.primaryContainer,
                ),
                errorWidget: Icon(
                  Icons.image,
                  color: Theme.of(context).colorScheme.surfaceDim,
                  size: 32,
                ),
              ),
            ),
            Positioned(
              right: 8,
              bottom: 8,
              child: AppIconButton(
                icon: Icons.camera_alt_rounded,
                iconSize: 14,
                borderRadius: 8,
                padding: const EdgeInsets.all(6),
                onTap: onTapImage,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _StoreCodeField extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onGenerate;

  const _StoreCodeField({
    required this.controller,
    required this.onGenerate,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSizes.padding),
      child: AppTextField(
        controller: controller,
        labelText: 'Store Code (Kode Toko)',
        hintText: 'Misal: LAKKU-01',
        suffixWidget: IconButton(
          icon: const Icon(Icons.auto_awesome, size: 20),
          tooltip: 'Generate Kode Toko Baru',
          onPressed: onGenerate,
        ),
      ),
    );
  }
}

class _NameField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const _NameField({
    required this.controller,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSizes.padding),
      child: AppTextField(
        controller: controller,
        labelText: 'Name',
        hintText: 'Your name...',
        onChanged: onChanged,
      ),
    );
  }
}

class _EmailField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const _EmailField({
    required this.controller,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSizes.padding),
      child: AppTextField(
        controller: controller,
        labelText: 'Email',
        hintText: 'Your email...',
        onChanged: onChanged,
      ),
    );
  }
}

class _PhoneField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const _PhoneField({
    required this.controller,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSizes.padding),
      child: AppTextField(
        controller: controller,
        labelText: 'Phone Number',
        hintText: 'Your phone number...',
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        onChanged: onChanged,
      ),
    );
  }
}

class _UpdateButton extends StatelessWidget {
  final VoidCallback onTap;

  const _UpdateButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        top: AppSizes.padding * 1.5,
        bottom: AppSizes.padding * 2,
      ),
      child: AppButton(
        text: 'Update',
        onTap: onTap,
      ),
    );
  }
}
