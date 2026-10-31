import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/di/app_providers.dart';
import '../../../core/themes/app_sizes.dart';
import '../../providers/auth/auth_notifier.dart';
import '../../providers/main/main_notifier.dart';
import '../welcome/welcome_screen.dart';

class MainScreen extends ConsumerStatefulWidget {
  final Widget child;

  const MainScreen({
    super.key,
    required this.child,
  });

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref.read(mainNotifierProvider.notifier).initMainProvider();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isLoaded = ref.watch(mainNotifierProvider.select((p) => p.isLoaded));
    final isHasInternet = ref.watch(mainNotifierProvider.select((p) => p.isHasInternet));
    final user = ref.watch(mainNotifierProvider.select((p) => p.user));

    final authUser = ref.watch(authNotifierProvider.select((p) => p.user));

    // Display RootScreen when data is being load
    if (!isLoaded) {
      return const WelcomeScreen();
    }

    // User data might still be null for the first time app open or login without internet connection
    if (isLoaded && user == null && authUser == null && !isHasInternet) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSizes.padding),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.wifi_off_rounded, size: 64, color: Theme.of(context).colorScheme.outline),
                const SizedBox(height: 16),
                Text(
                  'Koneksi Internet Diperlukan',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Koneksi internet diperlukan saat pertama kali membuka aplikasi atau login.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.outline),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: widget.child,
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.maps_home_work_outlined),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_customize_outlined),
            label: 'Products',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long_rounded),
            label: 'Transactions',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart_rounded),
            label: 'Laporan',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_circle_outlined),
            label: 'Account',
          ),
        ],
        currentIndex: _calculateSelectedIndex(),
        onTap: (int idx) => _onItemTapped(idx),
      ),
    );
  }

  int _calculateSelectedIndex() {
    final String location = ref.read(appRoutesProvider).router.state.uri.path;

    if (location.startsWith('/home')) {
      return 0;
    }

    if (location.startsWith('/products')) {
      return 1;
    }

    if (location.startsWith('/transactions')) {
      return 2;
    }

    if (location.startsWith('/reports')) {
      return 3;
    }

    if (location.startsWith('/account')) {
      return 4;
    }

    return 0;
  }

  void _onItemTapped(int index) {
    final router = ref.read(appRoutesProvider).router;

    switch (index) {
      case 0:
        router.go('/home');
      case 1:
        router.go('/products');
      case 2:
        router.go('/transactions');
      case 3:
        router.go('/reports');
      case 4:
        router.go('/account');
    }
  }
}
