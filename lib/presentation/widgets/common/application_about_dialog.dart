import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_strings.dart';

final applicationInstagramUri =
    Uri.https('www.instagram.com', '/mld.tech1/');
final applicationEmailUri = Uri(
  scheme: 'mailto',
  path: 'mldtech1.official@gmail.com',
);

Future<void> _openLink(BuildContext context, Uri uri) async {
  try {
    if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
  } catch (_) {
    // پیام قابل مشاهده پایین، شکست بازکردن لینک را به کاربر اعلام می‌کند.
  }
  if (!context.mounted) return;
  ScaffoldMessenger.maybeOf(context)?.showSnackBar(
    const SnackBar(content: Text('بازکردن لینک امکان‌پذیر نیست')),
  );
}

Future<void> showApplicationAboutDialog(BuildContext context) =>
    showDialog<void>(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.storefront, size: 40),
              SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(AppStrings.appName),
                  Text(
                    AppStrings.appVersion,
                    style: TextStyle(fontSize: 13),
                  ),
                ],
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(AppStrings.developer),
              const SizedBox(height: 8),
              TextButton(
                key: const ValueKey('about-instagram-link'),
                onPressed: () =>
                    _openLink(dialogContext, applicationInstagramUri),
                child: const Text(AppStrings.instagram),
              ),
              TextButton(
                key: const ValueKey('about-email-link'),
                onPressed: () =>
                    _openLink(dialogContext, applicationEmailUri),
                child: const Text(AppStrings.developerEmail),
              ),
            ],
          ),
          actions: [
            TextButton(
              key: const ValueKey('about-close-button'),
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('بستن'),
            ),
          ],
        ),
      ),
    );
