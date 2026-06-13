import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'core/constants/app_strings.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/keyboard_shortcuts.dart';
import 'presentation/providers/auth_provider.dart';
import 'presentation/screens/auth/login_screen.dart';
import 'presentation/screens/dashboard/dashboard_screen.dart';
import 'presentation/screens/invoice/new_invoice_screen.dart';
import 'presentation/screens/invoice/invoice_list_screen.dart';
import 'presentation/screens/invoice/invoice_detail_screen.dart';
import 'presentation/screens/inventory/inventory_screen.dart';
import 'presentation/screens/inventory/adjust_stock_screen.dart';
import 'presentation/screens/customers/customers_screen.dart';
import 'presentation/screens/customers/customer_detail_screen.dart';
import 'presentation/screens/customers/customer_form_screen.dart';
import 'presentation/screens/products/products_screen.dart';
import 'presentation/screens/products/product_form_screen.dart';
import 'presentation/screens/settings/settings_screen.dart';
import 'presentation/screens/settings/printer_settings_screen.dart';
import 'presentation/screens/reports/reports_screen.dart';
import 'presentation/screens/prediction/prediction_screen.dart';

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
          GoRoute(path: '/dashboard', builder: (_, __) => const DashboardScreen()),

          GoRoute(path: '/invoice/new', builder: (_, __) => const NewInvoiceScreen()),
          GoRoute(path: '/invoices', builder: (_, __) => const InvoiceListScreen()),
          GoRoute(
            path: '/invoices/:id',
            builder: (context, state) {
              final id = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
              return InvoiceDetailScreen(invoiceId: id);
            },
          ),

          GoRoute(path: '/products', builder: (_, __) => const ProductsScreen()),
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

          GoRoute(path: '/inventory', builder: (_, __) => const InventoryScreen()),
          GoRoute(
            path: '/inventory/adjust',
            builder: (context, state) {
              final productIdStr = state.uri.queryParameters['productId'];
              final productId = productIdStr != null ? int.tryParse(productIdStr) : null;
              return AdjustStockScreen(productId: productId);
            },
          ),

          GoRoute(path: '/customers', builder: (_, __) => const CustomersScreen()),
          GoRoute(path: '/customers/new', builder: (_, __) => const CustomerFormScreen()),
          GoRoute(
            path: '/customers/:id',
            builder: (context, state) {
              final id = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
              return CustomerDetailScreen(customerId: id);
            },
          ),
          GoRoute(
            path: '/customers/:id/edit',
            builder: (context, state) {
              final id = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
              return CustomerFormScreen(customerId: id);
            },
          ),

          GoRoute(path: '/reports', builder: (_, __) => const ReportsScreen()),
          GoRoute(path: '/prediction', builder: (_, __) => const PredictionScreen()),
          GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
          GoRoute(path: '/settings/printer', builder: (_, __) => const PrinterSettingsScreen()),
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
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: AppKeyboardShortcuts(
          child: child ?? const SizedBox(),
        ),
      ),
    );
  }
}

// ─── Shell ریسپانسیو ──────────────────────────────────────────────────────────

class _AppShell extends StatefulWidget {
  final Widget child;
  const _AppShell({required this.child});

  @override
  State<_AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<_AppShell> {
  // ─── آیتم‌های دسکتاپ (همه ۹ مسیر) ──────────────────────────────────────
  static const _routes = [
    '/dashboard', '/invoice/new', '/invoices', '/products',
    '/inventory', '/customers', '/prediction', '/reports', '/settings',
  ];
  static const _labels = [
    AppStrings.dashboard, AppStrings.newInvoice, AppStrings.invoices,
    AppStrings.products, AppStrings.inventory, AppStrings.customers,
    'پیش‌بینی', AppStrings.reports, AppStrings.settings,
  ];
  static const _icons = [
    Icons.dashboard_outlined, Icons.add_circle_outline, Icons.receipt_long_outlined,
    Icons.inventory_2_outlined, Icons.warehouse_outlined, Icons.people_outline,
    Icons.auto_awesome_outlined, Icons.bar_chart_outlined, Icons.settings_outlined,
  ];
  static const _selectedIcons = [
    Icons.dashboard, Icons.add_circle, Icons.receipt_long,
    Icons.inventory_2, Icons.warehouse, Icons.people,
    Icons.auto_awesome, Icons.bar_chart, Icons.settings,
  ];

  // ─── آیتم‌های موبایل (۴ مسیر اصلی + «بیشتر») ────────────────────────────
  static const _mobileRoutes = ['/dashboard', '/invoice/new', '/invoices', '/products'];
  static const _mobileLabels = [
    AppStrings.dashboard, AppStrings.newInvoice, AppStrings.invoices, AppStrings.products,
  ];
  static const _mobileIcons = [
    Icons.dashboard_outlined, Icons.add_circle_outline,
    Icons.receipt_long_outlined, Icons.inventory_2_outlined,
  ];
  static const _mobileSelectedIcons = [
    Icons.dashboard, Icons.add_circle, Icons.receipt_long, Icons.inventory_2,
  ];

  // ─── آیتم‌های «بیشتر» ────────────────────────────────────────────────────
  static const _moreItems = <({String route, String label, IconData icon})>[
    (route: '/inventory',  label: AppStrings.inventory,  icon: Icons.warehouse_outlined),
    (route: '/customers',  label: AppStrings.customers,  icon: Icons.people_outline),
    (route: '/prediction', label: 'پیش‌بینی',            icon: Icons.auto_awesome_outlined),
    (route: '/reports',    label: AppStrings.reports,    icon: Icons.bar_chart_outlined),
    (route: '/settings',   label: AppStrings.settings,   icon: Icons.settings_outlined),
  ];

  bool get _isDesktop => Platform.isWindows || Platform.isLinux || Platform.isMacOS;

  int _mobileIndexFromLocation(String loc) {
    for (int i = 0; i < _mobileRoutes.length; i++) {
      if (loc == _mobileRoutes[i] || loc.startsWith('${_mobileRoutes[i]}/')) return i;
    }
    return 4; // «بیشتر»
  }

  int _desktopIndexFromLocation(String loc) {
    for (int i = 0; i < _routes.length; i++) {
      if (loc == _routes[i] || loc.startsWith('${_routes[i]}/')) return i;
    }
    return 0;
  }

  void _navigate(String route) => context.go(route);

  void _showMoreSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 4),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ..._moreItems.map((item) => ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(item.icon,
                      color: Theme.of(context).colorScheme.primary, size: 22),
                ),
                title: Text(item.label,
                    style: const TextStyle(fontFamily: 'Vazirmatn', fontSize: 15,
                        fontWeight: FontWeight.w500)),
                onTap: () {
                  Navigator.pop(context);
                  _navigate(item.route);
                },
              )),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Future<bool> _showExitDialog(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.exit_to_app, color: Colors.red),
                  SizedBox(width: 8),
                  Text('خروج از برنامه',
                      style: TextStyle(fontFamily: 'Vazirmatn', fontWeight: FontWeight.w700)),
                ],
              ),
              content: const Text(
                'آیا می‌خواهید از فروشگاه هوشمند خارج شوید؟',
                style: TextStyle(fontFamily: 'Vazirmatn', fontSize: 14),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('بازگشت',
                      style: TextStyle(fontFamily: 'Vazirmatn')),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('خروج',
                      style: TextStyle(
                          fontFamily: 'Vazirmatn', color: Colors.white)),
                ),
              ],
            ),
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 800;
    String location = '/dashboard';
    try {
      location = GoRouterState.of(context).matchedLocation;
    } catch (_) {}

    // ─── دسکتاپ / تبلت ───────────────────────────────────────────────────────
    if (_isDesktop || isWide) {
      final idx = _desktopIndexFromLocation(location);
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
              selectedIndex: idx,
              onDestinationSelected: (i) => _navigate(_routes[i]),
              leading: const SizedBox(height: 16),
            ),
            const VerticalDivider(thickness: 1, width: 1),
            Expanded(child: widget.child),
          ],
        ),
      );
    }

    // ─── موبایل: NavigationBar ۵ آیتمه + دیالوگ خروج ────────────────────────
    final mobileIdx = _mobileIndexFromLocation(location);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final router = GoRouter.of(context);
        if (router.canPop()) {
          router.pop();
          return;
        }
        if (!context.mounted) return;
        final shouldExit = await _showExitDialog(context);
        if (shouldExit && context.mounted) {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        body: widget.child,
        bottomNavigationBar: NavigationBar(
          selectedIndex: mobileIdx,
          onDestinationSelected: (i) {
            if (i < _mobileRoutes.length) {
              _navigate(_mobileRoutes[i]);
            } else {
              _showMoreSheet(context);
            }
          },
          destinations: [
            ...List.generate(
              _mobileRoutes.length,
              (i) => NavigationDestination(
                icon: Icon(_mobileIcons[i]),
                selectedIcon: Icon(_mobileSelectedIcons[i]),
                label: _mobileLabels[i],
              ),
            ),
            const NavigationDestination(
              icon: Icon(Icons.more_horiz_outlined),
              selectedIcon: Icon(Icons.more_horiz),
              label: 'بیشتر',
            ),
          ],
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          height: 65,
        ),
      ),
    );
  }
}
