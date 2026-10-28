import 'package:flutter_contacts/flutter_contacts.dart';

import '../../../domain/entities/transaction_entity.dart';

class CustomerContact {
  final String name;
  final String? phone;
  final bool isFromDevice;

  const CustomerContact({
    required this.name,
    this.phone,
    this.isFromDevice = false,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CustomerContact &&
          runtimeType == other.runtimeType &&
          name.toLowerCase() == other.name.toLowerCase();

  @override
  int get hashCode => name.toLowerCase().hashCode;
}

class CustomerContactsService {
  List<CustomerContact> _cachedContacts = [];
  DateTime? _lastFetch;

  List<CustomerContact> get cachedContacts => _cachedContacts;

  Future<List<CustomerContact>> getContacts({
    List<TransactionEntity>? transactions,
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh &&
        _cachedContacts.isNotEmpty &&
        _lastFetch != null &&
        DateTime.now().difference(_lastFetch!).inMinutes < 5) {
      return _cachedContacts;
    }

    final Map<String, CustomerContact> map = {};

    // 1. Device Contacts (address book)
    try {
      final status = await FlutterContacts.permissions.request(PermissionType.read);
      if (status == PermissionStatus.granted) {
        final deviceList = await FlutterContacts.getAll(
          properties: {ContactProperty.name, ContactProperty.phone},
        );
        for (final c in deviceList) {
          final nameFromParts = [c.name?.first, c.name?.last].whereType<String>().join(' ');
          final displayName = (c.displayName?.isNotEmpty == true ? c.displayName! : nameFromParts).trim();
          if (displayName.isNotEmpty) {
            final key = displayName.toLowerCase();
            final phone = c.phones.isNotEmpty ? c.phones.first.number : null;
            map[key] = CustomerContact(
              name: displayName,
              phone: phone,
              isFromDevice: true,
            );
          }
        }
      }
    } catch (_) {
      // Platform / permission fallback
    }

    // 2. Transaction Customer History
    if (transactions != null) {
      for (final t in transactions) {
        final name = t.customerName?.trim();
        if (name != null && name.isNotEmpty && name != '-') {
          final key = name.toLowerCase();
          if (!map.containsKey(key)) {
            map[key] = CustomerContact(
              name: name,
              isFromDevice: false,
            );
          }
        }
      }
    }

    final sorted = map.values.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    _cachedContacts = sorted;
    _lastFetch = DateTime.now();
    return sorted;
  }
}
