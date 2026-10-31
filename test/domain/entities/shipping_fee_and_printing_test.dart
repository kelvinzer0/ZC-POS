import 'package:flutter_pos/data/models/ordered_product_model.dart';
import 'package:flutter_pos/data/models/product_model.dart';
import 'package:flutter_pos/data/models/transaction_model.dart';
import 'package:flutter_pos/domain/entities/product_entity.dart';
import 'package:flutter_pos/domain/entities/transaction_entity.dart';
import 'package:flutter_pos/presentation/providers/account/printer_settings_state.dart';
import 'package:flutter_pos/presentation/providers/home/home_notifier.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unified_esc_pos_printer/unified_esc_pos_printer.dart';

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
        storeCode: 'WARUNG-LAKKU',
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
      expect(json['storeCode'], 'WARUNG-LAKKU');

      final reconstructed = TransactionModel.fromJson(json);
      expect(reconstructed.shippingFee, 12000);
      expect(reconstructed.totalAmount, 42000);
      expect(reconstructed.storeCode, 'WARUNG-LAKKU');

      final entity = reconstructed.toEntity();
      expect(entity.shippingFee, 12000);
      expect(entity.storeCode, 'WARUNG-LAKKU');
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

    test('PrinterSettingsState supports hideReceiptHeaderTitle, hideReceiptHeaderSubtitle, and receiptReviewMessage', () {
      const state = PrinterSettingsState(
        paperSize: PaperSize.mm58,
        selectedTypes: {},
      );
      expect(state.hideReceiptHeaderTitle, false);
      expect(state.hideReceiptHeaderSubtitle, false);
      expect(state.hideReceiptReviewMessage, false);
      expect(state.receiptReviewMessage, 'Loved the food? Leave us a 5-star review via QR code.');

      final updated = state.copyWith(
        hideReceiptHeaderTitle: true,
        hideReceiptHeaderSubtitle: true,
        hideReceiptReviewMessage: true,
        receiptReviewMessage: 'Terima kasih atas pesanan Anda!',
      );
      expect(updated.hideReceiptHeaderTitle, true);
      expect(updated.hideReceiptHeaderSubtitle, true);
      expect(updated.hideReceiptReviewMessage, true);
      expect(updated.receiptReviewMessage, 'Terima kasih atas pesanan Anda!');
    });

    test('ProductEntity and ProductModel support imageBase64 for cloud sync', () {
      const entity = ProductEntity(
        id: 99,
        createdById: 'user_test',
        name: 'Es Teh Manis',
        imageUrl: '/local/path/image.jpg',
        imageBase64: 'sample_base64_encoded_string',
        stock: 50,
        price: 5000,
      );

      final model = ProductModel.fromEntity(entity);
      expect(model.imageBase64, 'sample_base64_encoded_string');

      final json = model.toJson();
      expect(json['imageBase64'], 'sample_base64_encoded_string');

      final fromJson = ProductModel.fromJson(json);
      expect(fromJson.imageBase64, 'sample_base64_encoded_string');

      final restoredEntity = fromJson.toEntity();
      expect(restoredEntity.imageBase64, 'sample_base64_encoded_string');
    });

    test('HomeNotifier supports adjusting product price and name in cart', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(homeNotifierProvider.notifier);

      const product = ProductEntity(
        id: 2,
        name: 'Ayam Geprek',
        imageUrl: '',
        stock: 10,
        price: 20000,
        category: 'Food',
        createdById: 'user_1',
      );
      notifier.onAddOrderedProduct(product, 1);

      expect(container.read(homeNotifierProvider).orderedProducts.first.name, 'Ayam Geprek');
      expect(container.read(homeNotifierProvider).orderedProducts.first.price, 20000);

      // Adjust price
      notifier.onChangedOrderedProductPrice(0, 18000);
      expect(container.read(homeNotifierProvider).orderedProducts.first.price, 18000);

      // Adjust name
      notifier.onChangedOrderedProductName(0, 'Ayam Geprek Jumbo + Sambal Ekstra');
      expect(container.read(homeNotifierProvider).orderedProducts.first.name, 'Ayam Geprek Jumbo + Sambal Ekstra');
    });
  });
}
