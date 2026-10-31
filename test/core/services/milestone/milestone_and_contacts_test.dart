import 'package:flutter_pos/core/services/contacts/customer_contacts_service.dart';
import 'package:flutter_pos/core/services/milestone/milestone_service.dart';
import 'package:flutter_pos/domain/entities/ordered_product_entity.dart';
import 'package:flutter_pos/domain/entities/product_entity.dart';
import 'package:flutter_pos/domain/entities/transaction_entity.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

TransactionEntity _mockTrx({
  int? id,
  String paymentMethod = 'cash',
  String? customerName,
  int totalAmount = 50000,
  int receivedAmount = 50000,
  int returnAmount = 0,
  int totalOrderedProduct = 1,
  String? createdAt,
  List<OrderedProductEntity>? orderedProducts,
}) {
  return TransactionEntity(
    id: id ?? 1,
    paymentMethod: paymentMethod,
    createdById: '1',
    customerName: customerName,
    totalAmount: totalAmount,
    receivedAmount: receivedAmount,
    returnAmount: returnAmount,
    totalOrderedProduct: totalOrderedProduct,
    createdAt: createdAt,
    orderedProducts: orderedProducts,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CustomerContactsService Tests', () {
    test('extracts unique sorted customer names from transaction history', () async {
      final service = CustomerContactsService();
      final transactions = [
        _mockTrx(id: 1, customerName: 'Budi Santoso'),
        _mockTrx(id: 2, customerName: 'Ani Wijaya'),
        _mockTrx(id: 3, customerName: 'budi santoso'), // duplicate lowercase
        _mockTrx(id: 4, customerName: '-'), // invalid
        _mockTrx(id: 5, customerName: ''), // empty
        _mockTrx(id: 6, customerName: 'Citra Dewi'),
      ];

      final contacts = await service.getContacts(transactions: transactions, forceRefresh: true);

      expect(contacts.length, 3);
      expect(contacts.map((c) => c.name).toList(), ['Ani Wijaya', 'Budi Santoso', 'Citra Dewi']);
      expect(contacts.first.isFromDevice, false);
    });
  });

  group('MilestoneService Tests', () {
    late SharedPreferences prefs;
    late MilestoneService service;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      service = MilestoneService(prefs);
    });

    test('triggers firstTransaction notification on first transaction today', () async {
      final now = DateTime(2026, 10, 29, 10, 0);
      final transactions = [
        _mockTrx(
          id: 1,
          totalAmount: 50000,
          createdAt: now.toIso8601String(),
        ),
      ];

      final notifs = await service.evaluateMilestones(
        allTransactions: transactions,
        allProducts: [],
        testTime: now,
      );

      final firstNotif = notifs.where((n) => n.type == MilestoneType.firstTransaction).firstOrNull;
      expect(firstNotif, isNotNull);
      expect(firstNotif!.message, contains('Transaksi pertama hari ini!'));
    });

    test('triggers targetReached when today sales reach daily target', () async {
      final now = DateTime(2026, 10, 29, 14, 0);
      await service.setDailyTarget(500000);

      final transactions = [
        _mockTrx(
          id: 1,
          totalAmount: 600000,
          createdAt: now.toIso8601String(),
        ),
      ];

      final notifs = await service.evaluateMilestones(
        allTransactions: transactions,
        allProducts: [],
        testTime: now,
      );

      final targetNotif = notifs.where((n) => n.type == MilestoneType.targetReached).firstOrNull;
      expect(targetNotif, isNotNull);
      expect(targetNotif!.message, contains('Target penjualan hari ini tercapai!'));
    });

    test('triggers salesGrowth when sales increase >= 10% compared to yesterday', () async {
      final now = DateTime(2026, 10, 29, 15, 0);
      final yesterday = now.subtract(const Duration(days: 1));

      final transactions = [
        _mockTrx(
          id: 1,
          totalAmount: 100000,
          createdAt: yesterday.toIso8601String(),
        ),
        _mockTrx(
          id: 2,
          totalAmount: 130000, // 30% increase
          createdAt: now.toIso8601String(),
        ),
      ];

      final notifs = await service.evaluateMilestones(
        allTransactions: transactions,
        allProducts: [],
        testTime: now,
      );

      final growthNotif = notifs.where((n) => n.type == MilestoneType.salesGrowth).firstOrNull;
      expect(growthNotif, isNotNull);
      expect(growthNotif!.message, contains('Penjualan naik 30% dibanding kemarin'));
    });

    test('triggers topProduct when an item has >= 3 qty sold today', () async {
      final now = DateTime(2026, 10, 29, 12, 0);
      final transactions = [
        _mockTrx(
          id: 1,
          totalAmount: 45000,
          createdAt: now.toIso8601String(),
          orderedProducts: const [
            OrderedProductEntity(
              id: 1,
              productId: 10,
              name: 'Ayam Geprek',
              imageUrl: '',
              stock: 10,
              quantity: 4,
              price: 15000,
            ),
          ],
        ),
      ];

      final notifs = await service.evaluateMilestones(
        allTransactions: transactions,
        allProducts: [],
        testTime: now,
      );

      final topNotif = notifs.where((n) => n.type == MilestoneType.topProduct).firstOrNull;
      expect(topNotif, isNotNull);
      expect(topNotif!.message, contains('Ayam Geprek jadi favorit hari ini!'));
    });

    test('triggers lowStock when a product has stock <= 5', () async {
      final now = DateTime(2026, 10, 29, 10, 0);
      const products = [
        ProductEntity(
          id: 1,
          name: 'Telur Ayam',
          imageUrl: '',
          price: 2500,
          stock: 3,
          category: 'Bahan',
          createdById: '1',
        ),
      ];

      final notifs = await service.evaluateMilestones(
        allTransactions: [],
        allProducts: products,
        testTime: now,
      );

      final stockNotif = notifs.where((n) => n.type == MilestoneType.lowStock).firstOrNull;
      expect(stockNotif, isNotNull);
      expect(stockNotif!.message, contains('Stok Telur Ayam tinggal 3'));
    });

    test('triggers dailyRecap at or after 20:05 WIB', () async {
      final eveningTime = DateTime(2026, 10, 29, 20, 10);
      final transactions = [
        _mockTrx(
          id: 1,
          totalAmount: 850000,
          createdAt: eveningTime.toIso8601String(),
        ),
      ];

      final notifs = await service.evaluateMilestones(
        allTransactions: transactions,
        allProducts: [],
        testTime: eveningTime,
      );

      final recapNotif = notifs.where((n) => n.type == MilestoneType.dailyRecap).firstOrNull;
      expect(recapNotif, isNotNull);
      expect(recapNotif!.message, contains('Omzet hari ini'));
      expect(recapNotif.message, contains('Terima kasih sudah berjuang!'));
    });

    test('updates dailyRecap when initial recap was 0 and transactions load or new sales occur', () async {
      final eveningTime = DateTime(2026, 10, 29, 20, 10);

      // First run with no transactions loaded yet (e.g. at app open)
      final initialNotifs = await service.evaluateMilestones(
        allTransactions: [],
        allProducts: [],
        testTime: eveningTime,
      );
      final initialRecap = initialNotifs.where((n) => n.type == MilestoneType.dailyRecap).firstOrNull;
      expect(initialRecap, isNotNull);
      expect(initialRecap!.message, contains('Rp0'));

      // Transactions finish loading with sales of Rp 450.000
      final updatedTime = DateTime(2026, 10, 29, 20, 15);
      final transactions = [
        _mockTrx(
          id: 1,
          totalAmount: 450000,
          createdAt: DateTime(2026, 10, 29, 14, 30).toIso8601String(),
        ),
      ];

      final updatedNotifs = await service.evaluateMilestones(
        allTransactions: transactions,
        allProducts: [],
        testTime: updatedTime,
      );

      final updatedRecap = updatedNotifs.where((n) => n.type == MilestoneType.dailyRecap).firstOrNull;
      expect(updatedRecap, isNotNull);
      expect(updatedRecap!.message, contains('Rp450.000'));

      // Verify that history only keeps the latest updated recap
      final history = service.getHistory();
      final recapHistory = history.where((n) => n.type == MilestoneType.dailyRecap).toList();
      expect(recapHistory.length, 1);
      expect(recapHistory.first.message, contains('Rp450.000'));
    });

    test('dailyRecap correctly recognizes transactions with UTC ISO strings and SQLite dates', () async {
      final eveningTime = DateTime(2026, 10, 29, 20, 30);
      final transactions = [
        _mockTrx(
          id: 1,
          totalAmount: 150000,
          // SQLite style date without T
          createdAt: '2026-10-29 11:20:00',
        ),
        _mockTrx(
          id: 2,
          totalAmount: 200000,
          // UTC style ISO format
          createdAt: DateTime(2026, 10, 29, 15, 0).toUtc().toIso8601String(),
        ),
      ];

      final notifs = await service.evaluateMilestones(
        allTransactions: transactions,
        allProducts: [],
        testTime: eveningTime,
      );

      final recapNotif = notifs.where((n) => n.type == MilestoneType.dailyRecap).firstOrNull;
      expect(recapNotif, isNotNull);
      expect(recapNotif!.message, contains('Rp350.000'));
    });
  });
}
