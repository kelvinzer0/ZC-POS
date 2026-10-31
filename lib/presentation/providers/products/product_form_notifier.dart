import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;

import '../../../app/di/app_providers.dart';
import '../../../core/common/result.dart';
import '../../../core/utilities/console_logger.dart';
import '../../../domain/entities/product_entity.dart';
import '../../../domain/usecases/product_usecases.dart';
import '../../../domain/usecases/storage_usecases.dart';
import '../auth/auth_notifier.dart';
import 'product_form_state.dart';
import 'products_notifier.dart';

final productFormNotifierProvider = NotifierProvider.autoDispose<ProductFormNotifier, ProductFormState>(
  ProductFormNotifier.new,
);

class ProductFormNotifier extends AutoDisposeNotifier<ProductFormState> {
  @override
  ProductFormState build() {
    return const ProductFormState();
  }

  String _requireUserId() {
    final authState = ref.read(authNotifierProvider);
    if (authState.isAuthenticated) return authState.user!.id;
    throw 'Unauthenticated!';
  }

  Future<String?> _compressImageToBase64(File file) async {
    try {
      final bytes = await file.readAsBytes();
      var decoded = img.decodeImage(bytes);
      if (decoded != null) {
        if (decoded.width > 600 || decoded.height > 600) {
          if (decoded.width >= decoded.height) {
            decoded = img.copyResize(decoded, width: 600);
          } else {
            decoded = img.copyResize(decoded, height: 600);
          }
        }
        final compressed = img.encodeJpg(decoded, quality: 80);
        return base64Encode(compressed);
      }
      return base64Encode(bytes);
    } catch (e) {
      debugPrint('Failed to compress image to base64: $e');
      return null;
    }
  }

  Future<void> initProductForm(int? productId) async {
    if (productId == null) {
      state = state.copyWith(isLoaded: true);
      return;
    }

    try {
      final productRepository = ref.read(productRepositoryProvider);
      var res = await GetProductUsecase(productRepository).call(productId);

      if (res.isSuccess) {
        var product = res.data;

        state = state.copyWith(
          imageUrl: product?.imageUrl,
          imageBase64: product?.imageBase64,
          name: product?.name,
          price: product?.price,
          stock: product?.stock,
          category: product?.category ?? 'General',
          description: product?.description,
          isLoaded: true,
        );
        return;
      }
    } catch (_) {}

    state = state.copyWith(isLoaded: true);
  }

  Future<Result<int>> createProduct() async {
    try {
      final userId = _requireUserId();
      final storageRepository = ref.read(storageRepositoryProvider);
      final productRepository = ref.read(productRepositoryProvider);

      var imageUrl = state.imageUrl;
      var imageBase64 = state.imageBase64;

      if (state.imageFile != null) {
        imageBase64 = await _compressImageToBase64(state.imageFile!);
        final res = await UploadProductImageUsecase(storageRepository).call(state.imageFile!.path);
        if (res.isSuccess && res.data != null && res.data!.isNotEmpty) {
          imageUrl = res.data;
        } else {
          imageUrl = state.imageFile!.path;
        }
      }

      cl('imageUrl $imageUrl');

      final resolvedName = (state.name != null && state.name!.trim().isNotEmpty)
          ? state.name!.trim()
          : 'Unnamed Product';

      var product = ProductEntity(
        createdById: userId,
        name: resolvedName,
        imageUrl: imageUrl ?? '',
        imageBase64: imageBase64,
        stock: state.stock ?? 0,
        price: state.price ?? 0,
        category: (state.category == null || state.category!.trim().isEmpty) ? 'General' : state.category!.trim(),
        description: state.description ?? '',
      );

      var res = await CreateProductUsecase(productRepository).call(product);

      // Refresh products
      try {
        ref.read(productsNotifierProvider.notifier).getAllProducts();
      } catch (_) {}

      return res;
    } catch (e) {
      return Result.failure(error: e);
    }
  }

  Future<Result<void>> updatedProduct(int id) async {
    try {
      final userId = _requireUserId();
      final storageRepository = ref.read(storageRepositoryProvider);
      final productRepository = ref.read(productRepositoryProvider);

      var imageUrl = state.imageUrl;
      var imageBase64 = state.imageBase64;

      if (state.imageFile != null) {
        imageBase64 = await _compressImageToBase64(state.imageFile!);
        final res = await UploadProductImageUsecase(storageRepository).call(state.imageFile!.path);
        if (res.isSuccess && res.data != null && res.data!.isNotEmpty) {
          imageUrl = res.data;
        } else {
          imageUrl = state.imageFile!.path;
        }
      }

      cl('imageUrl $imageUrl');

      final resolvedName = (state.name != null && state.name!.trim().isNotEmpty)
          ? state.name!.trim()
          : 'Unnamed Product';

      var product = ProductEntity(
        id: id,
        createdById: userId,
        name: resolvedName,
        imageUrl: imageUrl ?? '',
        imageBase64: imageBase64,
        stock: state.stock ?? 0,
        price: state.price ?? 0,
        category: (state.category == null || state.category!.trim().isEmpty) ? 'General' : state.category!.trim(),
        description: state.description ?? '',
      );

      var res = await UpdateProductUsecase(productRepository).call(product);

      // Refresh products
      try {
        ref.read(productsNotifierProvider.notifier).getAllProducts();
      } catch (_) {}

      return res;
    } catch (e) {
      return Result.failure(error: e);
    }
  }

  Future<Result<void>> deleteProduct(int id) async {
    try {
      final productRepository = ref.read(productRepositoryProvider);
      var res = await DeleteProductUsecase(productRepository).call(id);

      // Refresh products
      ref.read(productsNotifierProvider.notifier).getAllProducts();

      return res;
    } catch (e) {
      return Result.failure(error: e);
    }
  }

  void onChangedImage(File value) {
    state = state.copyWith(imageFile: value);
  }

  void onChangedName(String value) {
    state = state.copyWith(name: value);
  }

  void onChangedPrice(String value) {
    state = state.copyWith(price: int.tryParse(value));
  }

  void onChangedStock(String value) {
    state = state.copyWith(stock: int.tryParse(value));
  }

  void onChangedDesc(String value) {
    state = state.copyWith(description: value);
  }

  void onChangedCategory(String value) {
    state = state.copyWith(category: value);
  }
}
