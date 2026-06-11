import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/dio_client.dart';
import '../../providers/auth_provider.dart';
import '../../providers/sync_provider.dart';
import '../../widgets/common/confirm_dialog.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncState = ref.watch(syncProvider);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text(AppStrings.settings)),
        body: ListView(
          children: [
            // وضعیت سرور
            _SettingsTile(
              icon: Icons.cloud_sync,
              iconColor: syncState.isOnline ? AppColors.success : AppColors.warning,
              title: 'وضعیت سرور',
              subtitle: syncState.isOnline
                  ? (syncState.lastSyncTime != null
                      ? 'آخرین sync: ${syncState.message ?? "همگام"}'
                      : 'آنلاین')
                  : AppStrings.offline,
              trailing: TextButton(
                onPressed: () => ref.read(syncProvider.notifier).sync(),
                child: const Text('sync',
                    style: TextStyle(fontFamily: 'Vazirmatn')),
              ),
            ),
            const Divider(height: 1),

            // پرینتر
            _SettingsTile(
              icon: Icons.print,
              title: AppStrings.printerSettings,
              subtitle: 'تنظیم بلوتوث / وای‌فای',
              onTap: () => context.go('/settings/printer'),
            ),
            const Divider(height: 1),

            // آدرس سرور
            _SettingsTile(
              icon: Icons.dns,
              title: 'آدرس سرور',
              subtitle: 'تنظیم API endpoint',
              onTap: () => _showServerUrlDialog(context),
            ),
            const Divider(height: 1),

            // درباره
            _SettingsTile(
              icon: Icons.info_outline,
              title: 'درباره اپلیکیشن',
              subtitle: '${AppStrings.appName} - ${AppStrings.appVersion}',
            ),
            const Divider(height: 1),

            // خروج
            _SettingsTile(
              icon: Icons.logout,
              iconColor: AppColors.error,
              title: 'خروج از حساب',
              titleColor: AppColors.error,
              onTap: () async {
                final confirmed = await ConfirmDialog.show(
                  context,
                  title: 'خروج',
                  message: 'آیا می‌خواهید از حساب خارج شوید؟',
                  confirmText: 'خروج',
                  confirmColor: AppColors.error,
                );
                if (confirmed == true && context.mounted) {
                  await ref.read(authProvider.notifier).logout();
                  context.go('/login');
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showServerUrlDialog(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getString(ApiConstants.baseUrlKey) ?? ApiConstants.defaultBaseUrl;
    final ctrl = TextEditingController(text: current);

    if (!context.mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('آدرس سرور',
              style: TextStyle(fontFamily: 'Vazirmatn', fontWeight: FontWeight.w700)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'آدرس کامل API را وارد کنید:',
                style: TextStyle(fontFamily: 'Vazirmatn', fontSize: 12,
                    color: AppColors.textSecondary),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: ctrl,
                textDirection: TextDirection.ltr,
                decoration: InputDecoration(
                  hintText: 'http://192.168.1.1:8000/api',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                  filled: true,
                  fillColor: AppColors.background,
                ),
                style: const TextStyle(fontSize: 13),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text(AppStrings.cancel,
                  style: TextStyle(fontFamily: 'Vazirmatn')),
            ),
            ElevatedButton(
              onPressed: () async {
                final url = ctrl.text.trim();
                if (url.isNotEmpty) {
                  await prefs.setString(ApiConstants.baseUrlKey, url);
                  // ری‌ست Dio تا baseUrl جدید اعمال شود
                  DioClient.reset();
                }
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('آدرس سرور ذخیره شد',
                          style: TextStyle(fontFamily: 'Vazirmatn')),
                      backgroundColor: AppColors.success,
                    ),
                  );
                }
              },
              child: const Text(AppStrings.save,
                  style: TextStyle(fontFamily: 'Vazirmatn')),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String title;
  final Color? titleColor;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    this.iconColor,
    required this.title,
    this.titleColor,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: (iconColor ?? AppColors.primary).withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: iconColor ?? AppColors.primary, size: 22),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontFamily: 'Vazirmatn',
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: titleColor ?? AppColors.textPrimary,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle!,
              style: const TextStyle(
                fontFamily: 'Vazirmatn',
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            )
          : null,
      trailing: trailing ?? (onTap != null ? const Icon(Icons.chevron_left) : null),
      onTap: onTap,
    );
  }
}
