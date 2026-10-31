import '../../domain/entities/product_entity.dart';

class ProductModel {
  int id;
  String createdById;
  String name;
  String imageUrl;
  String? imageBase64;
  int stock;
  int sold;
  int price;
  String category;
  String? description;
  String? createdAt;
  String? updatedAt;

  ProductModel({
    required this.id,
    required this.createdById,
    required this.name,
    required this.imageUrl,
    this.imageBase64,
    required this.stock,
    required this.sold,
    required this.price,
    this.category = 'General',
    this.description,
    this.createdAt,
    this.updatedAt,
  });

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    return ProductModel(
      id: json['id'],
      createdById: json['createdById'],
      name: json['name'],
      imageUrl: json['imageUrl'],
      imageBase64: json['imageBase64'],
      stock: json['stock'],
      sold: json['sold'],
      price: json['price'],
      category: json['category'] ?? 'General',
      description: json['description'],
      createdAt: json['createdAt'],
      updatedAt: json['updatedAt'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'createdById': createdById,
      'name': name,
      'imageUrl': imageUrl,
      'imageBase64': imageBase64,
      'stock': stock,
      'sold': sold,
      'price': price,
      'category': category,
      'description': description,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  factory ProductModel.fromEntity(ProductEntity entity) {
    return ProductModel(
      id: entity.id ?? DateTime.now().millisecondsSinceEpoch,
      createdById: entity.createdById,
      name: entity.name,
      imageUrl: entity.imageUrl,
      imageBase64: entity.imageBase64,
      stock: entity.stock,
      sold: entity.sold ?? 0,
      price: entity.price,
      category: entity.category,
      description: entity.description,
      createdAt: entity.createdAt ?? DateTime.now().toIso8601String(),
      updatedAt: entity.updatedAt ?? DateTime.now().toIso8601String(),
    );
  }

  ProductEntity toEntity() {
    return ProductEntity(
      id: id,
      createdById: createdById,
      name: name,
      imageUrl: imageUrl,
      imageBase64: imageBase64,
      stock: stock,
      sold: sold,
      price: price,
      category: category,
      description: description,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
