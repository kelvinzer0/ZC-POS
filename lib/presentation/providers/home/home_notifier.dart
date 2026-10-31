import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/di/app_providers.dart';
import '../../../core/common/result.dart';
import '../../../core/constants/constants.dart';
import '../../../data/models/ordered_product_model.dart';
import '../../../domain/entities/ordered_product_entity.dart';
import '../../../domain/entities/product_entity.dart';
import '../../../domain/entities/transaction_entity.dart';
import '../../../domain/usecases/transaction_usecases.dart';
import '../auth/auth_notifier.dart';
import '../milestone/milestone_notifier.dart';
import '../products/products_notifier.dart';
import '../transactions/transactions_notifier.dart';
import 'home_state.dart';

final homeNotifierProvider = NotifierProvider<HomeNotifier, HomeState>(
  HomeNotifier.new,
);

class HomeNotifier extends Notifier<HomeState> {
  @override
  HomeState build() {
    try {
      final prefs = ref.watch(sharedPreferencesProvider);
      final draftStr = prefs.getString(Constants.cartDraftKey);
      if (draftStr != null && draftStr.isNotEmpty) {
        final Map<String, dynamic> draftMap = jsonDecode(draftStr);
        final rawProducts = draftMap['orderedProducts'] as List<dynamic>? ?? [];
        final products = rawProducts
            .map((p) => OrderedProductModel.fromJson(Map<String, dynamic>.from(p)).toEntity())
            .toList();
        return HomeState(
          orderedProducts: products,
          shippingFee: draftMap['shippingFee'] as int? ?? 0,
          receivedAmount: draftMap['receivedAmount'] as int? ?? 0,
          selectedPaymentMethod: draftMap['selectedPaymentMethod'] as String? ?? 'cash',
          selectedChannel: draftMap['selectedChannel'] as String? ?? 'offline',
          customerName: draftMap['customerName'] as String?,
          description: draftMap['description'] as String?,
        );
      }
    } catch (_) {
      // Handles uninitialized preferences or unit testing environments
    }
    return const HomeState();
  }

  void _persistDraft(HomeState nextState) {
    state = nextState;
    try {
      final prefs = ref.read(sharedPreferencesProvider);
      if (nextState.orderedProducts.isEmpty) {
        prefs.remove(Constants.cartDraftKey);
      } else {
        final draftMap = {
          'orderedProducts': nextState.orderedProducts
              .map((e) => OrderedProductModel.fromEntity(e).toJson())
              .toList(),
          'shippingFee': nextState.shippingFee,
          'receivedAmount': nextState.receivedAmount,
          'selectedPaymentMethod': nextState.selectedPaymentMethod,
          'selectedChannel': nextState.selectedChannel,
          'customerName': nextState.customerName,
          'description': nextState.description,
        };
        prefs.setString(Constants.cartDraftKey, jsonEncode(draftMap));
      }
    } catch (_) {}
  }

  Future<Result<int>> createTransaction() async {
    try {
      final authState = ref.read(authNotifierProvider);
      if (!authState.isAuthenticated) throw 'Unauthenticated!';
      final user = authState.user!;
      final storeCode = ref.read(storeServiceProvider).activeStoreCode;

      var transaction = TransactionEntity(
        id: DateTime.now().millisecondsSinceEpoch,
        storeCode: storeCode,
        paymentMethod: state.selectedPaymentMethod,
        channel: state.selectedChannel,
        customerName: state.customerName,
        description: state.description,
        orderedProducts: state.orderedProducts,
        createdById: user.id,
        createdBy: user,
        shippingFee: state.shippingFee,
        receivedAmount: state.receivedAmount,
        returnAmount: state.receivedAmount - getTotalAmount(),
        totalOrderedProduct: state.orderedProducts.length,
        totalAmount: getTotalAmount(),
      );

      final transactionRepository = ref.read(transactionRepositoryProvider);
      var res = await CreateTransactionUsecase(transactionRepository).call(transaction);

      // Refresh products & transactions and evaluate milestones
      ref.read(productsNotifierProvider.notifier).getAllProducts();
      ref.read(transactionsNotifierProvider.notifier).getAllTransactions();
      ref.read(milestoneNotifierProvider.notifier).checkMilestones();

      return res;
    } catch (e) {
      return Result.failure(error: e);
    }
  }

  void onChangedIsPanelExpanded(bool val) {
    state = state.copyWith(isPanelExpanded: val);
  }

  void onAddOrderedProduct(ProductEntity product, int qty, {int? price}) {
    final effectivePrice = price ?? product.price;
    final orderedProducts = [...state.orderedProducts];
    var currentIndex = orderedProducts.indexWhere((e) => e.productId == product.id && e.price == effectivePrice);

    if (currentIndex != -1) {
      orderedProducts[currentIndex] = orderedProducts[currentIndex].copyWith(quantity: qty);
    } else {
      var order = OrderedProductEntity(
        id: DateTime.now().millisecondsSinceEpoch,
        productId: product.id!,
        quantity: qty,
        stock: product.stock,
        name: product.name,
        imageUrl: product.imageUrl,
        price: effectivePrice,
      );

      orderedProducts.add(order);
    }

    _persistDraft(state.copyWith(orderedProducts: orderedProducts));
  }

  void onRemoveOrderedProduct(OrderedProductEntity val) {
    _persistDraft(
      state.copyWith(
        orderedProducts: state.orderedProducts.where((e) => e != val).toList(),
      ),
    );
  }

  void onRemoveAllOrderedProduct() {
    _persistDraft(const HomeState());
  }

  void onChangedOrderedProductQuantity(int index, int value) {
    final orderedProducts = [...state.orderedProducts];
    orderedProducts[index] = orderedProducts[index].copyWith(quantity: value);
    _persistDraft(state.copyWith(orderedProducts: orderedProducts));
  }

  void onChangedOrderedProductPrice(int index, int newPrice) {
    if (index < 0 || index >= state.orderedProducts.length) return;
    final orderedProducts = [...state.orderedProducts];
    orderedProducts[index] = orderedProducts[index].copyWith(price: newPrice);
    _persistDraft(state.copyWith(orderedProducts: orderedProducts));
  }

  void onChangedOrderedProductNotes(int index, String? notes) {
    if (index < 0 || index >= state.orderedProducts.length) return;
    final orderedProducts = [...state.orderedProducts];
    orderedProducts[index] = orderedProducts[index].copyWith(notes: notes);
    _persistDraft(state.copyWith(orderedProducts: orderedProducts));
  }

  void onChangedReceivedAmount(int value) {
    _persistDraft(state.copyWith(receivedAmount: value));
  }

  void onChangedPaymentMethod(String? value) {
    _persistDraft(state.copyWith(selectedPaymentMethod: value ?? state.selectedPaymentMethod));
  }

  void onChangedChannel(String? value) {
    _persistDraft(state.copyWith(selectedChannel: value ?? state.selectedChannel));
  }

  void onChangedCustomerName(String value) {
    _persistDraft(state.copyWith(customerName: value));
  }

  void onChangedDescription(String value) {
    _persistDraft(state.copyWith(description: value));
  }

  void onChangedShippingFee(int fee) {
    _persistDraft(state.copyWith(shippingFee: fee >= 0 ? fee : 0));
  }

  int getSubtotalAmount() {
    if (state.orderedProducts.isEmpty) return 0;
    return state.orderedProducts.map((e) => e.price * e.quantity).reduce((a, b) => a + b);
  }

  int getTotalAmount() {
    if (state.orderedProducts.isEmpty) return 0;
    return getSubtotalAmount() + state.shippingFee;
  }
}
