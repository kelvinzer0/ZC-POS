import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../utilities/console_logger.dart';
import 'database_config.dart';

class DatabaseService {
  DatabaseService._internal();

  static final DatabaseService _instance = DatabaseService._internal();

  static DatabaseService get instance => _instance;

  late Database database;

  Future<void> init() async {
    if (Platform.isWindows || Platform.isLinux) {
      // Initialize FFI
      sqfliteFfiInit();
    }

    // Get the path to the database
    String path = join(await getDatabasesPath(), DatabaseConfig.dbPath);

    if (kDebugMode) {
      // Only for development purpose
      // await dropDatabase(path);
    }

    // Create database if not exists
    File databaseFile = File(path);

    if (!await databaseFile.exists()) await databaseFile.create();

    // Open database
    database = await openDatabase(path);

    // Create tables
    await Future.wait([
      database.execute(DatabaseConfig.createUserTable),
      database.execute(DatabaseConfig.createProductTable),
      database.execute(DatabaseConfig.createTransactionTable),
      database.execute(DatabaseConfig.createOrderedProductTable),
      database.execute(DatabaseConfig.createQueuedActionTable),
    ]);

    // Ensure category column exists in Product table for existing databases
    try {
      await database.execute("ALTER TABLE '${DatabaseConfig.productTableName}' ADD COLUMN category TEXT DEFAULT 'General'");
    } catch (_) {}

    // Ensure notes column exists in OrderedProduct table for existing databases
    try {
      await database.execute("ALTER TABLE '${DatabaseConfig.orderedProductTableName}' ADD COLUMN notes TEXT");
    } catch (_) {}

    // Ensure channel column exists in Transaction table for existing databases
    try {
      await database.execute("ALTER TABLE '${DatabaseConfig.transactionTableName}' ADD COLUMN channel TEXT DEFAULT 'offline'");
    } catch (_) {}
  }

  @visibleForTesting
  Future<void> initTestDatabase({required Database testDatabase}) async {
    database = testDatabase;

    // Create tables
    await Future.wait([
      database.execute(DatabaseConfig.createUserTable),
      database.execute(DatabaseConfig.createProductTable),
      database.execute(DatabaseConfig.createTransactionTable),
      database.execute(DatabaseConfig.createOrderedProductTable),
      database.execute(DatabaseConfig.createQueuedActionTable),
    ]);

    // Ensure category column exists in Product table for existing databases
    try {
      await database.execute("ALTER TABLE '${DatabaseConfig.productTableName}' ADD COLUMN category TEXT DEFAULT 'General'");
    } catch (_) {}

    // Ensure notes column exists in OrderedProduct table for existing databases
    try {
      await database.execute("ALTER TABLE '${DatabaseConfig.orderedProductTableName}' ADD COLUMN notes TEXT");
    } catch (_) {}

    // Ensure channel column exists in Transaction table for existing databases
    try {
      await database.execute("ALTER TABLE '${DatabaseConfig.transactionTableName}' ADD COLUMN channel TEXT DEFAULT 'offline'");
    } catch (_) {}
  }

  Future<void> dropDatabase(String path) async {
    // Check if the database file exists
    File databaseFile = File(path);

    if (await databaseFile.exists()) {
      // Delete the database file
      await databaseFile.delete();

      cw('Database deleted successfully!');
    } else {
      ce('Database does not exist!');
    }
  }
}
