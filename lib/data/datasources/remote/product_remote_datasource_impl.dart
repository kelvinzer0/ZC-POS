import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/common/result.dart';
import '../../../core/constants/constants.dart';
import '../../models/product_model.dart';
import '../interfaces/product_datasource.dart';

class ProductRemoteDatasourceImpl extends ProductDatasource {
  final FirebaseFirestore _firebaseFirestore;
  final SharedPreferences? _sharedPreferences;

  ProductRemoteDatasourceImpl(this._firebaseFirestore, [this._sharedPreferences]);

  @override
  Future<Result<int>> createProduct(ProductModel product) async {
    try {
      final storeCode = _sharedPreferences?.getString(Constants.activeStoreCodeKey);
      final json = product.toJson();
      if (storeCode != null && storeCode.isNotEmpty) {
        json['storeCode'] = storeCode;
      }
      await _firebaseFirestore.collection('Product').doc("${product.id}").set(json);
      // The id has been generated in models
      return Result.success(data: product.id);
    } catch (e) {
      return Result.failure(error: e);
    }
  }

  @override
  Future<Result<void>> updateProduct(ProductModel product) async {
    try {
      final storeCode = _sharedPreferences?.getString(Constants.activeStoreCodeKey);
      final json = product.toJson();
      if (storeCode != null && storeCode.isNotEmpty) {
        json['storeCode'] = storeCode;
      }
      await _firebaseFirestore
          .collection('Product')
          .doc("${product.id}")
          .set(json, SetOptions(merge: true));

      return Result.success(data: null);
    } catch (e) {
      return Result.failure(error: e);
    }
  }

  @override
  Future<Result<void>> deleteProduct(int id) async {
    try {
      await _firebaseFirestore.collection('Product').doc("$id").delete();
      return Result.success(data: null);
    } catch (e) {
      return Result.failure(error: e);
    }
  }

  Future<void> _restoreLocalImageIfNeeded(ProductModel product) async {
    final base64Data = product.imageBase64;
    if (base64Data == null || base64Data.trim().isEmpty) return;

    // If imageUrl is a remote web URL, it can already be loaded by network
    if (product.imageUrl.startsWith('http://') || product.imageUrl.startsWith('https://')) {
      return;
    }

    // If local file already exists on this device, no need to rewrite
    if (product.imageUrl.isNotEmpty && File(product.imageUrl).existsSync()) {
      return;
    }

    // Missing local file on Device B: decode base64 from cloud and save locally
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final localDir = Directory('${appDir.path}/products');
      if (!await localDir.exists()) {
        await localDir.create(recursive: true);
      }
      final localFile = File('${localDir.path}/ProductImage_${product.id}.jpg');
      final bytes = base64Decode(base64Data);
      await localFile.writeAsBytes(bytes, flush: true);
      product.imageUrl = localFile.path;
    } catch (e) {
      debugPrint('Failed to restore product image from base64: $e');
    }
  }

  @override
  Future<Result<ProductModel?>> getProduct(int id) async {
    try {
      var res = await _firebaseFirestore.collection('Product').doc("$id").get();
      if (res.data() == null) return Result.success(data: null);
      final product = ProductModel.fromJson(res.data()!);
      await _restoreLocalImageIfNeeded(product);
      return Result.success(data: product);
    } catch (e) {
      return Result.failure(error: e);
    }
  }

  @override
  Future<Result<List<ProductModel>>> getAllUserProducts(String userId) async {
    try {
      final storeCode = _sharedPreferences?.getString(Constants.activeStoreCodeKey);
      QuerySnapshot<Map<String, dynamic>> res;
      if (storeCode != null && storeCode.isNotEmpty) {
        res = await _firebaseFirestore
            .collection('Product')
            .where('storeCode', isEqualTo: storeCode)
            .get();
        if (res.docs.isEmpty) {
          res = await _firebaseFirestore
              .collection('Product')
              .where('createdById', isEqualTo: userId)
              .get();
        }
      } else {
        res = await _firebaseFirestore
            .collection('Product')
            .where('createdById', isEqualTo: userId)
            .get();
      }
      var products = res.docs.map((e) => ProductModel.fromJson(e.data())).toList();
      for (final p in products) {
        await _restoreLocalImageIfNeeded(p);
      }
      products.sort((a, b) => (b.createdAt ?? '').compareTo(a.createdAt ?? ''));
      return Result.success(data: products);
    } catch (e) {
      return Result.failure(error: e);
    }
  }

  @override
  Future<Result<List<ProductModel>>> getUserProducts(
    String userId, {
    String orderBy = 'createdAt',
    String sortBy = 'DESC',
    int limit = 10,
    int? offset,
    String? contains,
  }) async {
    try {
      final storeCode = _sharedPreferences?.getString(Constants.activeStoreCodeKey);
      final collectionRef = _firebaseFirestore.collection('Product');
      QuerySnapshot<Map<String, dynamic>> rawProducts;

      if (storeCode != null && storeCode.isNotEmpty) {
        rawProducts = await collectionRef.where('storeCode', isEqualTo: storeCode).get();
        if (rawProducts.docs.isEmpty) {
          rawProducts = await collectionRef.where('createdById', isEqualTo: userId).get();
        }
      } else {
        rawProducts = await collectionRef.where('createdById', isEqualTo: userId).get();
      }

      var products = rawProducts.docs.map((e) => ProductModel.fromJson(e.data())).toList();
      for (final p in products) {
        await _restoreLocalImageIfNeeded(p);
      }

      // Sort in-memory to prevent FAILED_PRECONDITION (requiring composite indexes)
      products.sort((a, b) {
        final aVal = a.createdAt ?? '';
        final bVal = b.createdAt ?? '';
        return sortBy == 'DESC' ? bVal.compareTo(aVal) : aVal.compareTo(bVal);
      });

      if (contains != null && contains.trim().isNotEmpty) {
        final queryText = contains.trim().toLowerCase();
        products = products.where((p) {
          return p.name.toLowerCase().contains(queryText) ||
              p.category.toLowerCase().contains(queryText) ||
              '${p.id}'.contains(queryText);
        }).toList();
      }

      if (offset != null && offset > 0) {
        products = products.skip(offset).toList();
      }
      if (products.length > limit) {
        products = products.take(limit).toList();
      }

      return Result.success(data: products);
    } catch (e) {
      return Result.failure(error: e);
    }
  }
}
