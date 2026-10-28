import 'package:flutter_pos/data/models/ordered_product_model.dart';
import 'package:flutter_pos/data/models/transaction_model.dart';
import 'package:flutter_pos/domain/entities/ordered_product_entity.dart';
import 'package:flutter_pos/domain/entities/product_entity.dart';
import 'package:flutter_pos/domain/entities/transaction_entity.dart';
import 'package:flutter_pos/presentation/providers/home/home_notifier.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Shipping Fee & Printing Logic Tests', () {
    test('TransactionEntity defaults shippingFee to 0', () {
      const transaction = TransactionEntity(
        id: 1,
        paymentMethod: 'cash',
        createdById: 'user_1',
        receivedAmount: 20000,
        returnAmount: 0,
        totalAmount: 20000,
        totalOrderedProduct: 1,
      );

      expect(transaction.shippingFee, 0);
    });

    test('TransactionEntity supports custom shippingFee', () {
      const transaction = TransactionEntity(
        id: 1,
        paymentMethod: 'cash',
        createdById: 'user_1',
        shippingFee: 15000,
        receivedAmount: 35000,
        returnAmount: 0,
        totalAmount: 35000,
        totalOrderedProduct: 1,
      );

      expect(transaction.shippingFee, 15000);
      expect(transaction.totalAmount, 35000);
    });

    test('TransactionModel converts to and from JSON with shippingFee', () {
      final model = TransactionModel(
        id: 101,
        paymentMethod: 'bank',
        channel: 'wa',
        customerName: 'Budi',
        createdById: 'user_1',
        shippingFee: 12000,
        receivedAmount: 50000,
        returnAmount: 8000,
        totalAmount: 42000,
        totalOrderedProduct: 2,
        orderedProducts: [
          OrderedProductModel(
            id: 1,
            transactionId: 101,
            productId: 10,
            quantity: 2,
            stock: 20,
            name: 'Kopi',
            imageUrl: '',
            price: 15000,
          ),
        ],
      );

      final json = model.toJson();
      expect(json['shippingFee'], 12000);
      expect(json['channel'], 'wa');

      final reconstructed = TransactionModel.fromJson(json);
      expect(reconstructed.shippingFee, 12000);
      expect(reconstructed.totalAmount, 42000);

      final entity = reconstructed.toEntity();
      expect(entity.shippingFee, 12000);
    });

    test('HomeNotifier calculates subtotal and totalAmount with shippingFee', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(homeNotifierProvider.notifier);

      expect(notifier.getSubtotalAmount(), 0);
      expect(notifier.getTotalAmount(), 0);

      // Add product (price: 25000, qty: 2 -> subtotal 50000)
      const product = ProductEntity(
        id: 1,
        name: 'Item A',
        imageUrl: '',
        stock: 10,
        price: 25000,
        category: 'Food',
        createdById: 'user_1',
      );
      notifier.onAddOrderedProduct(product, 2);

      expect(notifier.getSubtotalAmount(), 50000);
      expect(notifier.getTotalAmount(), 50000);

      // Set manual ongkir: 15000
      notifier.onChangedShippingFee(15000);
      expect(container.read(homeNotifierProvider).shippingFee, 15000);
      expect(notifier.getSubtotalAmount(), 50000);
      expect(notifier.getTotalAmount(), 65000);

      // If ongkir set to 0
      notifier.onChangedShippingFee(0);
      expect(container.read(homeNotifierProvider).shippingFee, 0);
      expect(notifier.getTotalAmount(), 50000);
    });
  });
}
