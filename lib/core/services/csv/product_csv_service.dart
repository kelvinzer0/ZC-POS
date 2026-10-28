import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../../domain/entities/product_entity.dart';
import '../../../domain/repositories/product_repository.dart';
import '../../../domain/usecases/product_usecases.dart';

class ProductCsvService {
  ProductCsvService._();

  static final ProductCsvService instance = ProductCsvService._();

  /// Converts a list of products to a well-formatted CSV string
  String exportToCsv(List<ProductEntity> products) {
    final buffer = StringBuffer();
    // CSV Header
    buffer.writeln('id,name,category,price,stock,sold,description,imageUrl');

    for (final product in products) {
      final id = product.id?.toString() ?? '';
      final name = _escape(product.name);
      final category = _escape(product.category.isEmpty ? 'General' : product.category);
      final price = product.price.toString();
      final stock = product.stock.toString();
      final sold = product.sold.toString();
      final description = _escape(product.description ?? '');
      final imageUrl = _escape(product.imageUrl);

      buffer.writeln('$id,$name,$category,$price,$stock,$sold,$description,$imageUrl');
    }

    return buffer.toString();
  }

  /// Writes CSV content to a local backup file and returns its path
  Future<String> saveCsvToFile(String csvContent) async {
    final directory = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final file = File('${directory.path}/zcpos_products_backup_$timestamp.csv');
    await file.writeAsString(csvContent);
    return file.path;
  }

  /// Robust CSV parser handling multi-line fields, escaped quotes, and commas
  List<List<String>> parseCsv(String input) {
    final rows = <List<String>>[];
    var currentRow = <String>[];
    final currentCell = StringBuffer();
    bool insideQuotes = false;

    for (int i = 0; i < input.length; i++) {
      final char = input[i];

      if (char == '"') {
        if (insideQuotes && i + 1 < input.length && input[i + 1] == '"') {
          // Escaped double quote
          currentCell.write('"');
          i++;
        } else {
          insideQuotes = !insideQuotes;
        }
      } else if (char == ',' && !insideQuotes) {
        currentRow.add(currentCell.toString());
        currentCell.clear();
      } else if ((char == '\n' || char == '\r') && !insideQuotes) {
        if (char == '\r' && i + 1 < input.length && input[i + 1] == '\n') {
          i++;
        }
        currentRow.add(currentCell.toString());
        currentCell.clear();
        if (currentRow.any((c) => c.trim().isNotEmpty)) {
          rows.add(currentRow);
        }
        currentRow = [];
      } else {
        currentCell.write(char);
      }
    }

    if (currentCell.isNotEmpty || currentRow.isNotEmpty) {
      currentRow.add(currentCell.toString());
      if (currentRow.any((c) => c.trim().isNotEmpty)) {
        rows.add(currentRow);
      }
    }

    return rows;
  }

  /// Mass upserts products from CSV content
  Future<({int inserted, int updated, int failed})> upsertProductsFromCsv({
    required String csvContent,
    required List<ProductEntity> currentProducts,
    required ProductRepository repository,
    required String userId,
  }) async {
    final rows = parseCsv(csvContent);
    if (rows.isEmpty) {
      return (inserted: 0, updated: 0, failed: 0);
    }

    // Determine header mapping
    final firstRow = rows.first.map((e) => e.trim().toLowerCase()).toList();
    final bool hasHeader = firstRow.contains('name') || firstRow.contains('price');

    int idIdx = firstRow.indexOf('id');
    int nameIdx = firstRow.indexOf('name');
    int catIdx = firstRow.indexOf('category');
    int priceIdx = firstRow.indexOf('price');
    int stockIdx = firstRow.indexOf('stock');
    int soldIdx = firstRow.indexOf('sold');
    int descIdx = firstRow.indexOf('description');
    int imgIdx = firstRow.indexOf('imageurl');

    if (imgIdx == -1) imgIdx = firstRow.indexOf('image');

    // Default indices if no explicit header
    if (!hasHeader) {
      idIdx = 0;
      nameIdx = 1;
      catIdx = 2;
      priceIdx = 3;
      stockIdx = 4;
      soldIdx = 5;
      descIdx = 6;
      imgIdx = 7;
    }

    final dataRows = hasHeader ? rows.sublist(1) : rows;

    int inserted = 0;
    int updated = 0;
    int failed = 0;

    for (int i = 0; i < dataRows.length; i++) {
      final row = dataRows[i];
      if (row.isEmpty || row.every((c) => c.trim().isEmpty)) continue;

      try {
        final rawId = _getCell(row, idIdx);
        final name = _getCell(row, nameIdx);
        final category = _getCell(row, catIdx);
        final rawPrice = _getCell(row, priceIdx);
        final rawStock = _getCell(row, stockIdx);
        final rawSold = _getCell(row, soldIdx);
        final description = _getCell(row, descIdx);
        final imageUrl = _getCell(row, imgIdx);

        if (name.isEmpty) {
          failed++;
          continue;
        }

        final parsedId = int.tryParse(rawId);
        final parsedPrice = int.tryParse(rawPrice.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
        final parsedStock = int.tryParse(rawStock.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
        final parsedSold = int.tryParse(rawSold.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;

        // Find existing product by ID or by Name (case-insensitive)
        ProductEntity? existing;
        if (parsedId != null && parsedId > 0) {
          existing = currentProducts.where((p) => p.id == parsedId).firstOrNull;
        }
        existing ??= currentProducts.where((p) => p.name.trim().toLowerCase() == name.toLowerCase()).firstOrNull;

        if (existing != null) {
          // Update existing product
          final updatedProduct = existing.copyWith(
            name: name,
            category: category.isNotEmpty ? category : existing.category,
            price: parsedPrice > 0 ? parsedPrice : existing.price,
            stock: parsedStock,
            sold: parsedSold > 0 ? parsedSold : existing.sold,
            description: description.isNotEmpty ? description : existing.description,
            imageUrl: imageUrl.isNotEmpty ? imageUrl : existing.imageUrl,
            updatedAt: DateTime.now().toIso8601String(),
          );

          final res = await UpdateProductUsecase(repository).call(updatedProduct);
          if (res.isSuccess) {
            updated++;
          } else {
            failed++;
          }
        } else {
          // Create new product
          final newProduct = ProductEntity(
            id: parsedId ?? (DateTime.now().millisecondsSinceEpoch + i),
            createdById: userId,
            name: name,
            category: category.isNotEmpty ? category : 'General',
            price: parsedPrice,
            stock: parsedStock,
            sold: parsedSold,
            description: description.isNotEmpty ? description : null,
            imageUrl: imageUrl.isNotEmpty ? imageUrl : 'https://picsum.photos/200',
            createdAt: DateTime.now().toIso8601String(),
            updatedAt: DateTime.now().toIso8601String(),
          );

          final res = await CreateProductUsecase(repository).call(newProduct);
          if (res.isSuccess) {
            inserted++;
          } else {
            failed++;
          }
        }
      } catch (_) {
        failed++;
      }
    }

    return (inserted: inserted, updated: updated, failed: failed);
  }

  String _getCell(List<String> row, int index) {
    if (index >= 0 && index < row.length) {
      return row[index].trim();
    }
    return '';
  }

  String _escape(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n') || value.contains('\r')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }
}
