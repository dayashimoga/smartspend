import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'screens/accounts/accounts_screen.dart';
import 'screens/bills/bills_screen.dart';
import 'screens/dashboard/dashboard_screen.dart';
import 'screens/fastag/fastag_screen.dart';
import 'screens/home_shell.dart';
import 'screens/insights/insights_screen.dart';
import 'screens/review/review_screen.dart';
import 'screens/settings/settings_screen.dart';
import 'screens/transactions/transactions_screen.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<NavigatorState> _shellNavigatorKey =
    GlobalKey<NavigatorState>();

final appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/',
  routes: [
    ShellRoute(
      navigatorKey: _shellNavigatorKey,
      builder: (context, state, child) {
        return HomeShell(child: child);
      },
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const DashboardScreen(),
        ),
        GoRoute(
          path: '/transactions',
          builder: (context, state) => const TransactionsScreen(),
        ),
        GoRoute(
          path: '/accounts',
          builder: (context, state) => const AccountsScreen(),
        ),
        GoRoute(
          path: '/insights',
          builder: (context, state) => const InsightsScreen(),
        ),
        GoRoute(
          path: '/review',
          builder: (context, state) => const ReviewScreen(),
        ),
      ],
    ),
    GoRoute(
      path: '/bills',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const BillsScreen(),
    ),
    GoRoute(
      path: '/fastag',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const FastagScreen(),
    ),
    GoRoute(
      path: '/settings',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const SettingsScreen(),
    ),
  ],
);
