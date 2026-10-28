import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/contacts/customer_contacts_service.dart';
import '../transactions/transactions_notifier.dart';

final customerContactsServiceProvider = Provider<CustomerContactsService>((ref) {
  return CustomerContactsService();
});

final customerContactsProvider = FutureProvider.autoDispose<List<CustomerContact>>((ref) async {
  final transactions = ref.watch(transactionsNotifierProvider.select((s) => s.allTransactions));
  final service = ref.watch(customerContactsServiceProvider);
  return service.getContacts(transactions: transactions);
});
