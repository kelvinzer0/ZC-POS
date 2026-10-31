import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/di/app_providers.dart';
import '../../../core/services/milestone/milestone_service.dart';
import '../products/products_notifier.dart';
import '../transactions/transactions_notifier.dart';

final milestoneServiceProvider = Provider<MilestoneService>((ref) {
  return MilestoneService(ref.watch(sharedPreferencesProvider));
});

class MilestoneState {
  final MilestoneNotification? activeBanner;
  final List<MilestoneNotification> history;
  final int unreadCount;

  const MilestoneState({
    this.activeBanner,
    this.history = const [],
    this.unreadCount = 0,
  });

  MilestoneState copyWith({
    MilestoneNotification? activeBanner,
    bool clearActiveBanner = false,
    List<MilestoneNotification>? history,
    int? unreadCount,
  }) {
    return MilestoneState(
      activeBanner: clearActiveBanner ? null : (activeBanner ?? this.activeBanner),
      history: history ?? this.history,
      unreadCount: unreadCount ?? this.unreadCount,
    );
  }
}

final milestoneNotifierProvider = NotifierProvider<MilestoneNotifier, MilestoneState>(
  MilestoneNotifier.new,
);

class MilestoneNotifier extends Notifier<MilestoneState> {
  Timer? _timer;

  @override
  MilestoneState build() {
    final service = ref.watch(milestoneServiceProvider);
    final history = service.getHistory();
    final unread = history.where((n) => !n.isRead).length;

    // Listen to changes in transactions or products to evaluate milestones automatically
    ref.listen(transactionsNotifierProvider.select((s) => s.allTransactions), (_, next) {
      if (next != null) {
        checkMilestones();
      }
    });

    ref.listen(productsNotifierProvider.select((s) => s.allProducts), (_, next) {
      if (next != null) {
        checkMilestones();
      }
    });

    // Setup periodic timer every 60s for time-based milestones (e.g. 20:05 WIB recap, rush hour, etc.)
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      checkMilestones();
    });

    ref.onDispose(() {
      _timer?.cancel();
    });

    // Schedule initial check
    Future.microtask(() => checkMilestones());

    return MilestoneState(
      history: history,
      unreadCount: unread,
    );
  }

  Future<void> checkMilestones({DateTime? testTime}) async {
    final service = ref.read(milestoneServiceProvider);
    var transactions = ref.read(transactionsNotifierProvider).allTransactions;
    if (transactions == null) {
      try {
        await ref.read(transactionsNotifierProvider.notifier).getAllTransactions();
        transactions = ref.read(transactionsNotifierProvider).allTransactions;
      } catch (_) {}
    }
    transactions ??= [];
    final products = ref.read(productsNotifierProvider).allProducts ?? [];

    final newNotifs = await service.evaluateMilestones(
      allTransactions: transactions,
      allProducts: products,
      testTime: testTime,
    );

    if (newNotifs.isNotEmpty) {
      final updatedHistory = service.getHistory();
      final unread = updatedHistory.where((n) => !n.isRead).length;
      state = state.copyWith(
        activeBanner: newNotifs.first,
        history: updatedHistory,
        unreadCount: unread,
      );
    }
  }

  void dismissBanner() {
    state = state.copyWith(clearActiveBanner: true);
  }

  Future<void> markAllAsRead() async {
    final service = ref.read(milestoneServiceProvider);
    await service.markAllAsRead();
    final updatedHistory = service.getHistory();
    state = state.copyWith(
      history: updatedHistory,
      unreadCount: 0,
    );
  }
}
