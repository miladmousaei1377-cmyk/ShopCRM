import 'package:flutter/material.dart';

import '../../../core/constants/app_strings.dart';

void showApplicationAboutDialog(BuildContext context) => showAboutDialog(
      context: context,
      applicationName: AppStrings.appName,
      applicationVersion: AppStrings.appVersion,
      applicationIcon: const Icon(Icons.storefront, size: 40),
      children: const [
        Text(AppStrings.developer),
        SizedBox(height: 8),
        Text(AppStrings.instagram),
        SizedBox(height: 4),
        Text(AppStrings.developerEmail),
      ],
    );
