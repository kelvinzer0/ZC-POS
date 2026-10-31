import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../../../core/common/result.dart';
import '../../../core/constants/constants.dart';
import '../../../core/services/database/database_config.dart';
import '../../../core/services/database/database_service.dart';
import '../../models/product_model.dart';
import '../interfaces/product_datasource.dart';

class ProductLocalDatasourceImpl extends ProductDatasource {
  final DatabaseService _databaseService;
  final SharedPreferences? _sharedPreferences;

  ProductLocalDatasourceImpl(this._databaseService, [this._sharedPreferences]);

  @override
  Future<Result<int>> createProduct(ProductModel product) async {
    try {
      final storeCode = product.storeCode ?? _sharedPreferences?.getString(Constants.activeStoreCodeKey);
      final json = product.toJson();
      if (storeCode != null && storeCode.isNotEmpty) {
        json['storeCode'] = storeCode;
      }

      await _databaseService.database.insert(
        DatabaseConfig.productTableName,
        json,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // The id has been generated in models
      return Result.success(data: product.id);
    } catch (e) {
      return Result.failure(error: e);
    }
  }

  @override
  Future<Result<void>> updateProduct(ProductModel product) async {
    try {
      final storeCode = product.storeCode ?? _sharedPreferences?.getString(Constants.activeStoreCodeKey);
      final json = product.toJson();
      if (storeCode != null && storeCode.isNotEmpty) {
        json['storeCode'] = storeCode;
      }

      await _databaseService.database.update(
        DatabaseConfig.productTableName,
        json,
        where: 'id = ?',
        whereArgs: [product.id],
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      return Result.success(data: null);
    } catch (e) {
      return Result.failure(error: e);
    }
  }

  @override
  Future<Result<void>> deleteProduct(int id) async {
    try {
      await _databaseService.database.delete(
        DatabaseConfig.productTableName,
        where: 'id = ?',
        whereArgs: [id],
      );

      return Result.success(data: null);
    } catch (e) {
      return Result.failure(error: e);
    }
  }

  @override
  Future<Result<ProductModel?>> getProduct(int id) async {
    try {
      var res = await _databaseService.database.query(
        DatabaseConfig.productTableName,
        where: 'id = ?',
        whereArgs: [id],
      );

      if (res.isEmpty) return Result.success(data: null);

      return Result.success(data: ProductModel.fromJson(res.first));
    } catch (e) {
      return Result.failure(error: e);
    }
  }

  @override
  Future<Result<List<ProductModel>>> getAllUserProducts(String userId) async {
    try {
      final storeCode = _sharedPreferences?.getString(Constants.activeStoreCodeKey);
      List<Map<String, dynamic>> res;
      if (storeCode != null && storeCode.isNotEmpty) {
        res = await _databaseService.database.query(
          DatabaseConfig.productTableName,
          where: 'storeCode = ? OR createdById = ?',
          whereArgs: [storeCode, userId],
        );
      } else {
        res = await _databaseService.database.query(
          DatabaseConfig.productTableName,
          where: 'createdById = ?',
          whereArgs: [userId],
        );
      }

      return Result.success(
        data: res.map((e) => ProductModel.fromJson(e)).toList(),
      );
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
      List<Map<String, dynamic>> res;
      final searchPattern = "%${contains ?? ''}%";

      if (storeCode != null && storeCode.isNotEmpty) {
        res = await _databaseService.database.query(
          DatabaseConfig.productTableName,
          where: '(storeCode = ? OR createdById = ?) AND (name LIKE ? OR category LIKE ? OR id LIKE ?)',
          whereArgs: [storeCode, userId, searchPattern, searchPattern, searchPattern],
          orderBy: '$orderBy $sortBy',
          limit: limit,
          offset: offset,
        );
      } else {
        res = await _databaseService.database.query(
          DatabaseConfig.productTableName,
          where: 'createdById = ? AND (name LIKE ? OR category LIKE ? OR id LIKE ?)',
          whereArgs: [userId, searchPattern, searchPattern, searchPattern],
          orderBy: '$orderBy $sortBy',
          limit: limit,
          offset: offset,
        );
      }

      return Result.success(
        data: res.map((e) => ProductModel.fromJson(e)).toList(),
      );
    } catch (e) {
      return Result.failure(error: e);
    }
  }
}
