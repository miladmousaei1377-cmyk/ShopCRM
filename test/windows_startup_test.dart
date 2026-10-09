import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Windows window starts maximized', () async {
    final source = await File('lib/main.dart').readAsString();
    final nativeSource =
        await File('windows/runner/win32_window.cpp').readAsString();

    final readyIndex = source.indexOf('windowManager.waitUntilReadyToShow');
    final maximizeIndex = source.indexOf('await windowManager.maximize();');

    expect(readyIndex, greaterThanOrEqualTo(0));
    expect(maximizeIndex, greaterThan(readyIndex));
    expect(nativeSource, contains('ShowWindow(window_handle_, SW_MAXIMIZE)'));
  });

  test('Windows build and visible metadata use NEXOCRM version 1.0.2', () async {
    final cmake = await File('windows/CMakeLists.txt').readAsString();
    final runner = await File('windows/runner/main.cpp').readAsString();
    final resources = await File('windows/runner/Runner.rc').readAsString();
    final manifest =
        await File('android/app/src/main/AndroidManifest.xml').readAsString();
    final pubspec = await File('pubspec.yaml').readAsString();
    final workflow =
        await File('.github/workflows/build-windows.yml').readAsString();

    expect(cmake, contains('set(BINARY_NAME "NEXOCRM")'));
    expect(runner, contains('window.Create(L"NEXOCRM"'));
    expect(resources, contains('VALUE "ProductName", "NEXOCRM"'));
    expect(resources, contains('VALUE "OriginalFilename", "NEXOCRM.exe"'));
    expect(manifest, contains('android:label="NEXOCRM"'));
    expect(pubspec, contains('version: 1.0.2+7'));
    expect(pubspec, contains('display_name: NEXOCRM'));
    expect(pubspec, contains('msix_version: 1.0.2.0'));
    expect(pubspec, contains('output_name: NEXOCRM-Setup'));
    expect(workflow, contains('NEXOCRM-windows.zip'));
  });

  test('Windows exit hides the window before session cleanup', () async {
    final source = await File('lib/app.dart').readAsString();
    final hideIndex = source.indexOf('await windowManager.hide();');
    final logoutIndex = source.indexOf(
      'await ref.read(authProvider.notifier).logout();',
    );

    expect(hideIndex, greaterThanOrEqualTo(0));
    expect(logoutIndex, greaterThan(hideIndex));
  });

  test('settings groups use downward expandable sections', () async {
    final source = await File(
      'lib/presentation/screens/settings/settings_screen.dart',
    ).readAsString();

    expect(source, contains('class _SettingsSection'));
    expect(source, contains('ExpansionTile('));
    expect(RegExp(r'_SettingsSection\(').allMatches(source).length,
        greaterThanOrEqualTo(6));
  });
}
