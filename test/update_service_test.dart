import 'dart:io';

import 'package:bitdrix/core/constants/app_constants.dart';
import 'package:bitdrix/data/services/update_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('compares release tags with the installed version', () {
    expect(UpdateService.compareVersions('v1.0.1', '1.0.0'), greaterThan(0));
    expect(UpdateService.compareVersions('1.2.0', '1.10.0'), lessThan(0));
    expect(UpdateService.compareVersions('v1.0.0', '1.0.0'), 0);
    expect(UpdateService.compareVersions('2.0', '1.9.9'), greaterThan(0));
    expect(UpdateService.normalizeVersion('v1.3.0+7'), '1.3.0');
  });

  test('picks the installer for each platform', () {
    const assets = [
      (name: 'BitDrix-1.1.0.apk', url: 'apk'),
      (name: 'BitDrix-windows-1.1.0.zip', url: 'zip'),
      (name: 'BitDrix-setup-1.1.0.exe', url: 'exe'),
    ];
    expect(UpdateService.pickAsset(assets, TargetPlatform.windows)?.url, 'exe');
    expect(UpdateService.pickAsset(assets, TargetPlatform.android)?.url, 'apk');
    expect(
      UpdateService.pickAsset(assets, TargetPlatform.windows, isWeb: true),
      isNull,
    );
    expect(
      UpdateService.pickAsset(const [
        (name: 'BitDrix-windows.zip', url: 'zip'),
      ], TargetPlatform.windows)?.url,
      'zip',
    );
  });

  // The update check compares AppConstants.appVersion with GitHub releases,
  // so it must always match the version being built.
  test('AppConstants.appVersion matches pubspec.yaml', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final version = RegExp(
      r'^version:\s*([^\s+]+)',
      multiLine: true,
    ).firstMatch(pubspec)!.group(1);
    expect(AppConstants.appVersion, version);
  });
}
