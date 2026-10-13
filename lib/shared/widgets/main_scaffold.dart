import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tally/core/theme/app_theme.dart';
import 'package:tally/core/theme/theme_provider.dart';
import 'package:tally/features/sync/presentation/providers/sync_providers.dart';
import 'package:tally/features/sync/presentation/widgets/sync_account_sheet.dart';

class MainScaffold extends ConsumerWidget {
  final StatefulNavigationShell? navigationShell;
  final Widget? child;

  const MainScaffold({
    super.key,
    this.navigationShell,
    this.child,
  }) : assert(navigationShell != null || child != null);

  static const tabs = [
    (path: '/dashboard', icon: Icons.home_rounded, label: 'Beranda'),
    (path: '/history', icon: Icons.history_rounded, label: 'Riwayat'),
    (path: '/wallets', icon: Icons.account_balance_wallet_outlined, label: 'Dompet'),
    (path: '/budgets', icon: Icons.pie_chart_outline_rounded, label: 'Kuota'),
    (path: '/categories', icon: Icons.grid_view_rounded, label: 'Kategori'),
  ];

  int _currentIndex(BuildContext context) {
    if (navigationShell != null) {
      return navigationShell!.currentIndex;
    }
    final location = GoRouterState.of(context).matchedLocation;
    for (var i = 0; i < tabs.length; i++) {
      if (location.startsWith(tabs[i].path)) return i;
    }
    return 0;
  }

  void _onTap(BuildContext context, int index) {
    if (navigationShell != null) {
      navigationShell!.goBranch(
        index,
        initialLocation: index == navigationShell!.currentIndex,
      );
    } else {
      context.go(tabs[index].path);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentIndex = _currentIndex(context);
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode == ThemeMode.dark ||
        (themeMode == ThemeMode.system &&
            MediaQuery.platformBrightnessOf(context) == Brightness.dark);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isDark ? AppTheme.darkSystemUiStyle : AppTheme.systemUiStyle,
      child: Scaffold(
        backgroundColor: AppTheme.bg(context),
        appBar: AppBar(
          backgroundColor: AppTheme.bg(context),
          elevation: 0,
          scrolledUnderElevation: 0,
          titleSpacing: 20,
          title: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Image.asset(
                'assets/icons/tallyAppIconForeground.png',
                height: 32,
                fit: BoxFit.contain,
                color: isDark ? AppTheme.white : null,
              ),
              const SizedBox(width: 10),
              Text(
                'Tally',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.6,
                  color: AppTheme.textPrimary(context),
                ),
              ),
            ],
          ),
          actions: [
            Consumer(
              builder: (context, ref, _) {
                final userAsync = ref.watch(googleUserProvider);
                final cachedUserAsync = ref.watch(cachedGoogleUserProvider);
                final syncState = ref.watch(syncProvider);
                final isLoggedIn = userAsync.valueOrNull != null || (cachedUserAsync.valueOrNull?['email'] != null);

                return IconButton(
                  tooltip: 'Cadangan & Sinkronisasi',
                  icon: syncState.isSyncing
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(AppTheme.textPrimary(context)),
                          ),
                        )
                      : Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Icon(
                              isLoggedIn ? Icons.cloud_done_rounded : Icons.cloud_queue_rounded,
                              size: 22,
                              color: isLoggedIn ? AppTheme.textPrimary(context) : AppTheme.textSecondary(context),
                            ),
                            if (isLoggedIn)
                              Positioned(
                                right: -1,
                                top: -1,
                                child: Container(
                                  width: 7,
                                  height: 7,
                                  decoration: const BoxDecoration(
                                    color: Colors.green,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                          ],
                        ),
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    SyncAccountSheet.show(context);
                  },
                );
              },
            ),
            IconButton(
              tooltip: isDark ? 'Beralih ke Mode Terang' : 'Beralih ke Mode Gelap',
              icon: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (child, animation) {
                  return RotationTransition(
                    turns: animation,
                    child: FadeTransition(opacity: animation, child: child),
                  );
                },
                child: Icon(
                  isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                  key: ValueKey(isDark),
                  color: isDark ? AppTheme.white : AppTheme.black,
                  size: 22,
                ),
              ),
              onPressed: () {
                HapticFeedback.lightImpact();
                ref.read(themeModeProvider.notifier).toggle();
              },
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: navigationShell ?? child!,
        bottomNavigationBar: _BottomNavBar(
          currentIndex: currentIndex,
          onTap: (i) => _onTap(context, i),
          tabs: tabs,
        ),
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
    final isDark = AppTheme.isDark(context);
    final bottomPadding = MediaQuery.paddingOf(context).bottom;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.bg(context),
        border: Border(
          top: BorderSide(
            color: isDark ? AppTheme.darkBorder : AppTheme.grey200,
            width: 0.8,
          ),
        ),
      ),
      padding: EdgeInsets.only(
        top: 10,
        bottom: bottomPadding > 0 ? bottomPadding : 10,
      ),
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
                opacity: selected ? 1.0 : (isDark ? 0.4 : 0.3),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      tab.icon,
                      color: AppTheme.textPrimary(context),
                      size: 24,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      tab.label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                        color: AppTheme.textPrimary(context),
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
