import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tally/features/budgets/presentation/budgets_screen.dart';
import 'package:tally/features/categories/presentation/categories_screen.dart';
import 'package:tally/features/dashboard/presentation/dashboard_screen.dart';
import 'package:tally/features/history/presentation/history_screen.dart';
import 'package:tally/features/splash/presentation/splash_screen.dart';
import 'package:tally/features/wallets/presentation/wallets_screen.dart';
import 'package:tally/shared/widgets/main_scaffold.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/splash',
    debugLogDiagnostics: false,
    routes: [
      GoRoute(
        path: '/splash',
        name: 'splash',
        builder: (context, state) => const SplashScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return MainScaffold(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/dashboard',
                name: 'dashboard',
                builder: (context, state) => const DashboardScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/history',
                name: 'history',
                builder: (context, state) => const HistoryScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/wallets',
                name: 'wallets',
                builder: (context, state) => const WalletsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/budgets',
                name: 'budgets',
                builder: (context, state) => const BudgetsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/categories',
                name: 'categories',
                builder: (context, state) => const CategoriesScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
