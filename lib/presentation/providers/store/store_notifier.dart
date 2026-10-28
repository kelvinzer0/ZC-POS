import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/di/app_providers.dart';
import '../account/printer_settings_notifier.dart';
import '../auth/auth_notifier.dart';
import '../products/products_notifier.dart';
import '../theme/theme_notifier.dart';
import '../transactions/transactions_notifier.dart';

class StoreState {
  final String activeStoreCode;
  final bool isSyncing;
  final String? lastSyncedAt;

  const StoreState({
    required this.activeStoreCode,
    this.isSyncing = false,
    this.lastSyncedAt,
  });

  StoreState copyWith({
    String? activeStoreCode,
    bool? isSyncing,
    String? lastSyncedAt,
  }) {
    return StoreState(
      activeStoreCode: activeStoreCode ?? this.activeStoreCode,
      isSyncing: isSyncing ?? this.isSyncing,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
    );
  }
}

final storeNotifierProvider = NotifierProvider<StoreNotifier, StoreState>(
  StoreNotifier.new,
);

class StoreNotifier extends Notifier<StoreState> {
  @override
  StoreState build() {
    final storeService = ref.watch(storeServiceProvider);
    return StoreState(activeStoreCode: storeService.activeStoreCode);
  }

  String generateNewStoreCode() {
    final now = DateTime.now().millisecondsSinceEpoch.toString();
    final suffix = now.length > 4 ? now.substring(now.length - 4) : '01';
    return 'STORE-$suffix';
  }

  Future<void> setStoreCode(String code) async {
    final cleanCode = code.trim().toUpperCase().replaceAll(' ', '-');
    if (cleanCode.isEmpty) return;

    state = state.copyWith(isSyncing: true);
    final storeService = ref.read(storeServiceProvider);
    await storeService.setActiveStoreCode(cleanCode);

    final authState = ref.read(authNotifierProvider);
    if (!authState.isAuthenticated) {
      state = state.copyWith(
        activeStoreCode: cleanCode,
        isSyncing: false,
      );
      return;
    }

    // Apply any existing cloud settings from Store/{cleanCode}
    try {
      final applied = await storeService.fetchAndApplyCloudSettings(cleanCode);
      if (!applied) {
        // If store does not exist in cloud yet, push current local settings
        await storeService.syncSettingsToCloud(cleanCode);
      }
    } catch (_) {}

    // Refresh logo provider
    try {
      ref.read(receiptLogoProvider.notifier).updateLogo(
        ref.read(printerServiceProvider).receiptLogoPath,
      );
    } catch (_) {}

    // Refresh theme provider
    ref.invalidate(themeNotifierProvider);

    // Reload products & transactions for the new store
    try {
      await ref.read(productsNotifierProvider.notifier).getAllProducts();
      await ref.read(transactionsNotifierProvider.notifier).getAllTransactions();
    } catch (_) {}

    state = state.copyWith(
      activeStoreCode: cleanCode,
      isSyncing: false,
      lastSyncedAt: DateTime.now().toIso8601String(),
    );
  }

  Future<bool> syncToCloud() async {
    state = state.copyWith(isSyncing: true);
    final storeService = ref.read(storeServiceProvider);
    await storeService.syncSettingsToCloud();
    state = state.copyWith(
      isSyncing: false,
      lastSyncedAt: DateTime.now().toIso8601String(),
    );
    return true;
  }

  Future<bool> fetchFromCloud() async {
    state = state.copyWith(isSyncing: true);
    final storeService = ref.read(storeServiceProvider);
    final success = await storeService.fetchAndApplyCloudSettings();

    // Refresh logo and theme
    ref.read(receiptLogoProvider.notifier).updateLogo(
      ref.read(printerServiceProvider).receiptLogoPath,
    );
    ref.invalidate(themeNotifierProvider);

    // Reload data
    await ref.read(productsNotifierProvider.notifier).getAllProducts();
    await ref.read(transactionsNotifierProvider.notifier).getAllTransactions();

    state = state.copyWith(
      isSyncing: false,
      lastSyncedAt: DateTime.now().toIso8601String(),
    );
    return success;
  }
}
