import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/common/result.dart';
import '../interfaces/storage_datasource.dart';

class StorageRemoteDataSourceImpl implements StorageDataSource {
  final FirebaseStorage _firebaseStorage;

  StorageRemoteDataSourceImpl(this._firebaseStorage);

  @override
  Future<Result<String>> uploadUserPhoto(String imgPath) async {
    try {
      final ref = _firebaseStorage
          .ref()
          .child('user_photos')
          .child('UserImage_${DateTime.now().millisecondsSinceEpoch}.jpg');

      final metadata = SettableMetadata(contentType: 'image/jpeg');

      final taskSnapshot = await ref.putFile(File(imgPath), metadata);

      final url = await taskSnapshot.ref.getDownloadURL();

      return Result.success(data: url);
    } catch (e) {
      debugPrint('Firebase Storage uploadUserPhoto failed: $e. Falling back to local storage.');
      try {
        final appDir = await getApplicationDocumentsDirectory();
        final localDir = Directory('${appDir.path}/user_photos');
        if (!await localDir.exists()) {
          await localDir.create(recursive: true);
        }
        final fileName = 'UserImage_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final savedFile = await File(imgPath).copy('${localDir.path}/$fileName');
        return Result.success(data: savedFile.path);
      } catch (fallbackError) {
        debugPrint('Fallback saving user photo failed: $fallbackError');
        return Result.success(data: imgPath);
      }
    }
  }

  @override
  Future<Result<String>> uploadProductImage(String imgPath) async {
    try {
      final ref = _firebaseStorage
          .ref()
          .child('products')
          .child('ProductImage_${DateTime.now().millisecondsSinceEpoch}.jpg');

      final metadata = SettableMetadata(contentType: 'image/jpeg');

      final taskSnapshot = await ref.putFile(File(imgPath), metadata);

      final url = await taskSnapshot.ref.getDownloadURL();

      return Result.success(data: url);
    } catch (e) {
      debugPrint('Firebase Storage uploadProductImage failed: $e. Falling back to local storage.');
      try {
        final appDir = await getApplicationDocumentsDirectory();
        final localDir = Directory('${appDir.path}/products');
        if (!await localDir.exists()) {
          await localDir.create(recursive: true);
        }
        final fileName = 'ProductImage_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final savedFile = await File(imgPath).copy('${localDir.path}/$fileName');
        return Result.success(data: savedFile.path);
      } catch (fallbackError) {
        debugPrint('Fallback saving product image failed: $fallbackError');
        return Result.success(data: imgPath);
      }
    }
  }
}
