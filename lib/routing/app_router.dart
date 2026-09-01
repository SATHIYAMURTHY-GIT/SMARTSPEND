import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/expense.dart';

import '../screens/add_expense/add_expense_screen.dart';
import '../screens/expenses/expenses_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/reports/reports_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/home',
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) =>
          AppNavigationShell(navigationShell: navigationShell),
      branches: [
        _branch('/home', 'Home', const HomeScreen()),
        _branch('/expenses', 'Expenses', const ExpensesScreen()),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/add',
              name: 'Add',
              builder: (context, state) => AddExpenseScreen(
                expense: state.extra is Expense ? state.extra as Expense : null,
              ),
            ),
          ],
        ),
        _branch('/reports', 'Reports', const ReportsScreen()),
        _branch('/profile', 'Profile', const ProfileScreen()),
      ],
    ),
  ],
);

StatefulShellBranch _branch(String path, String name, Widget screen) {
  return StatefulShellBranch(
    routes: [GoRoute(path: path, name: name, builder: (_, state) => screen)],
  );
}

class AppNavigationShell extends StatelessWidget {
  const AppNavigationShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: navigationShell.goBranch,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Expenses',
          ),
          NavigationDestination(
            icon: Icon(Icons.add_circle_outline, size: 30),
            selectedIcon: Icon(Icons.add_circle, size: 32),
            label: 'Add',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: 'Reports',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}