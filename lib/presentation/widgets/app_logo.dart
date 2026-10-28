import 'dart:io';

import 'package:app_image/app_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/assets/assets.dart';
import '../providers/account/printer_settings_notifier.dart';

class AppLogo extends ConsumerWidget {
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  const AppLogo({
    super.key,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logoPath = ref.watch(receiptLogoProvider);

    if (logoPath != null && logoPath.isNotEmpty) {
      final file = File(logoPath);
      if (file.existsSync()) {
        return ClipRRect(
          borderRadius: borderRadius ?? BorderRadius.circular(16),
          child: Image.file(
            file,
            width: width,
            height: height,
            fit: fit,
            errorBuilder: (context, error, stackTrace) => _defaultLogo(),
          ),
        );
      }
    }

    return _defaultLogo();
  }

  Widget _defaultLogo() {
    return AppImage(
      image: Assets.welcome,
      imgProvider: ImgProvider.assetImage,
      width: width,
      height: height,
    );
  }
}
