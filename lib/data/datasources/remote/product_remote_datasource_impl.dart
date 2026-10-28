import 'package:cloud_firestore/cloud_firestore.dart';
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

  @override
  Future<Result<ProductModel?>> getProduct(int id) async {
    try {
      var res = await _firebaseFirestore.collection('Product').doc("$id").get();
      if (res.data() == null) return Result.success(data: null);
      return Result.success(data: ProductModel.fromJson(res.data()!));
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
