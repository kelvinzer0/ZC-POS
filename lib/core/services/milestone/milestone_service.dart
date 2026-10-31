import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../domain/entities/product_entity.dart';
import '../../../domain/entities/transaction_entity.dart';
import '../../utilities/currency_formatter.dart';

enum MilestoneType {
  firstTransaction,
  salesGrowth,
  targetReached,
  customerGrowth,
  topProduct,
  rushHour,
  lowStock,
  noTransactionYet,
  cashierActiveLong,
  dailyRecap,
}

class MilestoneNotification {
  final String id;
  final MilestoneType type;
  final String title;
  final String message;
  final String iconEmoji;
  final DateTime timestamp;
  final bool isRead;

  const MilestoneNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.iconEmoji,
    required this.timestamp,
    this.isRead = false,
  });

  MilestoneNotification copyWith({bool? isRead}) {
    return MilestoneNotification(
      id: id,
      type: type,
      title: title,
      message: message,
      iconEmoji: iconEmoji,
      timestamp: timestamp,
      isRead: isRead ?? this.isRead,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'title': title,
        'message': message,
        'iconEmoji': iconEmoji,
        'timestamp': timestamp.toIso8601String(),
        'isRead': isRead,
      };

  factory MilestoneNotification.fromJson(Map<String, dynamic> json) {
    return MilestoneNotification(
      id: json['id'] as String,
      type: MilestoneType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => MilestoneType.firstTransaction,
      ),
      title: json['title'] as String,
      message: json['message'] as String,
      iconEmoji: json['iconEmoji'] as String? ?? '🎉',
      timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ?? DateTime.now(),
      isRead: json['isRead'] as bool? ?? false,
    );
  }
}

class MilestoneService {
  final SharedPreferences _prefs;
  final DateTime appStartTime = DateTime.now();

  static const String _notificationsKey = 'milestone_notifications_history';
  static const String _dailyTargetKey = 'milestone_daily_target';

  MilestoneService(this._prefs);

  int get dailyTarget => _prefs.getInt(_dailyTargetKey) ?? 1000000;

  Future<void> setDailyTarget(int target) async {
    await _prefs.setInt(_dailyTargetKey, target);
  }

  List<MilestoneNotification> getHistory() {
    final raw = _prefs.getStringList(_notificationsKey) ?? [];
    return raw
        .map((str) {
          try {
            return MilestoneNotification.fromJson(jsonDecode(str));
          } catch (_) {
            return null;
          }
        })
        .whereType<MilestoneNotification>()
        .toList();
  }

  Future<void> saveNotification(MilestoneNotification notification) async {
    final list = getHistory();
    // Prepend new notification, keeping at most 50
    list.removeWhere((item) => item.id == notification.id);
    list.insert(0, notification);
    if (list.length > 50) {
      list.removeRange(50, list.length);
    }
    final rawList = list.map((item) => jsonEncode(item.toJson())).toList();
    await _prefs.setStringList(_notificationsKey, rawList);
  }

  Future<void> markAllAsRead() async {
    final list = getHistory().map((item) => item.copyWith(isRead: true)).toList();
    final rawList = list.map((item) => jsonEncode(item.toJson())).toList();
    await _prefs.setStringList(_notificationsKey, rawList);
  }

  bool _isMilestoneTriggered(String key) {
    return _prefs.getBool(key) ?? false;
  }

  Future<void> _setMilestoneTriggered(String key) async {
    await _prefs.setBool(key, true);
  }

  String _formatDate(DateTime dt) {
    final year = dt.year.toString();
    final month = dt.month.toString().padLeft(2, '0');
    final day = dt.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  /// Evaluates current business data and returns newly triggered notifications.
  Future<List<MilestoneNotification>> evaluateMilestones({
    required List<TransactionEntity> allTransactions,
    required List<ProductEntity> allProducts,
    DateTime? testTime,
  }) async {
    final now = testTime ?? DateTime.now();
    final todayStr = _formatDate(now);
    final yesterday = now.subtract(const Duration(days: 1));
    final yesterdayStr = _formatDate(yesterday);

    final List<MilestoneNotification> newNotifications = [];

    DateTime? parseDate(String? raw) {
      if (raw == null || raw.trim().isEmpty) return null;
      final dt = DateTime.tryParse(raw.trim());
      if (dt == null) return null;
      return dt.toLocal();
    }

    bool isSameDay(DateTime a, DateTime b) {
      return a.year == b.year && a.month == b.month && a.day == b.day;
    }

    // Filter transactions
    final todayTransactions = allTransactions.where((t) {
      if (t.createdAt == null) return false;
      final parsed = parseDate(t.createdAt);
      if (parsed != null) {
        return isSameDay(parsed, now);
      }
      return t.createdAt!.startsWith(todayStr);
    }).toList();

    final yesterdayTransactions = allTransactions.where((t) {
      if (t.createdAt == null) return false;
      final parsed = parseDate(t.createdAt);
      if (parsed != null) {
        return isSameDay(parsed, yesterday);
      }
      return t.createdAt!.startsWith(yesterdayStr);
    }).toList();

    final todaySales = todayTransactions.fold<int>(0, (sum, t) => sum + t.totalAmount);
    final yesterdaySales = yesterdayTransactions.fold<int>(0, (sum, t) => sum + t.totalAmount);

    // 1. Transaksi pertama hari ini
    final firstTrxKey = 'milestone_${todayStr}_first_transaction';
    if (todayTransactions.isNotEmpty && !_isMilestoneTriggered(firstTrxKey)) {
      await _setMilestoneTriggered(firstTrxKey);
      newNotifications.add(MilestoneNotification(
        id: firstTrxKey,
        type: MilestoneType.firstTransaction,
        title: 'Transaksi pertama',
        message: '🎉 Transaksi pertama hari ini! Semoga lancar terus.',
        iconEmoji: '🎉',
        timestamp: now,
      ));
    }

    // 2. Belum ada transaksi (Jika sudah jam 09:00+ dan belum ada transaksi)
    final noTrxKey = 'milestone_${todayStr}_no_transaction_yet';
    if (now.hour >= 9 && todayTransactions.isEmpty && !_isMilestoneTriggered(noTrxKey)) {
      await _setMilestoneTriggered(noTrxKey);
      newNotifications.add(MilestoneNotification(
        id: noTrxKey,
        type: MilestoneType.noTransactionYet,
        title: 'Belum ada transaksi',
        message: '🌱 Hari masih panjang. Semoga pesanan segera datang!',
        iconEmoji: '🌱',
        timestamp: now,
      ));
    }

    // 3. Penjualan naik dibanding kemarin
    final salesGrowthKey = 'milestone_${todayStr}_sales_growth';
    if (yesterdaySales > 0 && todaySales > yesterdaySales && !_isMilestoneTriggered(salesGrowthKey)) {
      final growthPercent = (((todaySales - yesterdaySales) / yesterdaySales) * 100).round();
      if (growthPercent >= 10) {
        await _setMilestoneTriggered(salesGrowthKey);
        newNotifications.add(MilestoneNotification(
          id: salesGrowthKey,
          type: MilestoneType.salesGrowth,
          title: 'Penjualan naik',
          message: '📈 Penjualan naik $growthPercent% dibanding kemarin. Mantap!',
          iconEmoji: '📈',
          timestamp: now,
        ));
      }
    }

    // 4. Target tercapai
    final targetKey = 'milestone_${todayStr}_target_reached';
    if (todaySales >= dailyTarget && !_isMilestoneTriggered(targetKey)) {
      await _setMilestoneTriggered(targetKey);
      newNotifications.add(MilestoneNotification(
        id: targetKey,
        type: MilestoneType.targetReached,
        title: 'Target tercapai',
        message: '🏆 Target penjualan hari ini tercapai!',
        iconEmoji: '🏆',
        timestamp: now,
      ));
    }

    // 5. Pelanggan bertambah (Milestone: 5, 10, 15, 20, 25, dst.)
    final customerCount = todayTransactions.length;
    if (customerCount >= 5) {
      final tier = (customerCount ~/ 5) * 5;
      final customerTierKey = 'milestone_${todayStr}_customer_tier_$tier';
      if (!_isMilestoneTriggered(customerTierKey)) {
        await _setMilestoneTriggered(customerTierKey);
        newNotifications.add(MilestoneNotification(
          id: customerTierKey,
          type: MilestoneType.customerGrowth,
          title: 'Pelanggan bertambah',
          message: '❤️ Terima kasih sudah melayani $tier pelanggan hari ini.',
          iconEmoji: '❤️',
          timestamp: now,
        ));
      }
    }

    // 6. Produk terlaris hari ini
    final Map<String, int> productQtyMap = {};
    for (final t in todayTransactions) {
      if (t.orderedProducts != null) {
        for (final p in t.orderedProducts!) {
          productQtyMap[p.name] = (productQtyMap[p.name] ?? 0) + p.quantity;
        }
      }
    }
    if (productQtyMap.isNotEmpty) {
      final sortedProducts = productQtyMap.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
      final topEntry = sortedProducts.first;
      if (topEntry.value >= 3) {
        final topProductKey = 'milestone_${todayStr}_top_product_${topEntry.key}';
        if (!_isMilestoneTriggered(topProductKey)) {
          await _setMilestoneTriggered(topProductKey);
          newNotifications.add(MilestoneNotification(
            id: topProductKey,
            type: MilestoneType.topProduct,
            title: 'Produk terlaris',
            message: '🔥 ${topEntry.key} jadi favorit hari ini!',
            iconEmoji: '🔥',
            timestamp: now,
          ));
        }
      }
    }

    // 7. Jam ramai
    final isRushHour = (now.hour == 11 && now.minute >= 30) ||
        (now.hour == 12) ||
        (now.hour == 13 && now.minute <= 30) ||
        (now.hour >= 18 && now.hour <= 20);
    final rushHourSlot = now.hour < 15 ? 'lunch' : 'dinner';
    final rushHourKey = 'milestone_${todayStr}_rush_hour_$rushHourSlot';
    if (isRushHour && !_isMilestoneTriggered(rushHourKey)) {
      await _setMilestoneTriggered(rushHourKey);
      newNotifications.add(MilestoneNotification(
        id: rushHourKey,
        type: MilestoneType.rushHour,
        title: 'Jam ramai',
        message: '⚡ Jam ramai dimulai. Siapkan pesanan terbaikmu!',
        iconEmoji: '⚡',
        timestamp: now,
      ));
    }

    // 8. Stok menipis
    final lowStockProducts = allProducts.where((p) => p.stock > 0 && p.stock <= 5).toList();
    if (lowStockProducts.isNotEmpty) {
      final p = lowStockProducts.first;
      final stockKey = 'milestone_${todayStr}_low_stock_${p.id}';
      if (!_isMilestoneTriggered(stockKey)) {
        await _setMilestoneTriggered(stockKey);
        newNotifications.add(MilestoneNotification(
          id: stockKey,
          type: MilestoneType.lowStock,
          title: 'Stok menipis',
          message: '📦 Stok ${p.name} tinggal ${p.stock}. Yuk, siapkan sebelum habis.',
          iconEmoji: '📦',
          timestamp: now,
        ));
      }
    }

    // 9. Kasir lama aktif (pengingat minum & istirahat)
    final activeMinutes = now.difference(appStartTime).inMinutes;
    if (activeMinutes >= 60) {
      final interval = activeMinutes ~/ 60;
      final activeKey = 'milestone_${todayStr}_active_hours_$interval';
      if (!_isMilestoneTriggered(activeKey)) {
        await _setMilestoneTriggered(activeKey);
        newNotifications.add(MilestoneNotification(
          id: activeKey,
          type: MilestoneType.cashierActiveLong,
          title: 'Kasir lama aktif',
          message: '💧 Sudah lama bekerja? Jangan lupa minum.',
          iconEmoji: '💧',
          timestamp: now,
        ));
      }
    }

    // 10. Rekap harian (jam 20:05 WIB)
    final isAfter2005 = (now.hour > 20) || (now.hour == 20 && now.minute >= 5);
    final recapKey = 'milestone_${todayStr}_daily_recap';
    final recapAmountKey = 'milestone_${todayStr}_daily_recap_amount';
    final lastRecapAmount = _prefs.getInt(recapAmountKey);
    final isTriggered = _isMilestoneTriggered(recapKey);

    // Trigger if not yet triggered, OR if previous recap was 0 while today has sales,
    // OR if new transactions increased today's sales beyond what was previously reported
    final shouldTriggerRecap = isAfter2005 &&
        (!isTriggered ||
            (lastRecapAmount == 0 && todaySales > 0) ||
            (lastRecapAmount != null && todaySales > lastRecapAmount));

    if (shouldTriggerRecap) {
      await _setMilestoneTriggered(recapKey);
      await _prefs.setInt(recapAmountKey, todaySales);
      final omzetFormatted = CurrencyFormatter.format(todaySales);
      newNotifications.add(MilestoneNotification(
        id: recapKey,
        type: MilestoneType.dailyRecap,
        title: 'Rekap harian (jam 20:05 WIB)',
        message: '💰 Omzet hari ini $omzetFormatted. Terima kasih sudah berjuang!',
        iconEmoji: '💰',
        timestamp: now,
      ));
    }

    // Persist all new notifications to history
    for (final notif in newNotifications) {
      await saveNotification(notif);
    }

    return newNotifications;
  }
}
