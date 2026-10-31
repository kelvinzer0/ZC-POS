import 'package:equatable/equatable.dart';

class ProductEntity extends Equatable {
  final int? id;
  final String createdById;
  final String name;
  final String imageUrl;
  final String? imageBase64;
  final int stock;
  final int? sold;
  final int price;
  final String category;
  final String? description;
  final String? createdAt;
  final String? updatedAt;

  const ProductEntity({
    this.id,
    required this.createdById,
    required this.name,
    required this.imageUrl,
    this.imageBase64,
    required this.stock,
    this.sold,
    required this.price,
    this.category = 'General',
    this.description,
    this.createdAt,
    this.updatedAt,
  });

  ProductEntity copyWith({
    int? id,
    String? createdById,
    String? name,
    String? imageUrl,
    String? imageBase64,
    int? stock,
    int? sold,
    int? price,
    String? category,
    String? description,
    String? createdAt,
    String? updatedAt,
  }) {
    return ProductEntity(
      id: id ?? this.id,
      createdById: createdById ?? this.createdById,
      name: name ?? this.name,
      imageUrl: imageUrl ?? this.imageUrl,
      imageBase64: imageBase64 ?? this.imageBase64,
      stock: stock ?? this.stock,
      sold: sold ?? this.sold,
      price: price ?? this.price,
      category: category ?? this.category,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    createdById,
    name,
    imageUrl,
    imageBase64,
    stock,
    sold,
    price,
    category,
    description,
    createdAt,
    updatedAt,
  ];
}
