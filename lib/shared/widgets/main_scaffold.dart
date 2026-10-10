import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:tally/core/theme/app_theme.dart';

class MainScaffold extends StatelessWidget {
  final Widget child;

  const MainScaffold({super.key, required this.child});

  static const _tabs = [
    (path: '/dashboard', icon: Icons.home_rounded, label: 'Home'),
    (path: '/history', icon: Icons.history_rounded, label: 'Riwayat'),
    (path: '/wallets', icon: Icons.account_balance_wallet_outlined, label: 'Wallet'),
    (path: '/budgets', icon: Icons.pie_chart_outline_rounded, label: 'Kuota'),
  ];

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    for (var i = 0; i < _tabs.length; i++) {
      if (location.startsWith(_tabs[i].path)) return i;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = _currentIndex(context);

    return Scaffold(
      backgroundColor: AppTheme.white,
      appBar: AppBar(
        backgroundColor: AppTheme.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leadingWidth: 56,
        leading: Padding(
          padding: const EdgeInsets.only(left: 20, top: 12, bottom: 12),
          child: Image.asset(
            'assets/icons/tallyLogoTransparan.png',
            fit: BoxFit.contain,
          ),
        ),
      ),
      body: child,
      bottomNavigationBar: _BottomNavBar(
        currentIndex: currentIndex,
        onTap: (i) => context.go(_tabs[i].path),
        tabs: _tabs,
      ),
    );
  }
}

class _BottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<({String path, IconData icon, String label})> tabs;

  const _BottomNavBar({
    required this.currentIndex,
    required this.onTap,
    required this.tabs,
  });

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.paddingOf(context).bottom;

    return Container(
      margin: EdgeInsets.only(bottom: bottomPadding + 5),
      decoration: const BoxDecoration(
        color: AppTheme.white,
      ),
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: List.generate(tabs.length, (i) {
          final tab = tabs[i];
          final selected = currentIndex == i;

          return Expanded(
            child: GestureDetector(
              onTap: () => onTap(i),
              behavior: HitTestBehavior.opaque,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: selected ? 1.0 : 0.3,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      tab.icon,
                      color: AppTheme.black,
                      size: 24,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      tab.label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                        color: AppTheme.black,
                        letterSpacing: 0.1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
