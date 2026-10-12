import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tally/features/dashboard/presentation/dashboard_screen.dart';
import 'package:tally/features/history/presentation/history_screen.dart';
import 'package:tally/features/wallets/presentation/wallets_screen.dart';
import 'package:tally/features/budgets/presentation/budgets_screen.dart';
import 'package:tally/features/categories/presentation/categories_screen.dart';
import 'package:tally/features/transactions/presentation/add_transaction_screen.dart';
import 'package:tally/features/splash/presentation/splash_screen.dart';
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
      GoRoute(
        path: '/transactions/add',
        name: 'add-transaction',
        builder: (context, state) => const AddTransactionScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => MainScaffold(child: child),
        routes: [
          GoRoute(
            path: '/dashboard',
            name: 'dashboard',
            builder: (context, state) => const DashboardScreen(),
          ),
          GoRoute(
            path: '/history',
            name: 'history',
            builder: (context, state) => const HistoryScreen(),
          ),
          GoRoute(
            path: '/wallets',
            name: 'wallets',
            builder: (context, state) => const WalletsScreen(),
          ),
          GoRoute(
            path: '/budgets',
            name: 'budgets',
            builder: (context, state) => const BudgetsScreen(),
          ),
          GoRoute(
            path: '/categories',
            name: 'categories',
            builder: (context, state) => const CategoriesScreen(),
          ),
        ],
      ),
    ],
  );
});
