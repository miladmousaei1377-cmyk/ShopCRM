import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'core/constants/app_strings.dart';
import 'core/theme/app_theme.dart';
import 'presentation/providers/auth_provider.dart';
import 'presentation/screens/auth/login_screen.dart';
import 'presentation/screens/dashboard/dashboard_screen.dart';
import 'presentation/screens/invoice/new_invoice_screen.dart';
import 'presentation/screens/invoice/invoice_list_screen.dart';
import 'presentation/screens/products/products_screen.dart';
import 'presentation/screens/products/product_form_screen.dart';
import 'presentation/screens/settings/settings_screen.dart';
import 'presentation/screens/settings/printer_settings_screen.dart';
import 'presentation/screens/reports/reports_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);

  return GoRouter(
    initialLocation: authState.isLoggedIn ? '/dashboard' : '/login',
    redirect: (context, state) {
      final isLoggedIn = authState.isLoggedIn;
      final isLoginRoute = state.matchedLocation == '/login';
      if (!isLoggedIn && !isLoginRoute) return '/login';
      if (isLoggedIn && isLoginRoute) return '/dashboard';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      ShellRoute(
        builder: (context, state, child) => _AppShell(child: child),
        routes: [
          GoRoute(
            path: '/dashboard',
            builder: (_, __) => const DashboardScreen(),
          ),
          GoRoute(
            path: '/invoice/new',
            builder: (_, __) => const NewInvoiceScreen(),
          ),
          GoRoute(
            path: '/invoices',
            builder: (_, __) => const InvoiceListScreen(),
          ),
          GoRoute(
            path: '/products',
            builder: (_, __) => const ProductsScreen(),
          ),
          GoRoute(
            path: '/products/new',
            builder: (context, state) {
              final barcode = state.uri.queryParameters['barcode'];
              return ProductFormScreen(initialBarcode: barcode);
            },
          ),
          GoRoute(
            path: '/products/:id',
            builder: (context, state) {
              final id = int.tryParse(state.pathParameters['id'] ?? '');
              return ProductFormScreen(productId: id);
            },
          ),
          GoRoute(
            path: '/reports',
            builder: (_, __) => const ReportsScreen(),
          ),
          GoRoute(
            path: '/settings',
            builder: (_, __) => const SettingsScreen(),
          ),
          GoRoute(
            path: '/settings/printer',
            builder: (_, __) => const PrinterSettingsScreen(),
          ),
        ],
      ),
    ],
  );
});

class ShopCrmApp extends ConsumerWidget {
  const ShopCrmApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: AppStrings.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routerConfig: router,
      // RTL همه جا
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: child ?? const SizedBox(),
        );
      },
    );
  }
}

/// Shell ریسپانسیو: موبایل → BottomNav | دسکتاپ → NavigationRail
class _AppShell extends StatefulWidget {
  final Widget child;
  const _AppShell({required this.child});

  @override
  State<_AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<_AppShell> {
  int _selectedIndex = 0;

  static const _routes = [
    '/dashboard',
    '/invoice/new',
    '/invoices',
    '/products',
    '/reports',
    '/settings',
  ];

  static const _labels = [
    AppStrings.dashboard,
    AppStrings.newInvoice,
    AppStrings.invoices,
    AppStrings.products,
    AppStrings.reports,
    AppStrings.settings,
  ];

  static const _icons = [
    Icons.dashboard_outlined,
    Icons.add_circle_outline,
    Icons.receipt_long_outlined,
    Icons.inventory_2_outlined,
    Icons.bar_chart_outlined,
    Icons.settings_outlined,
  ];

  static const _selectedIcons = [
    Icons.dashboard,
    Icons.add_circle,
    Icons.receipt_long,
    Icons.inventory_2,
    Icons.bar_chart,
    Icons.settings,
  ];

  bool get _isDesktop => Platform.isWindows || Platform.isLinux || Platform.isMacOS;

  void _onDestinationSelected(int index) {
    setState(() => _selectedIndex = index);
    context.go(_routes[index]);
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 800;

    if (_isDesktop || isWide) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              extended: isWide,
              destinations: List.generate(
                _routes.length,
                (i) => NavigationRailDestination(
                  icon: Icon(_icons[i]),
                  selectedIcon: Icon(_selectedIcons[i]),
                  label: Text(_labels[i],
                      style: const TextStyle(fontFamily: 'Vazirmatn', fontSize: 12)),
                ),
              ),
              selectedIndex: _selectedIndex,
              onDestinationSelected: _onDestinationSelected,
              leading: const SizedBox(height: 16),
            ),
            const VerticalDivider(thickness: 1, width: 1),
            Expanded(child: widget.child),
          ],
        ),
      );
    }

    return Scaffold(
      body: widget.child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onDestinationSelected,
        destinations: List.generate(
          _routes.length,
          (i) => NavigationDestination(
            icon: Icon(_icons[i]),
            selectedIcon: Icon(_selectedIcons[i]),
            label: _labels[i],
          ),
        ),
        labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
        height: 64,
      ),
    );
  }
}
