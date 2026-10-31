import '../../domain/entities/transaction_entity.dart';
import 'ordered_product_model.dart';
import 'user_model.dart';

class TransactionModel {
  int id;
  String? storeCode;
  String paymentMethod;
  String channel;
  String? customerName;
  String? description;
  String createdById;
  UserModel? createdBy;
  List<OrderedProductModel>? orderedProducts;
  int shippingFee;
  int receivedAmount;
  int returnAmount;
  int totalAmount;
  int totalOrderedProduct;
  String? createdAt;
  String? updatedAt;

  TransactionModel({
    required this.id,
    this.storeCode,
    required this.paymentMethod,
    this.channel = 'offline',
    this.customerName,
    this.description,
    required this.createdById,
    this.createdBy,
    this.orderedProducts,
    this.shippingFee = 0,
    required this.receivedAmount,
    required this.returnAmount,
    required this.totalAmount,
    required this.totalOrderedProduct,
    this.createdAt,
    this.updatedAt,
  });

  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    return TransactionModel(
      id: json['id'],
      storeCode: json['storeCode'],
      paymentMethod: json['paymentMethod'],
      channel: json['channel'] ?? 'offline',
      customerName: json['customerName'],
      description: json['description'],
      createdById: json['createdById'],
      createdBy: json['createdBy'],
      orderedProducts: json['orderedProducts'] != null
          ? (json['orderedProducts'] as List).map((e) => OrderedProductModel.fromJson(e)).toList()
          : null,
      shippingFee: json['shippingFee'] ?? 0,
      receivedAmount: json['receivedAmount'],
      returnAmount: json['returnAmount'],
      totalAmount: json['totalAmount'],
      totalOrderedProduct: json['totalOrderedProduct'],
      createdAt: json['createdAt'],
      updatedAt: json['updatedAt'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'storeCode': storeCode,
      'paymentMethod': paymentMethod,
      'channel': channel,
      'customerName': customerName,
      'description': description,
      'createdById': createdById,
      'createdBy': createdBy,
      'orderedProducts': orderedProducts?.map((e) => e.toJson()).toList(),
      'shippingFee': shippingFee,
      'receivedAmount': receivedAmount,
      'returnAmount': returnAmount,
      'totalAmount': totalAmount,
      'totalOrderedProduct': totalOrderedProduct,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  factory TransactionModel.fromEntity(TransactionEntity entity) {
    return TransactionModel(
      id: entity.id ?? DateTime.now().millisecondsSinceEpoch,
      storeCode: entity.storeCode,
      paymentMethod: entity.paymentMethod,
      channel: entity.channel,
      customerName: entity.customerName,
      description: entity.description,
      createdById: entity.createdById,
      createdBy: entity.createdBy != null ? UserModel.fromEntity(entity.createdBy!) : null,
      orderedProducts: entity.orderedProducts?.map((e) => OrderedProductModel.fromEntity(e)).toList(),
      shippingFee: entity.shippingFee,
      receivedAmount: entity.receivedAmount,
      returnAmount: entity.returnAmount,
      totalAmount: entity.totalAmount,
      totalOrderedProduct: entity.totalOrderedProduct,
      createdAt: entity.createdAt ?? DateTime.now().toIso8601String(),
      updatedAt: entity.updatedAt ?? DateTime.now().toIso8601String(),
    );
  }

  TransactionEntity toEntity() {
    return TransactionEntity(
      id: id,
      storeCode: storeCode,
      paymentMethod: paymentMethod,
      channel: channel,
      customerName: customerName,
      description: description,
      createdBy: createdBy?.toEntity(),
      createdById: createdById,
      orderedProducts: orderedProducts?.map((e) => e.toEntity()).toList(),
      shippingFee: shippingFee,
      receivedAmount: receivedAmount,
      returnAmount: returnAmount,
      totalAmount: totalAmount,
      totalOrderedProduct: totalOrderedProduct,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
