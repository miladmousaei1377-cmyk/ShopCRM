import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
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

  void _showServerUrlDialog(BuildContext context) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('آدرس سرور'),
          content: TextField(
            controller: ctrl,
            textDirection: TextDirection.ltr,
            decoration: const InputDecoration(
              hintText: 'http://192.168.1.1:8000/api',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(AppStrings.cancel),
            ),
            ElevatedButton(
              onPressed: () {
                // TODO: save server URL
                Navigator.pop(context);
              },
              child: const Text(AppStrings.save),
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
