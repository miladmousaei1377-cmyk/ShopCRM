import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/dio_client.dart';
import '../../../services/biometric_service.dart';
import '../../../services/backup_service.dart';
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
            // پروفایل فروشگاه
            const _ProfileSection(),
            const Divider(height: 1),

            // ─── امنیت (فقط موبایل — اثر انگشت روی ویندوز ندارد) ─────────────
            if (!Platform.isWindows && !Platform.isLinux && !Platform.isMacOS) ...[
              _SectionLabel(label: 'امنیت'),
              const _BiometricTile(),
              const Divider(height: 1),
            ],

            // ─── بکاپ ────────────────────────────────────────────────────────
            _SectionLabel(label: 'پشتیبان‌گیری'),
            const _BackupSection(),
            const Divider(height: 1),

            // ─── سرور و همگام‌سازی ───────────────────────────────────────────
            _SectionLabel(label: 'سرور'),
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
                child: const Text('sync', style: TextStyle(fontFamily: 'Vazirmatn')),
              ),
            ),
            const Divider(height: 1),
            _SettingsTile(
              icon: Icons.dns,
              title: 'آدرس سرور',
              subtitle: 'تنظیم API endpoint',
              onTap: () => _showServerUrlDialog(context),
            ),
            const Divider(height: 1),

            // ─── سایر ────────────────────────────────────────────────────────
            _SectionLabel(label: 'سایر'),
            _SettingsTile(
              icon: Icons.print,
              title: AppStrings.printerSettings,
              subtitle: 'تنظیم بلوتوث / وای‌فای',
              onTap: () => context.go('/settings/printer'),
            ),
            const Divider(height: 1),
            _SettingsTile(
              icon: Icons.info_outline,
              title: 'درباره اپلیکیشن',
              subtitle: '${AppStrings.appName} - ${AppStrings.appVersion}',
            ),
            const Divider(height: 1),
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
              const Text('آدرس کامل API را وارد کنید:',
                  style: TextStyle(fontFamily: 'Vazirmatn', fontSize: 12,
                      color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              TextField(
                controller: ctrl,
                textDirection: TextDirection.ltr,
                decoration: InputDecoration(
                  hintText: 'http://192.168.1.1:8000/api',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
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
              child: const Text(AppStrings.cancel, style: TextStyle(fontFamily: 'Vazirmatn')),
            ),
            ElevatedButton(
              onPressed: () async {
                final url = ctrl.text.trim();
                if (url.isNotEmpty) {
                  await prefs.setString(ApiConstants.baseUrlKey, url);
                  DioClient.reset();
                }
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('آدرس سرور ذخیره شد',
                        style: TextStyle(fontFamily: 'Vazirmatn')),
                    backgroundColor: AppColors.success,
                  ));
                }
              },
              child: const Text(AppStrings.save, style: TextStyle(fontFamily: 'Vazirmatn')),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── عنوان بخش ───────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        label,
        style: const TextStyle(
          fontFamily: 'Vazirmatn',
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

// ─── اثر انگشت ───────────────────────────────────────────────────────────────

class _BiometricTile extends StatefulWidget {
  const _BiometricTile();

  @override
  State<_BiometricTile> createState() => _BiometricTileState();
}

class _BiometricTileState extends State<_BiometricTile> {
  bool _available = false;
  bool _enabled = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final available = await BiometricService.isAvailable();
    final enabled = await BiometricService.isEnabled();
    if (mounted) setState(() { _available = available; _enabled = enabled; });
  }

  Future<void> _toggle(bool value) async {
    if (value) {
      // تأیید اثر انگشت قبل از فعال‌سازی
      final ok = await BiometricService.authenticate();
      if (!ok) return;
    }
    await BiometricService.setEnabled(value);
    if (mounted) setState(() => _enabled = value);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          value ? 'ورود با اثر انگشت فعال شد' : 'ورود با اثر انگشت غیرفعال شد',
          style: const TextStyle(fontFamily: 'Vazirmatn'),
        ),
        backgroundColor: value ? AppColors.success : AppColors.textSecondary,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_available) {
      return _SettingsTile(
        icon: Icons.fingerprint,
        iconColor: AppColors.textHint,
        title: 'ورود با اثر انگشت',
        subtitle: 'دستگاه شما از این ویژگی پشتیبانی نمی‌کند',
      );
    }
    return _SettingsTile(
      icon: Icons.fingerprint,
      iconColor: _enabled ? AppColors.success : AppColors.primary,
      title: 'ورود با اثر انگشت',
      subtitle: _enabled ? 'فعال — در صفحه ورود نمایش داده می‌شود' : 'غیرفعال',
      trailing: Switch(
        value: _enabled,
        onChanged: _toggle,
        activeColor: AppColors.success,
      ),
    );
  }
}

// ─── بکاپ ─────────────────────────────────────────────────────────────────────

class _BackupSection extends StatefulWidget {
  const _BackupSection();

  @override
  State<_BackupSection> createState() => _BackupSectionState();
}

class _BackupSectionState extends State<_BackupSection> {
  bool _autoEnabled = false;
  String _lastBackupLabel = 'در حال بارگذاری...';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final auto = await BackupService.isAutoEnabled();
    final label = await BackupService.getLastBackupLabel();
    if (mounted) {
      setState(() {
        _autoEnabled = auto;
        _lastBackupLabel = label ?? 'هرگز';
      });
    }
  }

  Future<void> _manualBackup() async {
    setState(() => _isLoading = true);
    final file = await BackupService.createBackup(share: true);
    if (mounted) {
      setState(() => _isLoading = false);
      if (file != null) {
        await _load();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('بکاپ با موفقیت ایجاد شد',
              style: TextStyle(fontFamily: 'Vazirmatn')),
          backgroundColor: AppColors.success,
        ));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('خطا در ایجاد بکاپ',
              style: TextStyle(fontFamily: 'Vazirmatn')),
          backgroundColor: AppColors.error,
        ));
      }
    }
  }

  Future<void> _toggleAuto(bool value) async {
    await BackupService.setAutoEnabled(value);
    if (mounted) setState(() => _autoEnabled = value);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _SettingsTile(
          icon: Icons.backup_outlined,
          title: 'بکاپ دستی',
          subtitle: 'آخرین بکاپ: $_lastBackupLabel',
          trailing: _isLoading
              ? const SizedBox(
                  width: 24, height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : TextButton(
                  onPressed: _manualBackup,
                  child: const Text('بکاپ بگیر',
                      style: TextStyle(fontFamily: 'Vazirmatn')),
                ),
        ),
        const Divider(height: 1),
        _SettingsTile(
          icon: Icons.schedule,
          iconColor: _autoEnabled ? AppColors.success : AppColors.primary,
          title: 'بکاپ خودکار هفتگی',
          subtitle: _autoEnabled
              ? 'هر ۷ روز یک‌بار بکاپ ذخیره می‌شود'
              : 'غیرفعال',
          trailing: Switch(
            value: _autoEnabled,
            onChanged: _toggleAuto,
            activeColor: AppColors.success,
          ),
        ),
      ],
    );
  }
}

// ─── پروفایل فروشگاه ─────────────────────────────────────────────────────────

class _ProfileSection extends StatefulWidget {
  const _ProfileSection();

  @override
  State<_ProfileSection> createState() => _ProfileSectionState();
}

class _ProfileSectionState extends State<_ProfileSection> {
  String _ownerName = '';
  String _storeName = '';
  String _phone = '';

  static const _keyOwner = 'profile_owner_name';
  static const _keyStore = 'profile_store_name';
  static const _keyPhone = 'profile_phone';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _ownerName = prefs.getString(_keyOwner) ?? '';
        _storeName = prefs.getString(_keyStore) ?? '';
        _phone = prefs.getString(_keyPhone) ?? '';
      });
    }
  }

  void _openEdit() {
    final ownerCtrl = TextEditingController(text: _ownerName);
    final storeCtrl = TextEditingController(text: _storeName);
    final phoneCtrl = TextEditingController(text: _phone);

    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('ویرایش پروفایل',
              style: TextStyle(fontFamily: 'Vazirmatn', fontWeight: FontWeight.w700)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: storeCtrl,
                decoration: const InputDecoration(
                  labelText: 'نام فروشگاه',
                  labelStyle: TextStyle(fontFamily: 'Vazirmatn'),
                  prefixIcon: Icon(Icons.store_outlined),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ownerCtrl,
                decoration: const InputDecoration(
                  labelText: 'نام صاحب فروشگاه',
                  labelStyle: TextStyle(fontFamily: 'Vazirmatn'),
                  prefixIcon: Icon(Icons.person_outline),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'شماره تماس',
                  labelStyle: TextStyle(fontFamily: 'Vazirmatn'),
                  prefixIcon: Icon(Icons.phone_outlined),
                  border: OutlineInputBorder(),
                ),
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
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString(_keyOwner, ownerCtrl.text.trim());
                await prefs.setString(_keyStore, storeCtrl.text.trim());
                await prefs.setString(_keyPhone, phoneCtrl.text.trim());
                if (ctx.mounted) Navigator.pop(ctx);
                await _load();
              },
              child: const Text(AppStrings.save,
                  style: TextStyle(fontFamily: 'Vazirmatn')),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final displayName = _storeName.isNotEmpty ? _storeName : 'فروشگاه هوشمند';
    final displayOwner = _ownerName.isNotEmpty ? _ownerName : 'تنظیم نشده';

    return InkWell(
      onTap: _openEdit,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: AppColors.primary.withValues(alpha: 0.12),
              child: Text(
                displayName.isNotEmpty ? displayName[0] : 'ف',
                style: const TextStyle(
                  fontFamily: 'Vazirmatn',
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(displayName,
                      style: const TextStyle(
                        fontFamily: 'Vazirmatn', fontSize: 16,
                        fontWeight: FontWeight.w700, color: AppColors.textPrimary,
                      )),
                  const SizedBox(height: 2),
                  Text('مدیر: $displayOwner',
                      style: const TextStyle(
                        fontFamily: 'Vazirmatn', fontSize: 12,
                        color: AppColors.textSecondary,
                      )),
                  if (_phone.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(_phone,
                        style: const TextStyle(
                          fontFamily: 'Vazirmatn', fontSize: 12,
                          color: AppColors.textSecondary,
                        )),
                  ],
                ],
              ),
            ),
            const Icon(Icons.edit_outlined, color: AppColors.textHint, size: 20),
          ],
        ),
      ),
    );
  }
}

// ─── ردیف تنظیمات ────────────────────────────────────────────────────────────

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
          color: (iconColor ?? AppColors.primary).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: iconColor ?? AppColors.primary, size: 22),
      ),
      title: Text(title,
          style: TextStyle(
            fontFamily: 'Vazirmatn', fontSize: 15, fontWeight: FontWeight.w500,
            color: titleColor ?? AppColors.textPrimary,
          )),
      subtitle: subtitle != null
          ? Text(subtitle!,
              style: const TextStyle(
                fontFamily: 'Vazirmatn', fontSize: 12,
                color: AppColors.textSecondary,
              ))
          : null,
      trailing: trailing ?? (onTap != null ? const Icon(Icons.chevron_left) : null),
      onTap: onTap,
    );
  }
}
