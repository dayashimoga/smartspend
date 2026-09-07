import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../providers/app_providers.dart';

class HomeShell extends ConsumerWidget {
  final Widget child;

  const HomeShell({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(financialSummaryProvider);
    final reviewCount = summaryAsync.asData?.value.needsReviewCount ?? 0;

    final location = GoRouterState.of(context).uri.toString();
    int currentIndex = 0;
    if (location.startsWith('/transactions')) {
      currentIndex = 1;
    } else if (location.startsWith('/accounts')) {
      currentIndex = 2;
    } else if (location.startsWith('/insights')) {
      currentIndex = 3;
    } else if (location.startsWith('/review')) {
      currentIndex = 4;
    }

    return Scaffold(
      body: child,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex,
        type: BottomNavigationBarType.fixed,
        selectedFontSize: 11,
        unselectedFontSize: 10,
        onTap: (index) {
          switch (index) {
            case 0:
              context.go('/');
              break;
            case 1:
              context.go('/transactions');
              break;
            case 2:
              context.go('/accounts');
              break;
            case 3:
              context.go('/insights');
              break;
            case 4:
              context.go('/review');
              break;
          }
        },
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            activeIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.swap_horiz_outlined),
            activeIcon: Icon(Icons.swap_horiz),
            label: 'Transactions',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.account_balance_wallet_outlined),
            activeIcon: Icon(Icons.account_balance_wallet),
            label: 'Accounts',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.pie_chart_outline),
            activeIcon: Icon(Icons.pie_chart),
            label: 'Insights',
          ),
          BottomNavigationBarItem(
            icon: Badge(
              isLabelVisible: reviewCount > 0,
              largeSize: 16,
              label: Text(reviewCount > 99 ? '99+' : reviewCount.toString(),
                  style: const TextStyle(fontSize: 10)),
              backgroundColor: AppColors.warning,
              child: const Icon(Icons.rate_review_outlined),
            ),
            activeIcon: Badge(
              isLabelVisible: reviewCount > 0,
              largeSize: 16,
              label: Text(reviewCount > 99 ? '99+' : reviewCount.toString(),
                  style: const TextStyle(fontSize: 10)),
              backgroundColor: AppColors.warning,
              child: const Icon(Icons.rate_review),
            ),
            label: 'Review',
          ),
        ],
      ),
    );
  }
}
